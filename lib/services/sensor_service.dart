import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/sensor_data.dart';

/// Service de lecture des données de capteurs ESP32 depuis Firestore.
///
/// L'ESP32 écrit dans :
///   users/{userId}/installations/{installationId}/sensors/latest
///
/// Structure attendue du document :
/// {
///   "luminosite": 45000,   // en lux
///   "temperature": 32.5,   // en °C
///   "timestamp": Timestamp
/// }
class SensorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Chemin du document "latest" pour les capteurs d'une installation.
  DocumentReference _sensorDoc(String userId, String installationId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('installations')
        .doc(installationId)
        .collection('sensors')
        .doc('latest');
  }

  // ── Lecture ponctuelle ──────────────────────────────────────────────────

  /// Récupère la dernière mesure des capteurs.
  /// Retourne [SensorData.offline()] si le document est absent ou trop vieux.
  Future<SensorData> getLatestSensorData(
    String userId,
    String installationId,
  ) async {
    try {
      final doc = await _sensorDoc(userId, installationId).get();

      if (!doc.exists || doc.data() == null) {
        debugPrint('[SensorService] ⚠️ Document sensors/latest absent.');
        return SensorData.offline();
      }

      final data = SensorData.fromFirestore(doc);
      debugPrint('[SensorService] ✅ Capteurs lus : $data');
      return data;
    } catch (e) {
      debugPrint('[SensorService] ❌ Erreur lecture capteurs : $e');
      return SensorData.offline();
    }
  }

  // ── Stream temps réel ───────────────────────────────────────────────────

  /// Stream Firestore du document sensors/latest.
  /// Émet [SensorData.offline()] si le document n'existe pas.
  Stream<SensorData> getSensorStream(String userId, String installationId) {
    return _sensorDoc(userId, installationId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        debugPrint('[SensorService] 📭 sensors/latest vide.');
        return SensorData.offline();
      }
      final data = SensorData.fromFirestore(doc);
      debugPrint('[SensorService] 📡 Mise à jour capteurs : $data');
      return data;
    }).handleError((e) {
      debugPrint('[SensorService] ❌ Erreur stream : $e');
      return SensorData.offline();
    });
  }

  // ── Écriture (utile pour les tests manuels / simulation ESP32) ──────────

  /// Écrit des données de capteurs simulées dans Firestore.
  /// Pratique pour tester sans ESP32 physique.
  Future<void> writeTestData({
    required String userId,
    required String installationId,
    required double luminosite,
    required double temperature,
  }) async {
    try {
      final data = SensorData(
        luminosite: luminosite,
        temperature: temperature,
        timestamp: DateTime.now(),
      );
      await _sensorDoc(userId, installationId).set(data.toMap());
      debugPrint('[SensorService] ✅ Données de test écrites : $data');
    } catch (e) {
      debugPrint('[SensorService] ❌ Erreur écriture test : $e');
    }
  }
}
