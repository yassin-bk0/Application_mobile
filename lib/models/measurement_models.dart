import 'package:cloud_firestore/cloud_firestore.dart';

/// Mesure individuelle toutes les 30 minutes
class RealtimeMeasurement {
  final String id; // format: "yyyyMMdd_HHmm" ex: "20260407_1630"
  final double consommationAC;
  final double productionAC;
  final double productionDC;
  final double rendement;
  final DateTime timestamp;
  final String periode; // "16:00" ou "16:30"

  RealtimeMeasurement({
    required this.id,
    required this.consommationAC,
    required this.productionAC,
    required this.productionDC,
    required this.rendement,
    required this.timestamp,
    required this.periode,
  });

  factory RealtimeMeasurement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final prodAC = (data['productionAC'] as num?)?.toDouble() ?? 0.0;
    final prodDC = (data['productionDC'] as num?)?.toDouble() ?? 0.0;

    // Recalcul dynamique — le champ 'rendement' stocké est ignoré
    // pour éviter la désynchronisation lors de modifications manuelles.
    final rendementCalcule = (prodDC > 0) ? (prodAC / prodDC) * 100.0 : 0.0;

    return RealtimeMeasurement(
      id: doc.id,
      consommationAC: (data['consommationAC'] as num?)?.toDouble() ?? 0.0,
      productionAC: prodAC,
      productionDC: prodDC,
      rendement: rendementCalcule,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      periode: data['periode'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'consommationAC': consommationAC,
      'productionAC': productionAC,
      'productionDC': productionDC,
      'rendement': rendement,
      'timestamp': Timestamp.fromDate(timestamp),
      'periode': periode,
    };
  }
}

/// Agrégation hebdomadaire (moyenne des 2 mesures de l'heure)
class HourlyAggregation {
  final int heure; // 16
  final double consommationAC_moyenne;
  final double productionAC_moyenne;
  final double productionDC_moyenne;
  final double rendement_moyen;
  final int nbMesures; // 1 ou 2

  HourlyAggregation({
    required this.heure,
    required this.consommationAC_moyenne,
    required this.productionAC_moyenne,
    required this.productionDC_moyenne,
    required this.rendement_moyen,
    required this.nbMesures,
  });

  factory HourlyAggregation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final prodACMoy = (data['productionAC_moyenne'] as num?)?.toDouble() ?? 0.0;
    final prodDCMoy = (data['productionDC_moyenne'] as num?)?.toDouble() ?? 0.0;

    // Recalcul dynamique du rendement moyen
    final rendementMoyCalc = (prodDCMoy > 0) ? (prodACMoy / prodDCMoy) * 100.0 : 0.0;

    return HourlyAggregation(
      heure: int.tryParse(doc.id.replaceFirst('h', '')) ?? 0,
      consommationAC_moyenne: (data['consommationAC_moyenne'] as num?)?.toDouble() ?? 0.0,
      productionAC_moyenne: prodACMoy,
      productionDC_moyenne: prodDCMoy,
      rendement_moyen: rendementMoyCalc,
      nbMesures: data['nbMesures'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'consommationAC_moyenne': consommationAC_moyenne,
      'productionAC_moyenne': productionAC_moyenne,
      'productionDC_moyenne': productionDC_moyenne,
      'rendement_moyen': rendement_moyen,
      'nbMesures': nbMesures,
      'timestamp_update': FieldValue.serverTimestamp(),
    };
  }
}
