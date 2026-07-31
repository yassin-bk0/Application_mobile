import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/mesure_model.dart';

/// Service métier pour récupérer les données d'historique pré-agrégées 
/// depuis la nouvelle structure hiérarchique Firestore.
class MesureService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── JOUR (Lecture de la collection 'heures') ────────────────────────────────
  Future<List<MesureAgregee>> getAggregatedDataByHour(String userId, String installationId, DateTime date) async {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    try {
      final snapshot = await _firestore
          .collection('users').doc(userId)
          .collection('installations').doc(installationId)
          .collection('historique').doc('annees')
          .collection('docs').doc(year)
          .collection('mois').doc(month)
          .collection('jours').doc(day)
          .collection('heures')
          .orderBy(FieldPath.documentId) // "00h" à "23h"
          .get();

      if (snapshot.docs.isEmpty) return [];

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return MesureAgregee(
          periodeLabel: doc.id, // "08h"
          productionTotale: (data['productionAC_moyenne'] ?? data['productionAC'] ?? data['production'] ?? 0.0).toDouble(),
          productionDCTotale: (data['productionDC_moyenne'] ?? data['productionDC'] ?? 0.0).toDouble(),
          consommationTotale: (data['consommationAC_moyenne'] ?? data['consommationAC'] ?? data['consommation'] ?? 0.0).toDouble(),
        );
      }).toList();
    } catch (e) {
      debugPrint('[MesureService] Erreur getAggregatedDataByHour: $e');
      return [];
    }
  }

  Stream<List<MesureAgregee>> streamAggregatedDataByHour(String userId, String installationId, DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return _firestore
        .collection('users').doc(userId)
        .collection('installations').doc(installationId)
        .collection('historique').doc('annees')
        .collection('docs').doc(year)
        .collection('mois').doc(month)
        .collection('jours').doc(day)
        .collection('heures')
        .orderBy(FieldPath.documentId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) {
            final data = doc.data();
            
            final prodAC = (data['productionAC_moyenne'] ?? data['productionAC'] ?? data['production'] ?? 0.0).toDouble();
            final prodDC = (data['productionDC_moyenne'] ?? data['productionDC'] ?? 0.0).toDouble();
            
            // Auto-correction du rendement si on a modifié manuellement les mesures
            final storedRendement = (data['rendement'] ?? 0.0).toDouble();
            final calcRendement = prodDC > 0 ? (prodAC / prodDC) * 100.0 : 0.0;
            if ((storedRendement - calcRendement).abs() > 0.01) {
              doc.reference.update({'rendement': calcRendement}).catchError((_) {});
            }

            return MesureAgregee(
              periodeLabel: doc.id,
              productionTotale: prodAC,
              productionDCTotale: prodDC,
              consommationTotale: (data['consommationAC_moyenne'] ?? data['consommationAC'] ?? data['consommation'] ?? 0.0).toDouble(),
            );
          }).toList();

          // Recalculer le total du jour et mettre à jour le document parent 'jour'
          double totalProd = 0, totalProdDC = 0, totalCons = 0;
          for (var m in list) {
            totalProd += m.productionTotale;
            totalProdDC += m.productionDCTotale;
            totalCons += m.consommationTotale;
          }
          
          _firestore
            .collection('users').doc(userId)
            .collection('installations').doc(installationId)
            .collection('historique').doc('annees')
            .collection('docs').doc(year)
            .collection('mois').doc(month)
            .collection('jours').doc(day)
            .set({
              'total_production': totalProd,
              'total_productionDC': totalProdDC,
              'total_consommation': totalCons,
              'timestamp_update': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

          return list;
        });
  }

  // ── MOIS (Lecture de la collection 'jours') ────────────────────────────────
  Future<List<MesureAgregee>> getAggregatedDataByDay(String userId, String installationId, DateTime date) async {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');

    try {
      final snapshot = await _firestore
          .collection('users').doc(userId)
          .collection('installations').doc(installationId)
          .collection('historique').doc('annees')
          .collection('docs').doc(year)
          .collection('mois').doc(month)
          .collection('jours')
          .orderBy(FieldPath.documentId)
          .get();

      if (snapshot.docs.isEmpty) return [];

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return MesureAgregee(
          periodeLabel: '${doc.id}/$month', // "05/04"
          productionTotale: (data['total_production'] ?? 0.0).toDouble(),
          productionDCTotale: (data['total_productionDC'] ?? 0.0).toDouble(),
          consommationTotale: (data['total_consommation'] ?? 0.0).toDouble(),
        );
      }).toList();
    } catch (e) {
      debugPrint('[MesureService] Erreur getAggregatedDataByDay: $e');
      return [];
    }
  }

  Stream<List<MesureAgregee>> streamAggregatedDataByDay(String userId, String installationId, DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');

    return _firestore
        .collection('users').doc(userId)
        .collection('installations').doc(installationId)
        .collection('historique').doc('annees')
        .collection('docs').doc(year)
        .collection('mois').doc(month)
        .collection('jours')
        .orderBy(FieldPath.documentId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) {
            final data = doc.data();
            return MesureAgregee(
              periodeLabel: '${doc.id}/$month',
              productionTotale: (data['total_production'] ?? 0.0).toDouble(),
              productionDCTotale: (data['total_productionDC'] ?? 0.0).toDouble(),
              consommationTotale: (data['total_consommation'] ?? 0.0).toDouble(),
            );
          }).toList();

          // Recalculer le total du mois et mettre à jour le document parent 'mois'
          // Déclenché chaque fois qu'un document 'jours' change (ex: suite à une modif sur 'heures')
          double totalProd = 0, totalProdDC = 0, totalCons = 0;
          for (var m in list) {
            totalProd += m.productionTotale;
            totalProdDC += m.productionDCTotale;
            totalCons += m.consommationTotale;
          }
          
          _firestore
            .collection('users').doc(userId)
            .collection('installations').doc(installationId)
            .collection('historique').doc('annees')
            .collection('docs').doc(year)
            .collection('mois').doc(month)
            .set({
              'total_production': totalProd,
              'total_productionDC': totalProdDC,
              'total_consommation': totalCons,
              'timestamp_update': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

          return list;
        });
  }


  // ── ANNÉE (Lecture de la collection 'mois') ────────────────────────────────
  Future<List<MesureAgregee>> getAggregatedDataByMonth(String userId, String installationId, DateTime date) async {
    final year = date.year.toString();

    try {
      final snapshot = await _firestore
          .collection('users').doc(userId)
          .collection('installations').doc(installationId)
          .collection('historique').doc('annees')
          .collection('docs').doc(year)
          .collection('mois')
          .orderBy(FieldPath.documentId)
          .get();

      if (snapshot.docs.isEmpty) return [];

      const List<String> monthNames = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];

      return snapshot.docs.map((doc) {
        final data = doc.data();
        int monthIdx = int.tryParse(doc.id) ?? 1;
        return MesureAgregee(
          periodeLabel: monthNames[monthIdx - 1], // "Avr"
          productionTotale: (data['total_production'] ?? 0.0).toDouble(),
          productionDCTotale: (data['total_productionDC'] ?? 0.0).toDouble(),
          consommationTotale: (data['total_consommation'] ?? 0.0).toDouble(),
        );
      }).toList();
    } catch (e) {
      debugPrint('[MesureService] Erreur getAggregatedDataByMonth: $e');
      return [];
    }
  }

  // ── ANNÉE — VERSION STREAM TEMPS RÉEL ─────────────────────────────────────
  Stream<List<MesureAgregee>> streamAggregatedDataByMonth(String userId, String installationId, DateTime date) {
    final year = date.year.toString();
    const List<String> monthNames = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];

    return _firestore
        .collection('users').doc(userId)
        .collection('installations').doc(installationId)
        .collection('historique').doc('annees')
        .collection('docs').doc(year)
        .collection('mois')
        .orderBy(FieldPath.documentId)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return <MesureAgregee>[];
          final list = snapshot.docs.map((doc) {
            final data = doc.data();
            final monthIdx = int.tryParse(doc.id) ?? 1;
            return MesureAgregee(
              periodeLabel: monthNames[monthIdx - 1],
              productionTotale: (data['total_production'] ?? 0.0).toDouble(),
              productionDCTotale: (data['total_productionDC'] ?? 0.0).toDouble(),
              consommationTotale: (data['total_consommation'] ?? 0.0).toDouble(),
            );
          }).toList();

          // Recalculer le total de l'année et mettre à jour le document parent 'annee'
          double totalProd = 0, totalProdDC = 0, totalCons = 0;
          for (var m in list) {
            totalProd += m.productionTotale;
            totalProdDC += m.productionDCTotale;
            totalCons += m.consommationTotale;
          }
          
          _firestore
            .collection('users').doc(userId)
            .collection('installations').doc(installationId)
            .collection('historique').doc('annees')
            .collection('docs').doc(year)
            .set({
              'total_production': totalProd,
              'total_productionDC': totalProdDC,
              'total_consommation': totalCons,
              'timestamp_update': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

          return list;
        });
  }
}
