import 'package:cloud_firestore/cloud_firestore.dart';

/// Modèle pour les données d'énergie au niveau "Heure" dans Firestore.
class EnergyHourData {
  final double consommationAC;
  final double productionAC;
  final double? productionDC; // Optionnel (nouveau)
  final double? rendement;    // Optionnel (nouveau)
  final DateTime? timestampUpdate;

  EnergyHourData({
    required this.consommationAC,
    required this.productionAC,
    this.productionDC,
    this.rendement,
    this.timestampUpdate,
  });

  /// Crée une instance à partir d'un snapshot Firestore.
  factory EnergyHourData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    DateTime? ts;
    final rawTs = data['timestamp_update'];
    if (rawTs is Timestamp) {
      ts = rawTs.toDate();
    }

    return EnergyHourData(
      consommationAC: (data['consommationAC'] ?? data['consommation'] ?? 0.0).toDouble(),
      productionAC: (data['productionAC'] ?? data['production'] ?? 0.0).toDouble(),
      productionDC: data['productionDC'] != null ? (data['productionDC'] as num).toDouble() : null,
      rendement: data['rendement'] != null ? (data['rendement'] as num).toDouble() : null,
      timestampUpdate: ts,
    );
  }

  /// Convertit l'instance en Map pour Firestore.
  Map<String, dynamic> toMap() {
    return {
      'consommationAC': consommationAC,
      'productionAC': productionAC,
      'productionDC': productionDC,
      'rendement': rendement,
      'timestamp_update': timestampUpdate != null ? Timestamp.fromDate(timestampUpdate!) : FieldValue.serverTimestamp(),
    };
  }
}
