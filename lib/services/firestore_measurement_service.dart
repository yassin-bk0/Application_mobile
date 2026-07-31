import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import '../models/measurement_models.dart';


class FirestoreMeasurementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _basePath(String userId, String installationId) {
    return 'users/$userId/installations/$installationId';
  }

  /// Sauvegarde une mesure individuelle toutes les 30 min.
  Future<void> saveMeasurement({
    required String userId,
    required String installationId,
    required double consoAC,
    required double prodAC,
    required double prodDC,
    DateTime? sourceTimestamp,
  }) async {
    try {
      final now = DateTime.now();
      final docId = 'current_data'; // Utilisation de l'ID fixe 'current_data'
      final periode = DateFormat('HH:mm').format(now);
      
      double rendement = 0.0;
      if (prodDC > 0) {
        rendement = (prodAC / prodDC) * 100;
      }

      final docRef = _firestore
          .doc(_basePath(userId, installationId))
          .collection('real_time')
          .doc(docId);

      // 1. Lire d'abord les données existantes (Toujours lire avant d'écrire)
      final existingDoc = await docRef.get();
      if (existingDoc.exists && sourceTimestamp != null) {
        final existingData = existingDoc.data()!;
        final existingTs = (existingData['timestamp_update'] as Timestamp?)?.toDate() 
                        ?? (existingData['timestamp'] as Timestamp?)?.toDate();
        
        // Si le document Firestore a été mis à jour plus récemment que la donnée source (ex: modif manuelle)
        // on n'écrase pas.
        if (existingTs != null && existingTs.isAfter(sourceTimestamp)) {
          debugPrint('[FirestoreMeasurementService] ⚠️ Donnée source obsolète. Firestore est plus récent. Ignoré.');
          return;
        }
      }

      final measurement = {
        'consommationAC': consoAC,
        'productionAC': prodAC,
        'productionDC': prodDC,
        'rendement': rendement,
        'timestamp': Timestamp.fromDate(now),
        'timestamp_update': FieldValue.serverTimestamp(),
        'periode': periode,
      };

      await docRef.set(measurement, SetOptions(merge: true));

      debugPrint('[FirestoreMeasurementService] ✅ Mesure sauvegardée: $docId');
    } catch (e) {
      debugPrint('[FirestoreMeasurementService] ❌ Erreur saveMeasurement: $e');
    }
  }

  /// Agrège les mesures de l'heure spécifiée (00 et 30 min).
  Future<void> aggregateHour({
    required String userId,
    required String installationId,
    required DateTime hourToAggregate,
  }) async {
    try {
      final dateStr = DateFormat('yyyyMMdd').format(hourToAggregate);
      final hourPrefix = '${dateStr}_${hourToAggregate.hour.toString().padLeft(2, '0')}';
      
      final snapshot = await _firestore
          .doc(_basePath(userId, installationId))
          .collection('real_time')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: '${hourPrefix}00')
          .where(FieldPath.documentId, isLessThanOrEqualTo: '${hourPrefix}59')
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint('[FirestoreMeasurementService] ⚠️ Aucune donnée pour l\'heure: $hourPrefix');
        return;
      }

      double totalConsAC = 0;
      double totalProdAC = 0;
      double totalProdDC = 0;
      int count = snapshot.docs.length;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        totalConsAC += (data['consommationAC'] as num?)?.toDouble() ?? 0.0;
        totalProdAC += (data['productionAC'] as num?)?.toDouble() ?? 0.0;
        totalProdDC += (data['productionDC'] as num?)?.toDouble() ?? 0.0;
      }

      final avgConsAC = totalConsAC / count;
      final avgProdAC = totalProdAC / count;
      final avgProdDC = totalProdDC / count;
      
      double rendementMoyen = 0;
      if (avgProdDC > 0) {
        rendementMoyen = (avgProdAC / avgProdDC) * 100;
      }

      final year = hourToAggregate.year.toString();
      final month = hourToAggregate.month.toString().padLeft(2, '0');
      final day = hourToAggregate.day.toString().padLeft(2, '0');
      final hourLabel = '${hourToAggregate.hour.toString().padLeft(2, '0')}h';

      final agg = HourlyAggregation(
        heure: hourToAggregate.hour,
        consommationAC_moyenne: avgConsAC,
        productionAC_moyenne: avgProdAC,
        productionDC_moyenne: avgProdDC,
        rendement_moyen: rendementMoyen,
        nbMesures: count,
      );

      final path = 'users/$userId/installations/$installationId/historique/annees/docs/$year/mois/$month/jours/$day/heures/$hourLabel';
      
      await _firestore.doc(path).set(agg.toMap(), SetOptions(merge: true));
      debugPrint('[FirestoreMeasurementService] ✅ Agrégation terminée pour l\'heure: $hourLabel');
    } catch (e) {
      debugPrint('[FirestoreMeasurementService] ❌ Erreur aggregateHour: $e');
    }
  }

  /// Récupère la toute dernière mesure effectuée.
  Future<RealtimeMeasurement?> getLastMeasurement(String userId, String installationId) async {
    final snapshot = await _firestore
        .doc(_basePath(userId, installationId))
        .collection('real_time')
        .get();

    if (snapshot.docs.isEmpty) return null;
    
    // Tri par le champ timestamp réel (plus récent en premier)
    final docs = snapshot.docs.toList();
    docs.sort((a, b) {
      final tA = (a.data()['timestamp'] as Timestamp?)?.toDate() ?? DateTime(2000);
      final tB = (b.data()['timestamp'] as Timestamp?)?.toDate() ?? DateTime(2000);
      return tB.compareTo(tA);
    });
    
    return RealtimeMeasurement.fromFirestore(docs.first);
  }

  /// Récupère les agrégations horaires d'une journée précise.
  Future<List<HourlyAggregation>> getHourlyAggregations(String userId, String installationId, DateTime date) async {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    final path = 'users/$userId/installations/$installationId/historique/annees/docs/$year/mois/$month/jours/$day/heures';
    
    try {
      final snapshot = await _firestore.collection(path).get();
      final aggs = snapshot.docs.map((doc) => HourlyAggregation.fromFirestore(doc)).toList();
      aggs.sort((a, b) => a.heure.compareTo(b.heure));
      return aggs;
    } catch (e) {
      debugPrint('[Historique] Erreur : $e');
      return [];
    }
  }

  /// Stream temps réel du document 'current_data' (unique source de vérité Firestore).
  /// Implémentation robuste :
  /// - includeMetadataChanges: true pour réactivité instantanée offline/online
  /// - Auto-reconnexion en cas d'erreur ou timeout
  /// - StreamController permanent
  Stream<RealtimeMeasurement?> getLastMeasurementStream(String userId, String installationId) {
    debugPrint('[FirestoreService] 👂 Initialisation stream robuste current_data pour $userId/$installationId');
    
    StreamController<RealtimeMeasurement?>? controller;
    StreamSubscription? subscription;

    void startListening() {
      debugPrint('[FirestoreService] 🚀 Démarrage de l\'écoute Firestore (snapshots) ...');
      subscription?.cancel();
      
      subscription = _firestore
          .doc(_basePath(userId, installationId))
          .collection('real_time')
          .doc('current_data')
          .snapshots(includeMetadataChanges: true)
          .listen(
        (doc) {
          if (!doc.exists) {
            debugPrint('[FirestoreService] 📭 Document current_data inexistant.');
            if (controller != null && !controller!.isClosed) {
              controller!.add(null);
            }
            return;
          }

          try {
            final data = doc.data() as Map<String, dynamic>;
            final prodAC = (data['productionAC'] as num?)?.toDouble() ?? 0.0;
            final prodDC = (data['productionDC'] as num?)?.toDouble() ?? 0.0;
            final storedRendement = (data['rendement'] as num?)?.toDouble() ?? 0.0;
            final calculatedRendement = (prodDC > 0) ? (prodAC / prodDC) * 100.0 : 0.0;

            // Auto-correction Firestore si modif manuelle
            if ((storedRendement - calculatedRendement).abs() > 0.01) {
              debugPrint('[FirestoreService] 🔧 Rendement désynchronisé ($storedRendement% → ${calculatedRendement.toStringAsFixed(2)}%). Correction...');
              doc.reference.update({'rendement': calculatedRendement}).catchError((e) {
                debugPrint('[FirestoreService] ❌ Erreur correction rendement: $e');
              });
            }

            final isFromCache = doc.metadata.isFromCache;
            debugPrint('[FirestoreService] ✅ Snapshot reçu (Cache: $isFromCache) — prodAC: $prodAC, rendement: ${calculatedRendement.toStringAsFixed(2)}%');
            
            if (controller != null && !controller!.isClosed) {
              controller!.add(RealtimeMeasurement.fromFirestore(doc));
            }
          } catch (e) {
            debugPrint('[FirestoreService] ❌ Erreur parsing: $e');
          }
        },
        onError: (error) {
          debugPrint('[FirestoreService] ❌ Erreur critique stream Firestore: $error');
          debugPrint('[FirestoreService] 🔄 Tentative de reconnexion dans 5 secondes...');
          // Reconnexion automatique
          Future.delayed(const Duration(seconds: 5), () {
            if (controller != null && !controller!.isClosed) {
              startListening();
            }
          });
        },
        cancelOnError: false, // Ne pas fermer le stream principal en cas d'erreur
      );
    }

    controller = StreamController<RealtimeMeasurement?>.broadcast(
      onListen: () {
        debugPrint('[FirestoreService] 🟢 Un widget écoute le stream.');
        startListening();
      },
      onCancel: () {
        debugPrint('[FirestoreService] 🛑 Tous les widgets ont arrêté d\'écouter.');
        subscription?.cancel();
      },
    );

    return controller.stream;
  }

  // ── GRAPHIQUES : Stream combiné historique + temps réel ─────────────────


  ///
  /// Écoute en temps réel la collection `heures` de chaque jour compris
  /// dans la fenêtre (1H, 6H, 24H). Tout nouveau document horaire créé ou
  /// modifié dans Firestore rafraîchit le graphique automatiquement.
  /// Écoute aussi `current_data` pour le point live instantané.
  Stream<List<RealtimeMeasurement>> getChartStream({
    required String userId,
    required String installationId,
    required Duration window,
  }) {
    final controller = StreamController<List<RealtimeMeasurement>>();
    final subs = <StreamSubscription>[];

    final now = DateTime.now();
    final cutoff = now.subtract(window);

    // Déterminer tous les jours calendaires couverts par la fenêtre
    final days = <DateTime>[];
    var dayCursor = DateTime(cutoff.year, cutoff.month, cutoff.day);
    final today = DateTime(now.year, now.month, now.day);
    while (!dayCursor.isAfter(today)) {
      days.add(dayCursor);
      dayCursor = dayCursor.add(const Duration(days: 1));
    }

    // Cache mémoire des points horaires. Clé = "{dayStr}_{hLabel}" pour éviter
    // les collisions entre jours différents (ex: 20h du 07 vs 20h du 08).
    final Map<String, RealtimeMeasurement> hourlyCache = {};
    RealtimeMeasurement? livePoint;

    void emit() {
      if (controller.isClosed) return;
      final windowCutoff = DateTime.now().subtract(window);

      // Inclure toutes les heures dont le début est dans la fenêtre
      // OU juste avant (1h de marge pour ne pas couper la première heure partielle).
      final combined = hourlyCache.values
          .where((m) => m.timestamp.isAfter(
              windowCutoff.subtract(const Duration(hours: 1))))
          .toList();

      // Toujours inclure le point "live" et forcer son timestamp à "maintenant".
      // Même si l'ESP32 s'est déconnecté il y a 2 heures, c'est la dernière valeur connue.
      // Cela garantit qu'il sera trié à la fin et affiché au bord droit du graphique.
      if (livePoint != null) {
        combined.removeWhere((m) => m.id == 'current_data');
        final currentLivePoint = RealtimeMeasurement(
          id: livePoint!.id,
          consommationAC: livePoint!.consommationAC,
          productionAC: livePoint!.productionAC,
          productionDC: livePoint!.productionDC,
          rendement: livePoint!.rendement,
          timestamp: DateTime.now(),
          periode: livePoint!.periode,
        );
        combined.add(currentLivePoint);
      }

      // Toujours trier APRES avoir ajouté le point live pour garantir 
      // que les timestamps (axe X) soient strictement croissants.
      combined.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      controller.add(combined);
    }

    // ── Listener sur la collection heures/ de chaque jour ──────────────────
    for (final day in days) {
      final yearStr  = day.year.toString();
      final monthStr = day.month.toString().padLeft(2, '0');
      final dayStr   = day.day.toString().padLeft(2, '0');

      final heuresRef = _firestore
          .doc(_basePath(userId, installationId))
          .collection('historique').doc('annees')
          .collection('docs').doc(yearStr)
          .collection('mois').doc(monthStr)
          .collection('jours').doc(dayStr)
          .collection('heures');

      subs.add(heuresRef.snapshots().listen((snapshot) {
        for (final doc in snapshot.docs) {
          final d = doc.data();
          final hourInt = int.tryParse(doc.id.replaceAll('h', '')) ?? 0;
          final ts = DateTime(day.year, day.month, day.day, hourInt);

          final prodAC = (d['productionAC_moyenne'] ?? d['productionAC'] ?? 0.0).toDouble();
          final prodDC = (d['productionDC_moyenne'] ?? d['productionDC'] ?? 0.0).toDouble();
          final consAC = (d['consommationAC_moyenne'] ?? d['consommationAC'] ?? 0.0).toDouble();
          final rendement = prodDC > 0 ? (prodAC / prodDC) * 100.0 : 0.0;

          hourlyCache['${dayStr}_${doc.id}'] = RealtimeMeasurement(
            id: doc.id,
            consommationAC: consAC,
            productionAC: prodAC,
            productionDC: prodDC,
            rendement: rendement,
            timestamp: ts,
            periode: doc.id,
          );
        }

        // Retirer du cache les documents supprimés depuis Firestore
        final activeKeys = snapshot.docs.map((d) => '${dayStr}_${d.id}').toSet();
        hourlyCache.removeWhere(
            (k, _) => k.startsWith('${dayStr}_') && !activeKeys.contains(k));

        debugPrint('[ChartsService] 🔄 heures/$dayStr → ${snapshot.docs.length} docs. Cache: ${hourlyCache.length} total.');
        emit();
      }, onError: (e) {
        debugPrint('[ChartsService] ❌ Erreur snapshot heures/$dayStr: $e');
      }));
    }

    // ── Listener sur current_data (point live) ─────────────────────────────
    // On réutilise getLastMeasurementStream qui est déjà robuste (reconnexion auto, cache, etc.)
    subs.add(getLastMeasurementStream(userId, installationId).listen((measurement) {
      if (controller.isClosed) return;
      livePoint = measurement;
      emit();
    }, onError: (e) {
      debugPrint('[ChartsService] ❌ Erreur live stream: $e');
    }));

    controller.onCancel = () {
      for (final s in subs) { s.cancel(); }
      if (!controller.isClosed) controller.close();
    };


    return controller.stream;
  }


  /// @deprecated — utilisez getChartStream à la place.
  /// Conservé pour compatibilité éventuelle.
  Stream<List<RealtimeMeasurement>> getRecentMeasurementsStream(
      String userId, String installationId, Duration window) {
    return getChartStream(
        userId: userId, installationId: installationId, window: window);
  }


  /// Récupère les agrégations journalières d'un mois précis.
  Future<List<Map<String, dynamic>>> getDailyAggregations(String userId, String installationId, DateTime date) async {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');

    final path = 'users/$userId/installations/$installationId/historique/annees/docs/$year/mois/$month/jours';
    
    final snapshot = await _firestore.collection(path).get();
    
    final results = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'label': '${doc.id}/$month',
        'productionAC': (data['total_production'] ?? data['productionAC'] ?? 0.0).toDouble(),
        'productionDC': (data['total_productionDC'] ?? data['productionDC'] ?? 0.0).toDouble(),
        'consommationAC': (data['total_consommation'] ?? data['consommationAC'] ?? 0.0).toDouble(),
      };
    }).toList();

    results.sort((a, b) => a['label'].compareTo(b['label']));
    return results;
  }

  /// Récupère les agrégations mensuelles d'une année précise.
  Future<List<Map<String, dynamic>>> getMonthlyAggregations(String userId, String installationId, DateTime date) async {
    final year = date.year.toString();
    const monthNames = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];

    final path = 'users/$userId/installations/$installationId/historique/annees/docs/$year/mois';
    
    final snapshot = await _firestore.collection(path).get();
    
    final results = snapshot.docs.map((doc) {
      final data = doc.data();
      final monthIdx = int.tryParse(doc.id) ?? 1;
      return {
        'label': monthNames[monthIdx - 1],
        'productionAC': (data['total_production'] ?? data['productionAC'] ?? 0.0).toDouble(),
        'productionDC': (data['total_productionDC'] ?? data['productionDC'] ?? 0.0).toDouble(),
        'consommationAC': (data['total_consommation'] ?? data['consommationAC'] ?? 0.0).toDouble(),
      };
    }).toList();

    return results;
  }
}
