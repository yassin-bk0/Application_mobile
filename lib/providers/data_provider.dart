import 'dart:async';

import 'package:flutter/material.dart';
import '../models/pv_data.dart';
import '../services/sensor_data_service.dart';
import '../services/data_repository.dart';
import '../services/esp32_service.dart';
import '../services/firebase_service.dart';
import '../services/firestore_realtime_service.dart';
import '../services/firestore_measurement_service.dart';
import '../services/measurement_scheduler.dart';
import '../services/mesure_service.dart';
import '../services/hourly_archive_service.dart';
import '../services/seed_service.dart';

class DataProvider with ChangeNotifier {
  /// Service de données actif (fake ou réel selon DataRepository.currentMode).
  final SensorDataService _sensorService = DataRepository.createService();

  /// Conservé pour compatibilité ascendante avec les méthodes qui utilisent
  /// Esp32Service directement (ex: generateHistoricalData).
  final Esp32Service _esp32Service = Esp32Service();

  /// Service de seeding Firestore (MODE TEST seulement).
  final SeedService _seedService = SeedService();
  final FirebaseService _firebaseService = FirebaseService();
  final FirestoreRealtimeService _realtimeService = FirestoreRealtimeService();
  final FirestoreMeasurementService _firestoreMeasurementService = FirestoreMeasurementService();

  final MeasurementScheduler? _scheduler = null;
  final HourlyArchiveService _hourlyArchive = HourlyArchiveService();

  void setScheduler(MeasurementScheduler scheduler) {
    // kept for backward compatibility — scheduler is optional
  }

  // ── Core data state ────────────────────────────────────────────────────────
  PvData _currentData = PvData.empty();
  PvData get currentData => _currentData;

  final List<PvData> _history = [];
  List<PvData> get history => _history;

  final List<PredictionData> _predictions = [];
  List<PredictionData> get predictions => _predictions;

  // ── Financial & Environmental ─────────────────────────────────────────────
  double _totalEnergyKwh = 0.0;
  double get totalEnergyKwh => _totalEnergyKwh;

  double get totalEarningsTnd => _totalEnergyKwh * 0.25; // 0.25 TND per kWh
  double get co2SavedKg => _totalEnergyKwh * 0.5; // 0.5 kg CO2 per kWh
  int get treesSaved => (co2SavedKg / 21).floor(); // 1 tree ~ 21 kg CO2/yr
  
  DateTime? _lastReadingTime;
  DateTime? _lastAggregationTime;

  // ── Connection / Loading / Error state ────────────────────────────────────
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  List<String> _alerts = [];
  List<String> get alerts => _alerts;

  // ── Firebase mode flag ────────────────────────────────────────────────────
  /// When true the provider streams from Firebase RTDB and persists to Firestore.
  /// Falls back to mock ESP32 stream when false (or when RTDB is empty).
  bool _isFirebaseMode = true;
  bool get isFirebaseMode => _isFirebaseMode;

  /// Mode actuel de l'application (TEST ou RÉEL).
  AppMode get appMode => DataRepository.currentMode;

  /// Nom lisible du mode actuel pour l'UI.
  String get appModeName => DataRepository.modeName;

  // RTDB stream subscription handle (cancelled in dispose)
  StreamSubscription<PvData>? _rtdbSubscription;
  StreamSubscription? _todayHoursSubscription;
  StreamSubscription? _thisMonthDaysSubscription; // Écoute jours → met à jour mois

  // ── IDs for context (User/Installation) ──────────────────────────────
  String? _userId;
  String? _installationId;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Connect and start streaming data.
  Future<void> connectAndStart({String? userId, String? installationId}) async {
    _isLoading = true;
    _error = null;
    _userId = userId;
    _installationId = installationId;
    notifyListeners();

    print('[DataProvider] Démarrage de la connexion... User ID: $userId, Installation ID: $installationId');

    // ⚠️ SUPPRIMÉ : On ne réécrit JAMAIS de données vides dans Firestore au démarrage.
    // Firestore est la source de vérité — on lit seulement, on n'écrase pas.

    try {
      // ── Step 1: Seed history from Firestore ──────────────────────────────
      // (Note: Optional - we could update this to the new path too if history was migrated)
      final firestoreHistory = await _firebaseService.getHistoricalData(limit: 720);

      if (firestoreHistory.isNotEmpty) {
        _history.clear();
        _history.addAll(firestoreHistory);
        _currentData = firestoreHistory.last;
        _recalculateTotals();
      } else {
        // Firestore vide → seeder avec les données fake si en MODE TEST
        if (DataRepository.isTestMode && _userId != null && _installationId != null) {
          debugPrint('[DataProvider] 🌱 Firestore vide — Seeding automatique en MODE TEST...');
          await _seedService.seedRealistic24hData(
            userId: _userId!,
            installationId: _installationId!,
          );
        }
        // Utiliser l'historique mock en mémoire pour l'UI (immédiat)
        final mockHistory = _esp32Service.generateHistoricalData();
        _history.addAll(mockHistory);
        if (mockHistory.isNotEmpty) {
          _currentData = mockHistory.last;
          _recalculateTotals();
        }
      }

      _isConnected = true;

      // ── Step 2: Subscribe to RTDB live stream ───────────────────────────
      _firebaseService.startLiveStream();

      // ── Step 3: Listeners en arrière-plan (Cascade complète) ──────────────────
      // Niveau 1: écoute heures/ → recalcule totaux du jour
      final now = DateTime.now();
      _todayHoursSubscription?.cancel();
      _todayHoursSubscription = MesureService()
          .streamAggregatedDataByHour(_userId!, _installationId!, now)
          .listen((_) {
        debugPrint('[DataProvider] 🔄 Heures → totaux jour mis à jour.');
      }, onError: (e) {
        debugPrint('[DataProvider] ❌ Erreur listener heures: $e');
      });

      // Niveau 2: écoute jours/ → recalcule totaux du mois
      // Si un total de jour change (car les heures ont changé), les totaux du mois se mettent à jour aussi.
      _thisMonthDaysSubscription?.cancel();
      _thisMonthDaysSubscription = MesureService()
          .streamAggregatedDataByDay(_userId!, _installationId!, now)
          .listen((_) {
        debugPrint('[DataProvider] 🔄 Jours → totaux mois mis à jour.');
      }, onError: (e) {
        debugPrint('[DataProvider] ❌ Erreur listener jours: $e');
      });

      // ── Step 4: Démarrer le service d'archivage horaire automatique ────────────
      // Détecte la fin de chaque heure et crée le document Firestore correspondant.
      // Récupère aussi les heures manquées si l'app était fermée.
      await _hourlyArchive.start(
        userId: _userId!,
        installationId: _installationId!,
      );

      // We give the RTDB stream a short window to determine if it has data.
      bool rtdbHasData = false;
      // Timeout: if no RTDB event in 5 s, fall back to mock stream.
      _rtdbSubscription = _firebaseService.liveStream.listen(
        (PvData data) {
          rtdbHasData = true;
          // updateScheduler: true → données réelles RTDB alimentent le scheduler
          _handleNewReading(data, pushToFirestore: false, updateScheduler: true);
        },
        onError: (err) {
          print('[DataProvider] RTDB error: $err');
          _error = 'Realtime Database error: $err';
          notifyListeners();
        },
      );

      // Wait briefly to detect if RTDB is populated
      await Future.delayed(const Duration(seconds: 5));
      if (!rtdbHasData) {
        // ── Fallback: start mock stream ─────────────────────────────────
        _isFirebaseMode = false;
        _startMockStream();
      }
    } catch (e) {
      _error = 'Failed to connect to Firebase: $e';
      print('[DataProvider] $e');
      // Still fall back to mock so the UI is not broken
      _isFirebaseMode = false;
      _startMockStream();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Disconnect and stop all streams.
  void disconnect() {
    _rtdbSubscription?.cancel();
    _rtdbSubscription = null;
    _todayHoursSubscription?.cancel();
    _todayHoursSubscription = null;
    _thisMonthDaysSubscription?.cancel();
    _thisMonthDaysSubscription = null;
    _hourlyArchive.stop(); // Arrêter le service d'archivage horaire
    _firebaseService.stopLiveStream();
    _esp32Service.stopStream();
    _sensorService.dispose(); // Libérer le service actif (fake ou réel)
    _isConnected = false;
    _userId = null;
    _installationId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _firebaseService.dispose();
    super.dispose();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  void _startMockStream() {
    if (DataRepository.isTestMode) {
      // MODE TEST : utiliser le SensorDataService (FakeSensorDataService)
      _sensorService.initialize().then((_) {
        _sensorService.dataStream.listen((PvData data) {
          // ⚠️ Mode simulation : on ne push PAS vers Firestore ici.
          // C'est le MeasurementScheduler qui écrit dans Firestore toutes les 15 min.
          _handleNewReading(data, pushToFirestore: false, updateScheduler: false);
        });
      });
    } else {
      // MODE RÉEL (fallback mock si pas de RTDB)
      _esp32Service.onDataReceived = (PvData data) {
        _handleNewReading(data, pushToFirestore: false, updateScheduler: false);
      };
      _esp32Service.startMockStream();
    }
  }

  /// Central handler for any new reading regardless of source.
  /// [pushToFirestore] : si true, persiste dans Firestore.
  /// [updateScheduler] : si true, transmet au scheduler (doit être false en mode mock).
  Future<void> _handleNewReading(PvData data, {bool pushToFirestore = false, bool updateScheduler = true}) async {
    _currentData = data;
    _history.add(data);
    
    // Mettre à jour le scheduler UNIQUEMENT avec des données réelles (pas mock)
    if (updateScheduler) {
      _scheduler?.updateData(data);
    }

    if (_lastReadingTime != null && data.timestamp.isAfter(_lastReadingTime!)) {
      final hours = data.timestamp.difference(_lastReadingTime!).inSeconds / 3600.0;
      if (hours > 0 && hours < 24) { // Filter out absurdly large gaps
        _totalEnergyKwh += (data.pPv / 1000.0) * hours;
      }
    }
    _lastReadingTime = data.timestamp;

    // Cap in-memory history to avoid OOM
    if (_history.length > 20000) {
      _history.removeAt(0);
    }

    _checkAlerts(data);
    _generateMockPredictions(data);

    // Persist to Firestore asynchronously using the new structure
    if (pushToFirestore && _userId != null && _installationId != null) {
      _realtimeService.saveRealtimeMeasurement(
        userId: _userId!,
        installationId: _installationId!,
        consommationAC: data.pConsumer,
        productionAC: data.pPv,
        productionDC: data.vPv * data.iPv, // Calcul de la puissance DC
        sourceTimestamp: data.timestamp,
      );

      // Met à jour la structure hiérarchique (Historique Firestore) toutes les 15 minutes
      // Cela permet d'avoir les dossiers annee/mois/jour/heure remplis proprement
      // pour que l'utilisateur puisse les consulter facilement dans la console Firebase.
      final now = DateTime.now();
      if (_lastAggregationTime == null || now.difference(_lastAggregationTime!).inMinutes >= 15) {
        _lastAggregationTime = now;
        _firestoreMeasurementService.aggregateHour(
          userId: _userId!,
          installationId: _installationId!,
          hourToAggregate: now,
        );
      }
    }

    notifyListeners();
  }

  void _checkAlerts(PvData data) {
    _alerts.clear();
    
    // Unusual drop in production
    if (data.pPv < 50 && data.irradiance > 500) {
      _alerts.add("Warning: PV Production is unusually low given the current irradiance.");
    }
    if (data.temperature > 40) {
      _alerts.add("Alert: High Panel Temperature detected.");
    }
    
    // High consumption error
    if (data.pConsumer > 4000) {
       _alerts.add("Alert: High consumption detected (> 4 kW).");
    }
    
    // Earnings milestone
    if (totalEarningsTnd >= 10 && _alerts.every((a) => !a.contains("10 TND"))) {
       // Typically you'd persistently track milestones, but here we just show it if > 10
       // We'll keep it simple: alert if > 100, etc. For demonstration, let's just do:
       if (totalEarningsTnd > 50) {
         _alerts.add("Milestone: High earnings reached (> 50 TND)!");
       }
    }
  }

  void _recalculateTotals() {
    _totalEnergyKwh = 0.0;
    if (_history.isEmpty) return;
    for (int i = 1; i < _history.length; i++) {
        final durationHours = _history[i].timestamp.difference(_history[i-1].timestamp).inSeconds / 3600.0;
        if (durationHours > 0 && durationHours < 24) {
           _totalEnergyKwh += (_history[i].pPv / 1000.0) * durationHours;
        }
    }
    _lastReadingTime = _history.last.timestamp;
  }

  void _generateMockPredictions(PvData data) {
    _predictions.clear();
    for (int i = 1; i <= 5; i++) {
      _predictions.add(
        PredictionData(
          predictedVPv: data.vPv * (1 + (0.02 * i)),
          predictedIPv: data.iPv * (1 - (0.01 * i)),
          predictedPPv: (data.vPv * (1 + (0.02 * i))) * (data.iPv * (1 - (0.01 * i))),
          targetTime: data.timestamp.add(Duration(minutes: i * 15)),
        ),
      );
    }
  }
}
