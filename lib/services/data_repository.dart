import 'sensor_data_service.dart';
import 'fake_sensor_data_service.dart';
import 'esp32_service.dart';

/// Mode de fonctionnement de l'application.
enum AppMode {
  /// MODE TEST : données simulées (fake data), pas besoin de matériel.
  test,

  /// MODE RÉEL : données venant de l'ESP32 via Firebase Realtime Database.
  real,
}

/// Point d'entrée unique pour sélectionner la source de données.
///
/// ## Pour passer en MODE RÉEL :
/// Changer **une seule ligne** :
/// ```dart
/// static const AppMode currentMode = AppMode.real;
/// ```
///
/// L'UI, les graphiques et Firestore continuent à fonctionner sans
/// aucune autre modification.
class DataRepository {
  // ╔══════════════════════════════════════════════════════════════════════════╗
  // ║  CONFIGURATION — Changer ici pour passer en MODE RÉEL                  ║
  // ╚══════════════════════════════════════════════════════════════════════════╝
  static const AppMode currentMode = AppMode.test;

  /// Crée et retourne le service de données correspondant au mode actuel.
  static SensorDataService createService() {
    switch (currentMode) {
      case AppMode.test:
        return FakeSensorDataService();
      case AppMode.real:
        return Esp32Service();
    }
  }

  /// `true` si l'application tourne en mode test.
  static bool get isTestMode => currentMode == AppMode.test;

  /// `true` si l'application tourne en mode réel.
  static bool get isRealMode => currentMode == AppMode.real;

  /// Nom lisible du mode actuel (pour debug/UI).
  static String get modeName => currentMode == AppMode.test ? 'MODE TEST' : 'MODE RÉEL';
}
