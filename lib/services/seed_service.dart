import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'fake_data_service.dart';

/// Service de seeding Firestore avec des données réalistes simulées.
///
/// Écrit dans DEUX collections :
/// 1. `real_time/current_data` — point temps réel actuel
/// 2. `historique/.../heures/{h}h` — agrégations horaires pour les graphiques
///
/// À appeler au démarrage en MODE TEST pour pré-remplir Firestore.
class SeedService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _basePath(String userId, String installationId) =>
      'users/$userId/installations/$installationId';

  /// Peuple les 24 dernières heures de données Firestore avec des données
  /// réalistes générées par [FakeDataService].
  ///
  /// - Nettoie d'abord les anciennes données `real_time` (hors current_data)
  /// - Écrit le document `current_data` avec les valeurs actuelles
  /// - Écrit les agrégations horaires dans la structure `historique/`
  Future<void> seedRealistic24hData({
    required String userId,
    required String installationId,
  }) async {
    debugPrint('[SeedService] 🌱 Début du seeding 24h...');

    try {
      final now = DateTime.now();

      // ── 1. Écrire current_data (temps réel) ──────────────────────────────
      await _writeCurrentData(userId, installationId, now);

      // ── 2. Écrire les agrégations horaires (pour les graphiques) ─────────
      await _writeHourlyAggregations(userId, installationId, now);

      debugPrint('[SeedService] ✅ Seeding terminé avec succès.');
    } catch (e) {
      debugPrint('[SeedService] ❌ Erreur lors du seeding: $e');
    }
  }

  /// Met à jour uniquement le document `current_data` (appelé toutes les 15 min).
  Future<void> updateCurrentData({
    required String userId,
    required String installationId,
  }) async {
    final now = DateTime.now();
    await _writeCurrentData(userId, installationId, now);
    debugPrint('[SeedService] 🔄 current_data mis à jour (${now.hour}h${now.minute.toString().padLeft(2, '0')})');
  }

  // ── Écriture current_data ─────────────────────────────────────────────────

  Future<void> _writeCurrentData(
    String userId,
    String installationId,
    DateTime now,
  ) async {
    final data = FakeDataService.generateForTime(now);

    final correctRef = _firestore
        .doc('${_basePath(userId, installationId)}/real_time/current_data');

    await correctRef.set({
      // Champs principaux
      'productionAC': data.pPv,
      'productionDC': data.productionDC,
      'consommationAC': data.pConsumer,
      'rendement': data.rendement,
      // Nouveaux champs
      'batteryPower': data.batteryPower,
      'batterySOC': data.batterySOC,
      'gridImport': data.gridImport,
      'gridExport': data.gridExport,
      'inverterTemp': data.inverterTemp,
      'voltage': data.vConsumer,
      'current': data.iConsumer,
      'frequency': data.frequency,
      'irradiation': data.irradiance,
      'bilanNet': data.bilanNet,
      // Métadonnées
      'timestamp': Timestamp.fromDate(now),
      'timestamp_update': FieldValue.serverTimestamp(),
      'periode': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      'mode': 'TEST',
      'source': 'FakeDataService',
    }, SetOptions(merge: false));
  }

  // ── Écriture agrégations horaires ─────────────────────────────────────────

  /// Écrit les agrégations horaires des 24 dernières heures dans Firestore.
  /// Chaque heure = moyenne de 6 points (1 point tous les 10 min).
  Future<void> _writeHourlyAggregations(
    String userId,
    String installationId,
    DateTime now,
  ) async {
    // On couvre les 25 dernières heures pour être sûr d'inclure l'heure courante
    final List<WriteBatch> batches = [];
    WriteBatch currentBatch = _firestore.batch();
    int opsInBatch = 0;

    for (int hBack = 24; hBack >= 0; hBack--) {
      final DateTime hourTime = now.subtract(Duration(hours: hBack));

      // Calculer la moyenne de l'heure (6 points tous les 10 min)
      double sumProdAC = 0, sumProdDC = 0, sumConsAC = 0;
      double sumBattPower = 0, sumBattSOC = 0;
      double sumGridImport = 0, sumGridExport = 0;
      int count = 0;

      for (int m = 0; m < 60; m += 10) {
        final DateTime pt = DateTime(
          hourTime.year, hourTime.month, hourTime.day, hourTime.hour, m);
        final pv = FakeDataService.generateForTime(pt);

        sumProdAC += pv.pPv;
        sumProdDC += pv.productionDC;
        sumConsAC += pv.pConsumer;
        sumBattPower += pv.batteryPower;
        sumBattSOC += pv.batterySOC;
        sumGridImport += pv.gridImport;
        sumGridExport += pv.gridExport;
        count++;
      }

      final double avgProdAC = sumProdAC / count;
      final double avgProdDC = sumProdDC / count;
      final double avgConsAC = sumConsAC / count;
      final double avgRendement = avgProdDC > 0 ? (avgProdAC / avgProdDC) * 100 : 0.0;

      final year = hourTime.year.toString();
      final month = hourTime.month.toString().padLeft(2, '0');
      final day = hourTime.day.toString().padLeft(2, '0');
      final hourLabel = '${hourTime.hour.toString().padLeft(2, '0')}h';

      final path =
          '${_basePath(userId, installationId)}/historique/annees/docs/$year/mois/$month/jours/$day/heures/$hourLabel';

      final docRef = _firestore.doc(path);
      currentBatch.set(docRef, {
        'productionAC_moyenne': avgProdAC,
        'productionDC_moyenne': avgProdDC,
        'consommationAC_moyenne': avgConsAC,
        'rendement_moyen': avgRendement,
        'batteryPower_moyenne': sumBattPower / count,
        'batterySOC_moyenne': sumBattSOC / count,
        'gridImport_moyenne': sumGridImport / count,
        'gridExport_moyenne': sumGridExport / count,
        'bilanNet_moyen': avgProdAC - avgConsAC,
        'nbMesures': count,
        'heure': hourTime.hour,
        'mode': 'TEST',
      }, SetOptions(merge: false));

      opsInBatch++;

      // Firestore limite les batches à 500 opérations
      if (opsInBatch >= 450) {
        batches.add(currentBatch);
        currentBatch = _firestore.batch();
        opsInBatch = 0;
      }
    }

    // Dernier batch
    if (opsInBatch > 0) batches.add(currentBatch);

    // Commit de tous les batches
    for (final batch in batches) {
      await batch.commit();
    }

    debugPrint('[SeedService] 📊 ${batches.length} batch(es) d\'agrégations horaires écrits.');
  }
}
