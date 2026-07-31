import '../models/pv_data.dart';
import 'fake_data_service.dart';
import 'sensor_data_service.dart';

/// Implémentation de [SensorDataService] utilisant des données simulées.
///
/// Utilisée en MODE TEST.
/// Toujours "connectée" — ne nécessite aucun matériel.
class FakeSensorDataService implements SensorDataService {
  final FakeDataService _fakeService = FakeDataService();
  bool _initialized = false;

  @override
  String get sourceName => 'FAKE';

  @override
  bool get isConnected => _initialized;

  @override
  Stream<PvData> get dataStream => _fakeService.dataStream;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _fakeService.startStream();
    _initialized = true;
  }

  @override
  void dispose() {
    _fakeService.dispose();
    _initialized = false;
  }
}
