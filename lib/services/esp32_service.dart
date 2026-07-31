import 'dart:async';
import '../models/pv_data.dart';
import 'sensor_data_service.dart';
import 'fake_data_service.dart';

/// Service de connexion à l'ESP32 via Firebase Realtime Database.
///
/// En MODE RÉEL : reçoit les données réelles de l'ESP32
/// (ACS712, DHT22, TSL2561, capteurs tension/courant).
///
/// Implémente [SensorDataService] pour être interchangeable
/// avec [FakeSensorDataService].
class Esp32Service implements SensorDataService {
  final StreamController<PvData> _controller =
      StreamController<PvData>.broadcast();

  Timer? _timer;
  bool _connected = false;

  // Callback pour compatibilité ascendante (ancien code)
  Function(PvData)? onDataReceived;

  @override
  String get sourceName => 'ESP32';

  @override
  bool get isConnected => _connected;

  @override
  Stream<PvData> get dataStream => _controller.stream;

  // ── SensorDataService API ─────────────────────────────────────────────────

  @override
  Future<void> initialize() async {
    // TODO (MODE RÉEL) : Se connecter à Firebase RTDB et écouter
    // le nœud contenant les données ESP32.
    // Pour l'instant, démarrer le stream mock pour compatibilité.
    startMockStream();
  }

  @override
  void dispose() {
    stopStream();
    _controller.close();
  }

  // ── Compatibilité ascendante ───────────────────────────────────────────────

  /// Génère 24h de données historiques simulées (un point toutes les 10 min).
  List<PvData> generateHistoricalData() {
    return FakeDataService.generateHistory24h();
  }

  /// Démarre un stream mock (utilisé en fallback quand RTDB est vide).
  void startMockStream() {
    _timer?.cancel();
    _connected = true;
    // Émet immédiatement
    final initial = FakeDataService.generateForTime(DateTime.now());
    _controller.add(initial);
    onDataReceived?.call(initial);

    _timer = Timer.periodic(const Duration(minutes: 15), (_) {
      if (_controller.isClosed) return;
      final data = FakeDataService.generateForTime(DateTime.now());
      _controller.add(data);
      onDataReceived?.call(data);
    });
  }

  void stopStream() {
    _timer?.cancel();
    _timer = null;
    _connected = false;
  }
}
