class PvData {
  final double irradiance;
  final double temperature;
  final double humidity;

  final double vPv;
  final double iPv;
  final double pPv;

  final double vConsumer;
  final double iConsumer;
  final double pConsumer;

  /// Puissance batterie en Watts.
  /// Positif = en charge, Négatif = en décharge.
  final double batteryPower;

  /// État de charge de la batterie (0–100 %).
  final double batterySOC;

  /// Énergie importée du réseau (W). 0 si autosuffisant.
  final double gridImport;

  /// Énergie exportée vers le réseau (W). 0 si déficit.
  final double gridExport;

  /// Température de l'onduleur (°C).
  final double inverterTemp;

  /// Fréquence du réseau (Hz).
  final double frequency;

  final DateTime timestamp;

  // ── Computed properties ────────────────────────────────────────────────────

  /// Puissance DC calculée (Vpv * Ipv)
  double get productionDC => vPv * iPv;

  /// Rendement de l'onduleur (%) (Pac / Pdc * 100)
  double get rendement {
    final dc = productionDC;
    if (dc <= 0) return 0.0;
    return (pPv / dc) * 100;
  }

  /// Bilan net = Production AC - Consommation AC (W)
  double get bilanNet => pPv - pConsumer;

  PvData({
    required this.irradiance,
    required this.temperature,
    required this.humidity,
    required this.vPv,
    required this.iPv,
    required this.pPv,
    required this.vConsumer,
    required this.iConsumer,
    required this.pConsumer,
    required this.timestamp,
    this.batteryPower = 0.0,
    this.batterySOC = 50.0,
    this.gridImport = 0.0,
    this.gridExport = 0.0,
    this.inverterTemp = 25.0,
    this.frequency = 50.0,
  });

  factory PvData.empty() {
    return PvData(
      irradiance: 0.0,
      temperature: 0.0,
      humidity: 0.0,
      vPv: 0.0,
      iPv: 0.0,
      pPv: 0.0,
      vConsumer: 0.0,
      iConsumer: 0.0,
      pConsumer: 0.0,
      timestamp: DateTime.now(),
      batteryPower: 0.0,
      batterySOC: 50.0,
      gridImport: 0.0,
      gridExport: 0.0,
      inverterTemp: 25.0,
      frequency: 50.0,
    );
  }

  /// Serialize to a map for Firestore / Realtime Database writes.
  Map<String, dynamic> toMap() {
    return {
      'irradiance': irradiance,
      'temperature': temperature,
      'humidity': humidity,
      'vPv': vPv,
      'iPv': iPv,
      'pPv': pPv,
      'vConsumer': vConsumer,
      'iConsumer': iConsumer,
      'pConsumer': pConsumer,
      'batteryPower': batteryPower,
      'batterySOC': batterySOC,
      'gridImport': gridImport,
      'gridExport': gridExport,
      'inverterTemp': inverterTemp,
      'frequency': frequency,
      'bilanNet': bilanNet,
      // Store as milliseconds-since-epoch for portability across RTDB & Firestore.
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  /// Deserialize from a Firestore / Realtime Database map.
  factory PvData.fromMap(Map<dynamic, dynamic> map) {
    // Timestamp may be stored as int (ms) or a Firestore Timestamp object.
    DateTime ts;
    final rawTs = map['timestamp'];
    if (rawTs is int) {
      ts = DateTime.fromMillisecondsSinceEpoch(rawTs);
    } else {
      // Firestore Timestamp — use .toDate()
      try {
        ts = (rawTs as dynamic).toDate() as DateTime;
      } catch (_) {
        ts = DateTime.now();
      }
    }

    return PvData(
      irradiance: _toDouble(map['irradiance']),
      temperature: _toDouble(map['temperature']),
      humidity: _toDouble(map['humidity']),
      vPv: _toDouble(map['vPv']),
      iPv: _toDouble(map['iPv']),
      pPv: _toDouble(map['pPv']),
      vConsumer: _toDouble(map['vConsumer']),
      iConsumer: _toDouble(map['iConsumer']),
      pConsumer: _toDouble(map['pConsumer']),
      timestamp: ts,
      batteryPower: _toDouble(map['batteryPower']),
      batterySOC: _toDouble(map['batterySOC'] ?? 50.0),
      gridImport: _toDouble(map['gridImport']),
      gridExport: _toDouble(map['gridExport']),
      inverterTemp: _toDouble(map['inverterTemp'] ?? 25.0),
      frequency: _toDouble(map['frequency'] ?? 50.0),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return 0.0;
  }
}

class PredictionData {
  final double predictedVPv;
  final double predictedIPv;
  final double predictedPPv;
  final DateTime targetTime;

  PredictionData({
    required this.predictedVPv,
    required this.predictedIPv,
    required this.predictedPPv,
    required this.targetTime,
  });
}
