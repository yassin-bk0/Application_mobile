import '../models/pv_data.dart';

/// Interface commune pour toutes les sources de données capteur.
///
/// En MODE TEST  → implémentée par [FakeSensorDataService]
/// En MODE RÉEL  → implémentée par [Esp32Service]
///
/// Cette abstraction garantit que le reste de l'application (DataProvider,
/// DataRepository) n'a jamais à connaître la source concrète des données.
abstract class SensorDataService {
  /// Stream continu de données PV.
  Stream<PvData> get dataStream;

  /// Initialise la source (connexion, démarrage du stream, etc.).
  Future<void> initialize();

  /// Libère les ressources.
  void dispose();

  /// `true` si la source est active et produit des données.
  bool get isConnected;

  /// Identifiant lisible de la source : "FAKE" | "ESP32" | etc.
  String get sourceName;
}
