import 'package:cloud_firestore/cloud_firestore.dart';

/// Données provenant des capteurs physiques (ESP32) :
/// - Capteur de luminosité (LDR / irradiance)
/// - Capteur de température (DS18B20 / DHT22)
///
/// L'ESP32 écrit ces données dans Firestore à :
/// users/{userId}/installations/{installationId}/sensors/latest
class SensorData {
  final double luminosite;  // en lux
  final double temperature; // en °C
  final DateTime timestamp;

  /// true si le document est absent ou vieux de plus de [kOfflineThreshold].
  final bool isOffline;

  /// Seuil au-delà duquel les capteurs sont considérés hors-ligne.
  static const Duration kOfflineThreshold = Duration(minutes: 20);

  const SensorData({
    required this.luminosite,
    required this.temperature,
    required this.timestamp,
    this.isOffline = false,
  });

  /// Construit un [SensorData] marqué comme hors-ligne.
  factory SensorData.offline() {
    return SensorData(
      luminosite: 0,
      temperature: 0,
      timestamp: DateTime.now(),
      isOffline: true,
    );
  }

  /// Désérialise depuis un document Firestore.
  factory SensorData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime ts;
    final rawTs = data['timestamp'];
    if (rawTs is Timestamp) {
      ts = rawTs.toDate();
    } else if (rawTs is int) {
      ts = DateTime.fromMillisecondsSinceEpoch(rawTs);
    } else {
      ts = DateTime.now();
    }

    final isOld = DateTime.now().difference(ts) > kOfflineThreshold;

    return SensorData(
      luminosite: (data['luminosite'] as num?)?.toDouble() ?? 0.0,
      temperature: (data['temperature'] as num?)?.toDouble() ?? 0.0,
      timestamp: ts,
      isOffline: isOld,
    );
  }

  /// Désérialise depuis un Map générique (ex: Realtime Database).
  factory SensorData.fromMap(Map<dynamic, dynamic> map) {
    DateTime ts;
    final rawTs = map['timestamp'];
    if (rawTs is int) {
      ts = DateTime.fromMillisecondsSinceEpoch(rawTs);
    } else {
      ts = DateTime.now();
    }

    final isOld = DateTime.now().difference(ts) > kOfflineThreshold;

    return SensorData(
      luminosite: _toDouble(map['luminosite']),
      temperature: _toDouble(map['temperature']),
      timestamp: ts,
      isOffline: isOld,
    );
  }

  /// Sérialise pour écriture Firestore (utile pour les tests).
  Map<String, dynamic> toMap() {
    return {
      'luminosite': luminosite,
      'temperature': temperature,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    return (value as num).toDouble();
  }

  // ── Indicateurs de performance PV ────────────────────────────────────────

  /// Niveau de performance basé sur la luminosité capteur.
  String get performanceLevel {
    if (luminosite >= 40000) return 'Élevée';
    if (luminosite >= 10000) return 'Moyenne';
    return 'Faible';
  }

  /// true si la luminosité est suffisante pour espérer une bonne production.
  bool get isHighIrradiance => luminosite >= 10000;

  @override
  String toString() =>
      'SensorData(lux=$luminosite, temp=$temperature°C, offline=$isOffline)';
}
