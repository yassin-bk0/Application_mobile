import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'seed_service.dart';
import 'data_repository.dart';
import '../models/pv_data.dart';
import '../utils/format_utils.dart';
import 'firestore_measurement_service.dart';

/// Planificateur de mesures périodiques (toutes les 15 minutes).
///
/// En MODE TEST  → utilise [SeedService] pour écrire les fake data dans Firestore.
/// En MODE RÉEL  → utilise [FirestoreMeasurementService] avec les données ESP32.
///
/// Le scheduler se déclenche exactement aux :00, :15, :30, :45 de chaque heure.
class MeasurementScheduler with ChangeNotifier {
  final FirestoreMeasurementService _firestoreService =
      FirestoreMeasurementService();
  final SeedService _seedService = SeedService();

  Timer? _countdownTimer;
  Duration _remainingTime = Duration.zero;
  DateTime? _nextMeasurementTime;
  PvData? _latestData;

  // ── Getters publics ────────────────────────────────────────────────────────

  void updateData(PvData data) => _latestData = data;

  Duration get remainingTime => _remainingTime;

  String get countdownString =>
      '${_remainingTime.inMinutes.toString().padLeft(2, '0')} min '
      '${_remainingTime.inSeconds.remainder(60).toString().padLeft(2, '0')} sec';

  bool get isTestMode => DataRepository.isTestMode;

  // ── Initialisation ─────────────────────────────────────────────────────────

  MeasurementScheduler() {
    _init();
  }

  Future<void> _init() async {
    _calculateNextMeasurement();
    _startTimer();
  }

  bool _isProcessing = false;

  // ── Timer interne ──────────────────────────────────────────────────────────

  void _calculateNextMeasurement() {
    final now = DateTime.now();
    // Prochain multiple de 15 minutes
    final int nextMinutes =
        ((now.minute / 15).floor() + 1) * 15;

    _nextMeasurementTime = DateTime(
      now.year, now.month, now.day,
      now.hour + (nextMinutes ~/ 60),
      nextMinutes % 60,
    );

    final diff = _nextMeasurementTime!.difference(now);
    _remainingTime = diff.isNegative ? Duration.zero : diff;
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final diff = _nextMeasurementTime!.difference(now);
      _remainingTime = diff.isNegative ? Duration.zero : diff;

      if (_remainingTime.inSeconds == 0) {
        _onTimeReached();
      }

      notifyListeners();
    });
  }

  // ── Déclenchement à l'heure prévue ────────────────────────────────────────

  Future<void> _onTimeReached() async {
    if (_isProcessing) return;
    _isProcessing = true;

    // Réinitialiser le timer immédiatement pour l'UI
    _calculateNextMeasurement();
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      final instId = prefs.getString('installationId');

      if (userId != null && instId != null) {
        debugPrint(
          '[MeasurementScheduler] ⏰ ${DataRepository.modeName} — '
          'Déclenchement automatique à ${DateTime.now().hour}h${DateTime.now().minute.toString().padLeft(2, '0')}.',
        );
        await _executeMeasurement(userId, instId);
      }
    } catch (e) {
      debugPrint('[MeasurementScheduler] ❌ Erreur onTimeReached: $e');
    } finally {
      _isProcessing = false;
    }
  }

  // ── Exécution de la mesure ─────────────────────────────────────────────────

  /// Déclenche manuellement une mesure (compatible avec l'ancien code).
  Future<void> triggerManualMeasurement(
      String userId, String installationId) async {
    await _executeMeasurement(userId, installationId);
  }

  Future<void> _executeMeasurement(
      String userId, String installationId) async {
    if (DataRepository.isTestMode) {
      // MODE TEST : mise à jour de current_data via SeedService
      await _seedService.updateCurrentData(
        userId: userId,
        installationId: installationId,
      );
      debugPrint(
          '[MeasurementScheduler] ✅ [MODE TEST] current_data mis à jour.');
    } else {
      // MODE RÉEL : utiliser les données ESP32 reçues
      if (_latestData == null) {
        debugPrint(
            '[MeasurementScheduler] ⚠️ [MODE RÉEL] Pas de données ESP32 disponibles.');
        return;
      }

      debugPrint(
        '[MeasurementScheduler] 🛠️ [MODE RÉEL] Sauvegarde Firestore '
        '(conso: ${FormatUtils.formatPower(_latestData!.pConsumer)})',
      );

      try {
        await _firestoreService.saveMeasurement(
          userId: userId,
          installationId: installationId,
          consoAC: _latestData!.pConsumer,
          prodAC: _latestData!.pPv,
          prodDC: _latestData!.productionDC,
          sourceTimestamp: _latestData!.timestamp,
        );
        debugPrint(
            '[MeasurementScheduler] ✅ [MODE RÉEL] Sauvegarde Firestore réussie.');
      } catch (e) {
        debugPrint(
            '[MeasurementScheduler] ❌ [MODE RÉEL] ÉCHEC de la sauvegarde: $e');
      }
    }

    notifyListeners();
  }

  // ── Dispose ────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}
