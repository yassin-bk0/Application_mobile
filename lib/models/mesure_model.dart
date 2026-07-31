import 'package:cloud_firestore/cloud_firestore.dart';

class Mesure {
  final DateTime timestamp;
  final double production;
  final double consommation;

  Mesure({
    required this.timestamp,
    required this.production,
    required this.consommation,
  });

  factory Mesure.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    DateTime ts;
    final rawTs = data['timestamp'];
    if (rawTs is Timestamp) {
      ts = rawTs.toDate();
    } else if (rawTs is int) {
      ts = DateTime.fromMillisecondsSinceEpoch(rawTs);
    } else {
      ts = DateTime.now();
    }

    return Mesure(
      timestamp: ts,
      production: (data['productionAC'] ?? data['pPv'] ?? 0.0).toDouble(),
      consommation: (data['consommationAC'] ?? data['pConsumer'] ?? 0.0).toDouble(),
    );
  }

  double get productionDC {
    // Note: productionDC is typically calculated as vPv * iPv in the real-time data
    // but the aggregation service already computes productionDC_total.
    return 0.0;
  }
}

class MesureAgregee {
  final String periodeLabel; // Ex: "08h", "05/04", "Jan"
  final double productionTotale;
  final double productionDCTotale;
  final double consommationTotale;

  MesureAgregee({
    required this.periodeLabel,
    required this.productionTotale,
    required this.productionDCTotale,
    required this.consommationTotale,
  });

  double get bilantNet => productionTotale - consommationTotale;
}
