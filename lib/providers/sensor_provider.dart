import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/sensor_data.dart';
import '../models/installation_pv.dart';
import '../services/sensor_service.dart';

/// Intervalle de rafraîchissement forcé (en complément du stream Firestore).
const Duration _kRefreshInterval = Duration(minutes: 15);

/// Seuil de luminosité (lux) au-dessus duquel on considère que le soleil brille.
const double _kHighIrradianceThreshold = 10000;

/// Seuil de production (W) en dessous duquel on considère la production faible.
const double _kLowProductionThreshold = 50;

/// Provider qui remplace WeatherProvider.
/// Lit les données des capteurs ESP32 depuis Firebase et expose :
///   - [sensorData]      : dernière mesure disponible
///   - [isLoading]       : chargement en cours
///   - [error]           : message d'erreur éventuel
///   - [nuisanceAlert]   : message d'alerte si nuisance détectée
///   - [isOffline]       : true si capteurs hors ligne
class SensorProvider with ChangeNotifier {
  final SensorService _sensorService = SensorService();

  // ── État ──────────────────────────────────────────────────────────────────
  SensorData? _sensorData;
  SensorData? get sensorData => _sensorData;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  /// Dernière production AC connue (W) — mise à jour par DataProvider via [updateProduction].
  double _lastProductionAC = 0.0;

  // ── IDs en cours ─────────────────────────────────────────────────────────
  User? _currentUser;
  String? _installationId;

  // ── Souscriptions / Timers ───────────────────────────────────────────────
  StreamSubscription<SensorData>? _sensorSubscription;
  Timer? _refreshTimer;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Appelé par [ChangeNotifierProxyProvider2] quand [AuthProvider] ou
  /// [InstallationProvider] change.
  Future<void> updateUser(User? user, InstallationPV? installation) async {
    final bool userSame = user?.uid == _currentUser?.uid;
    final bool instSame = installation?.id == _installationId;

    if (userSame && instSame) return;

    _currentUser = user;
    _installationId = installation?.id;

    // Déconnexion
    if (user == null) {
      _clear();
      return;
    }

    // Si on n'a pas encore d'installation, attendre.
    if (_installationId == null) return;

    await _startListening();
  }

  /// Appelé par DataProvider (ou MeasurementScheduler) pour alimenter
  /// la logique de détection de nuisances avec la dernière production.
  void updateProduction(double productionAC) {
    if (_lastProductionAC == productionAC) return;
    _lastProductionAC = productionAC;
    notifyListeners();
  }

  /// Rafraîchit manuellement les données capteurs.
  Future<void> refresh() async {
    if (_currentUser == null || _installationId == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _sensorService.getLatestSensorData(
        _currentUser!.uid,
        _installationId!,
      );
      _sensorData = data;
    } catch (e) {
      _error = 'Erreur capteurs : $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Indicateurs exposés ───────────────────────────────────────────────────

  /// true si les capteurs sont hors ligne (document absent ou trop vieux).
  bool get isOffline => _sensorData?.isOffline ?? true;

  /// Niveau de performance PV : 'Élevée' / 'Moyenne' / 'Faible'.
  String getPerformanceLevel() {
    if (_sensorData == null || isOffline) return 'Inconnu';
    return _sensorData!.performanceLevel;
  }

  /// Retourne une alerte nuisance si :
  ///   luminosité ≥ 10 000 lux  ET  production AC < 50 W
  /// Sinon null.
  String? getNuisanceAlert() {
    if (_sensorData == null || isOffline) return null;
    if (_sensorData!.luminosite >= _kHighIrradianceThreshold &&
        _lastProductionAC < _kLowProductionThreshold) {
      return '⚠️ Possible nuisance détectée (ombrage ou saleté sur les panneaux)';
    }
    return null;
  }

  // ── Privé ─────────────────────────────────────────────────────────────────

  Future<void> _startListening() async {
    // Annuler les abonnements précédents
    await _sensorSubscription?.cancel();
    _refreshTimer?.cancel();

    _isLoading = true;
    _error = null;
    notifyListeners();

    // 1. Lecture immédiate
    try {
      _sensorData = await _sensorService.getLatestSensorData(
        _currentUser!.uid,
        _installationId!,
      );
    } catch (e) {
      _error = 'Erreur capteurs : $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    // 2. Stream Firestore temps réel
    _sensorSubscription = _sensorService
        .getSensorStream(_currentUser!.uid, _installationId!)
        .listen(
      (data) {
        _sensorData = data;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = 'Erreur stream capteurs : $e';
        notifyListeners();
      },
    );

    // 3. Timer de rafraîchissement toutes les 15 minutes (fallback)
    _refreshTimer = Timer.periodic(_kRefreshInterval, (_) => refresh());
  }

  void _clear() {
    _sensorSubscription?.cancel();
    _sensorSubscription = null;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _sensorData = null;
    _lastProductionAC = 0;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }
}
