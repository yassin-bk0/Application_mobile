import 'package:cloud_firestore/cloud_firestore.dart';

class RealtimeMeasurement {
  final String id; // Format: yyyy-MM-dd_HH:mm:ss
  final double consommationAC;
  final double productionAC;
  final double productionDC;
  final double rendement;
  final DateTime timestamp;

  RealtimeMeasurement({
    required this.id,
    required this.consommationAC,
    required this.productionAC,
    required this.productionDC,
    required this.rendement,
    required this.timestamp,
  });

  factory RealtimeMeasurement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    DateTime ts;
    final rawTs = data['timestamp'];
    if (rawTs is Timestamp) {
      ts = rawTs.toDate();
    } else {
      ts = DateTime.now(); // Fallback
    }

    final prodAC = (data['productionAC'] as num?)?.toDouble() ?? 0.0;
    final prodDC = (data['productionDC'] as num?)?.toDouble() ?? 0.0;

    // Recalcul dynamique du rendement depuis les valeurs brutes.
    // On ignore le champ 'rendement' stocké pour éviter toute désynchronisation
    // lorsque productionAC ou productionDC est modifié manuellement dans Firestore.
    final rendementCalcule = (prodDC > 0) ? (prodAC / prodDC) * 100.0 : 0.0;

    return RealtimeMeasurement(
      id: doc.id,
      consommationAC: (data['consommationAC'] as num?)?.toDouble() ?? 0.0,
      productionAC: prodAC,
      productionDC: prodDC,
      rendement: rendementCalcule,
      timestamp: ts,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'consommationAC': consommationAC,
      'productionAC': productionAC,
      'productionDC': productionDC,
      'rendement': rendement,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
