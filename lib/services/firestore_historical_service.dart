import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/realtime_measurement.dart';
import '../models/hourly_aggregation.dart';
import '../utils/date_utils_helper.dart';

class FirestoreHistoricalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _basePath(String userId, String installationId) {
    return 'users/$userId/installations/$installationId';
  }

  /// Agrège toutes les données de l'heure spécifiée et sauvegarde les moyennes.
  Future<void> aggregateLastHour({
    required String userId,
    required String installationId,
    required DateTime hourToAggregate,
  }) async {
    final start = DateTime(hourToAggregate.year, hourToAggregate.month, hourToAggregate.day, hourToAggregate.hour);
    final end = start.add(const Duration(hours: 1));

    // Récupérer les mesures de cette heure
    final snapshot = await _firestore
        .doc(_basePath(userId, installationId))
        .collection('real_time')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThan: Timestamp.fromDate(end))
        .get();

    if (snapshot.docs.isEmpty) {
      print('[FirestoreHistoricalService] No measurements found for this hour ($start)');
      return;
    }

    // Calculer les moyennes
    double totalConsAC = 0;
    double totalProdAC = 0;
    double totalProdDC = 0;
    int count = snapshot.docs.length;

    for (var doc in snapshot.docs) {
      final m = RealtimeMeasurement.fromFirestore(doc);
      totalConsAC += m.consommationAC;
      totalProdAC += m.productionAC;
      totalProdDC += m.productionDC;
    }

    final avgConsAC = totalConsAC / count;
    final avgProdAC = totalProdAC / count;
    final avgProdDC = totalProdDC / count;
    
    double rendementMoyen = 0;
    if (avgProdDC > 0) {
      rendementMoyen = (avgProdAC / avgProdDC) * 100;
    }

    final agg = HourlyAggregation(
      consommationAC_total: avgConsAC,
      productionAC_total: avgProdAC,
      productionDC_total: avgProdDC,
      rendement_moyen: rendementMoyen,
    );

    // Sauvegarder dans la structure hiérarchique
    final year = start.year.toString();
    final month = DateUtilsHelper.formatMonth(start.month);
    final day = DateUtilsHelper.formatDay(start.day);
    final hourLabel = DateUtilsHelper.formatHourLabel(start.hour);

    final baseRef = _firestore.doc(_basePath(userId, installationId)).collection('historique');
    final yearRef = baseRef.doc('annees').collection('docs').doc(year);
    final monthRef = yearRef.collection('mois').doc(month);
    final dayRef = monthRef.collection('jours').doc(day);
    final hourRef = dayRef.collection('heures').doc(hourLabel);
    
    final batch = _firestore.batch();
    
    try {
      // 1. Sauvegarde de l'heure
      batch.set(hourRef, agg.toMap(), SetOptions(merge: true));
      
      // 2. Mise à jour des parents (totaux)
      final parentsUpdate = {
        'total_productionDC': FieldValue.increment(avgProdDC), // On ajoute la moyenne horaire au total
        'timestamp_update': FieldValue.serverTimestamp(),
      };
      
      batch.set(yearRef, parentsUpdate, SetOptions(merge: true));
      batch.set(monthRef, parentsUpdate, SetOptions(merge: true));
      batch.set(dayRef, parentsUpdate, SetOptions(merge: true));

      await batch.commit();
      print('[FirestoreHistoricalService] Successfully aggregated hour $hourLabel and updated parents.');
    } catch (e) {
      print('[FirestoreHistoricalService] Error saving aggregation: $e');
    }
  }

  /// Liste toutes les heures agrégées pour un jour donné.
  Stream<QuerySnapshot<Map<String, dynamic>>> getHoursStream({
    required String userId,
    required String installationId,
    required int year,
    required int month,
    required int day,
  }) {
    final sMonth = DateUtilsHelper.formatMonth(month);
    final sDay = DateUtilsHelper.formatDay(day);

    final path = '${_basePath(userId, installationId)}/historique/annees/docs/$year/mois/$sMonth/jours/$sDay/heures';
    
    return _firestore.collection(path).snapshots();
  }

  /// Script de migration unique vers le nouveau format de champs (AC/DC/Rendement).
  Future<void> runMigration({required String userId, required String installationId}) async {
    final snapshot = await _firestore
        .doc(_basePath(userId, installationId))
        .collection('real_time')
        .get();

    final batch = _firestore.batch();
    int count = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (!data.containsKey('productionDC') || !data.containsKey('rendement')) {
        final prodAC = (data['productionAC'] ?? data['production'] ?? 0.0).toDouble();
        final consAC = (data['consommationAC'] ?? data['consommation'] ?? 0.0).toDouble();
        
        batch.update(doc.reference, {
          'productionAC': prodAC,
          'consommationAC': consAC,
          'productionDC': prodAC, // Par défaut, DC = AC lors de la migration
          'rendement': 100.0,
          'migrated': true,
        });
        count++;
      }
    }

    if (count > 0) {
      await batch.commit();
      print('[FirestoreHistoricalService] Migrated $count legacy documents for user $userId.');
    }
  }
}
