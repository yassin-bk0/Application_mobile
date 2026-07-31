import 'package:cloud_firestore/cloud_firestore.dart';

class HourlyAggregation {
  final double consommationAC_total; // Moyenne horaire
  final double productionAC_total; // Moyenne horaire
  final double productionDC_total; // Moyenne horaire
  final double rendement_moyen;    // (Moyenne AC / Moyenne DC) * 100

  HourlyAggregation({
    required this.consommationAC_total,
    required this.productionAC_total,
    required this.productionDC_total,
    required this.rendement_moyen,
  });

  factory HourlyAggregation.fromMap(Map<String, dynamic> data) {
    return HourlyAggregation(
      consommationAC_total: (data['consommationAC_moyenne'] ?? data['consommationAC_total'] ?? data['consommationAC'] ?? 0.0).toDouble(),
      productionAC_total: (data['productionAC_moyenne'] ?? data['productionAC_total'] ?? data['productionAC'] ?? 0.0).toDouble(),
      productionDC_total: (data['productionDC_moyenne'] ?? data['productionDC_total'] ?? data['productionDC'] ?? 0.0).toDouble(),
      rendement_moyen: (data['rendement_moyen'] ?? data['rendement'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'consommationAC': consommationAC_total,
      'productionAC': productionAC_total,
      'productionDC': productionDC_total,
      'rendement': rendement_moyen,
      'timestamp_update': FieldValue.serverTimestamp(),
    };
  }
}
