import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/realtime_measurement.dart';
import '../utils/date_utils_helper.dart';

class FirestoreRealtimeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Sauvegarde une mesure en temps réel avec ID fixe 'current_data' pour optimiser
  Future<void> saveRealtimeMeasurement({
    required String userId,
    required String installationId,
    required double consommationAC,
    required double productionAC,
    required double productionDC,
    DateTime? sourceTimestamp,
  }) async {
    final now = DateTime.now();
    
    // Calcul automatique du rendement
    double rendement = 0.0;
    if (productionDC > 0) {
      rendement = (productionAC / productionDC) * 100;
    }

    final measurement = RealtimeMeasurement(
      id: 'current_data',
      consommationAC: consommationAC,
      productionAC: productionAC,
      productionDC: productionDC,
      rendement: rendement,
      timestamp: now,
    );

    final docRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('installations')
        .doc(installationId)
        .collection('real_time')
        .doc('current_data');

    try {
      // Lire avant d'écrire pour ne pas écraser une modif manuelle plus récente
      final existingDoc = await docRef.get();
      if (existingDoc.exists && sourceTimestamp != null) {
        final existingData = existingDoc.data()!;
        final existingTs = (existingData['timestamp_update'] as Timestamp?)?.toDate() 
                        ?? (existingData['timestamp'] as Timestamp?)?.toDate();
        
        if (existingTs != null && existingTs.isAfter(sourceTimestamp)) {
          print('[FirestoreRealtimeService] ⚠️ Donnée source obsolète. Firestore est plus récent. Ignoré.');
          return;
        }
      }

      await docRef.set(measurement.toMap()..addAll({'timestamp_update': FieldValue.serverTimestamp()}), SetOptions(merge: true));
    } catch (e) {
      print('[FirestoreRealtimeService] Error saving realtime data: $e');
      rethrow;
    }
  }

  /// Écoute la mesure en temps réel (un seul document 'current_data')
  Stream<List<RealtimeMeasurement>> getRealtimeStream({
    required String userId,
    required String installationId,
    int limit = 50,
  }) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('installations')
        .doc(installationId)
        .collection('real_time')
        .doc('current_data')
        .snapshots()
        .map((doc) {
      if (!doc.exists) return [];
      return [RealtimeMeasurement.fromFirestore(doc)];
    });
  }
}
