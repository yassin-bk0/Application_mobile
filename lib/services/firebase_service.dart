import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../models/energy_data_model.dart';
import '../models/pv_data.dart';

/// Repository that wraps all Firebase interactions for PV sensor data.
///
/// • Realtime Database  → live telemetry stream   (path: /pv_live)
/// • Cloud Firestore    → historical records store (collection: pv_readings)
class FirebaseService {
  // ── singletons ────────────────────────────────────────────────────────────
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  // Firestore collection for historical data
  static const String _collection = 'pv_readings';

  // Realtime Database node where the ESP32 pushes live readings
  static const String _liveNode = 'pv_live';

  // Internal RTDB stream subscription (kept so we can cancel it)
  StreamSubscription<DatabaseEvent>? _rtdbSubscription;

  // Public stream controller that the DataProvider listens to
  final StreamController<PvData> _liveController =
      StreamController<PvData>.broadcast();

  /// Stream of live [PvData] readings coming from the Realtime Database.
  Stream<PvData> get liveStream => _liveController.stream;

  // ── Live Stream ───────────────────────────────────────────────────────────

  /// Start listening to the `/pv_live` RTDB node.
  /// Call [stopLiveStream] to cancel when no longer needed.
  void startLiveStream() {
    final ref = _rtdb.ref(_liveNode);

    _rtdbSubscription = ref.onValue.listen(
      (DatabaseEvent event) {
        final data = event.snapshot.value;
        if (data == null) return;

        try {
          final map = Map<dynamic, dynamic>.from(data as Map);
          final pvData = PvData.fromMap(map);
          _liveController.add(pvData);
        } catch (e) {
          print('[FirebaseService] Error parsing RTDB data: $e');
        }
      },
      onError: (error) {
        print('[FirebaseService] RTDB stream error: $error');
        _liveController.addError(error);
      },
    );
  }

  /// Cancel the RTDB listener.
  void stopLiveStream() {
    _rtdbSubscription?.cancel();
    _rtdbSubscription = null;
  }

  /// Fetch a single snapshot of the current live data from RTDB.
  Future<PvData?> getLatestLiveReading() async {
    try {
      final snapshot = await _rtdb.ref(_liveNode).get();
      if (!snapshot.exists || snapshot.value == null) return null;
      
      final map = Map<dynamic, dynamic>.from(snapshot.value as Map);
      return PvData.fromMap(map);
    } catch (e) {
      debugPrint('[FirebaseService] Error getting latest live reading: $e');
      return null;
    }
  }

  /// Close the broadcast stream controller. Call from [DataProvider.dispose].
  void dispose() {
    stopLiveStream();
    _liveController.close();
  }

  // ── Firestore Writes ──────────────────────────────────────────────────────

  /// Push a single [PvData] reading to the `pv_readings` Firestore collection.
  ///
  /// The timestamp is stored as a Firestore [Timestamp] for precise ordering
  /// in addition to the epoch-ms integer inside [PvData.toMap].
  /// Push a single [PvData] reading to both the 'real_time' collection
  /// and the hierarchical 'historique' structure.
  Future<void> pushDataToFirestore({
    required String userId,
    required String installationId,
    required PvData data,
  }) async {
    try {
      final now = data.timestamp;
      final year = now.year.toString();
      final month = now.month.toString().padLeft(2, '0');
      final day = now.day.toString().padLeft(2, '0');
      final hour = '${now.hour.toString().padLeft(2, '0')}h';
      
      // Chemin Firestore dynamique
      final hourPath = getHeureDocumentPath(
        userId: userId, 
        installationId: installationId, 
        annee: now.year, 
        mois: now.month, 
        jour: now.day, 
        heure: hour
      );

      final map = {
        'timestamp': Timestamp.fromDate(now),
        'productionAC': data.pPv, // Mise à jour du nom du champ
        'consommationAC': data.pConsumer, // Mise à jour du nom du champ
        'temperature': data.temperature,
        'humidity': data.humidity,
        'vPv': data.vPv,
        'iPv': data.iPv,
        'vConsumer': data.vConsumer,
        'iConsumer': data.iConsumer,
      };

      // 1. Write to raw 'real_time' collection
      final realTimePath = 'users/$userId/installations/$installationId/real_time';
      debugPrint('[FirebaseService] 📝 Écriture real-time: $realTimePath');
      
      final batch = _firestore.batch();
      
      final realTimeRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('installations')
          .doc(installationId)
          .collection('real_time')
          .doc('current_data'); // Utilisation de l'ID fixe 'current_data'
      
      batch.set(realTimeRef, map);

      // 2. Update/Set the hierarchical history structure
      // Les documents parents (annees, mois, jours) seront calculés automatiquement par les Streams Flutter
      // pour éviter les incrémentations infinies et fausses.

      final hourRef = _firestore.doc(hourPath);
      batch.set(hourRef, {
        'productionAC': data.pPv,
        'productionDC': data.productionDC,
        'rendement': data.rendement,
        'consommationAC': data.pConsumer,
        'timestamp_update': Timestamp.now(),
      }, SetOptions(merge: true));

      await batch.commit();
      debugPrint('[FirebaseService] ✅ Hiérarchie Historique mise à jour avec succès !');
    } catch (e) {
      debugPrint('[FirebaseService] ❌ Erreur écriture hiérarchie : $e');
    }
  }

  // ── Firestore Reads ───────────────────────────────────────────────────────

  /// Fetch the most recent [limit] readings from Firestore, ordered by time.
  ///
  /// Returns an empty list on any error so the caller always gets a valid list.
  Future<List<PvData>> getHistoricalData({int limit = 500}) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      final results = snapshot.docs.map((doc) {
        final raw = doc.data();
        // Normalise the Firestore Timestamp to epoch-ms before passing to fromMap
        final ts = raw['timestamp'];
        if (ts is Timestamp) {
          raw['timestamp'] = ts.millisecondsSinceEpoch;
        }
        return PvData.fromMap(raw);
      }).toList();

      // Re-order ascending (oldest first) for the history chart
      results.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return results;
    } catch (e) {
      print('[FirebaseService] Firestore read error: $e');
      return [];
    }
  }

  /// Real-time Firestore stream of newly added readings.
  ///
  /// Useful as an alternative/complement to RTDB when the RTDB node is empty
  /// (e.g. during development without physical ESP32).
  Stream<PvData> firestoreNewReadingsStream() {
    return _firestore
        .collection(_collection)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) throw Exception('No data');
      final raw = snapshot.docs.first.data();
      final ts = raw['timestamp'];
      if (ts is Timestamp) {
        raw['timestamp'] = ts.millisecondsSinceEpoch;
      }
      return PvData.fromMap(raw);
    });
  }
  // ── Production DC & Rendement Logic ───────────────────────────────────────

  /// 1. Fonction pour obtenir le chemin Firestore dynamique demandé :
  /// /users/{userId}/installations/{installationId}/historique/annees/docs/{année}/mois/{mois}/jours/{jour}/heures/{heure}
  String getHeureDocumentPath({
    required String userId,
    required String installationId,
    required int annee,
    required int mois,
    required int jour,
    required String heure,
  }) {
    final sMois = mois.toString().padLeft(2, '0');
    final sJour = jour.toString().padLeft(2, '0');
    return 'users/$userId/installations/$installationId/historique/annees/docs/$annee/mois/$sMois/jours/$sJour/heures/$heure';
  }

  /// 2. Fonction pour ajouter/mettre à jour productionDC et rendement :
  Future<void> addProductionDCAndRendement({
    required String userId,
    required String installationId,
    required int annee,
    required int mois,
    required int jour,
    required String heure,
    required double productionDC,
  }) async {
    final path = getHeureDocumentPath(
      userId: userId,
      installationId: installationId,
      annee: annee,
      mois: mois,
      jour: jour,
      heure: heure,
    );
    final docRef = _firestore.doc(path);

    try {
      // Lire le document existant pour récupérer productionAC
      final snapshot = await docRef.get();
      
      double productionAC = 0.0;
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        // Gérer les deux noms possibles au cas où
        productionAC = (data['productionAC'] ?? data['production'] ?? 0.0).toDouble();
      }

      // Calculer rendement = (productionAC / productionDC) * 100
      double rendement = 0.0;
      if (productionDC > 0) {
        rendement = (productionAC / productionDC) * 100;
      }

      // Faire update() du document (ne pas supprimer consommationAC et productionAC existants)
      await docRef.update({
        'productionDC': productionDC,
        'rendement': rendement,
        'timestamp_update': FieldValue.serverTimestamp(),
      });
      debugPrint('[FirebaseService] Doc mis à jour : productionDC=$productionDC, rendement=$rendement%');
      
    } catch (e) {
      debugPrint('[FirebaseService] Erreur lors de la mise à jour DC/Rendement : $e');
      // Si le document n'existe pas, update() échouera. 
      // On pourrait choisir de faire un set(..., SetOptions(merge: true)) si on veut créer le doc.
      rethrow;
    }
  }

  /// 3. Flux (Stream) pour le widget d'affichage
  Stream<EnergyHourData> getHeureStream({
    required String userId,
    required String installationId,
    required int annee,
    required int mois,
    required int jour,
    required String heure,
  }) {
    final path = getHeureDocumentPath(
      userId: userId,
      installationId: installationId,
      annee: annee,
      mois: mois,
      jour: jour,
      heure: heure,
    );
    return _firestore.doc(path).snapshots().map((doc) => EnergyHourData.fromFirestore(doc));
  }
}
