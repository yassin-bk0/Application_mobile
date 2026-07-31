import 'package:workmanager/workmanager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'firestore_measurement_service.dart';
import 'firebase_service.dart';
import '../models/pv_data.dart';

// Nom de la tâche
const String kMeasurementTask = "com.pv_monitor.measurement_task";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint("[Background] 🚀 Tâche de fond démarrée: $task");

    try {
      // 1. Initialiser Firebase en arrière-plan
      await Firebase.initializeApp();

      // 2. Récupérer les identifiants stockés
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      final instId = prefs.getString('installationId');

      if (userId == null || instId == null) {
        debugPrint("[Background] ⚠️ Identifiants manquants dans les SharedPreferences.");
        return Future.value(true);
      }

      // 3. Récupérer les données réelles depuis Firebase Realtime Database
      final firebaseService = FirebaseService();
      final pvData = await firebaseService.getLatestLiveReading();

      if (pvData == null) {
        debugPrint("[Background] ⚠️ Impossible de récupérer les données réelles (RTDB vide ou erreur).");
        return Future.value(false);
      }

      // 4. Utiliser le service Firestore pour sauvegarder la mesure réelle
      final service = FirestoreMeasurementService();
      await service.saveMeasurement(
        userId: userId,
        installationId: instId,
        consoAC: pvData.pConsumer,
        prodAC: pvData.pPv,
        prodDC: pvData.productionDC,
        sourceTimestamp: pvData.timestamp,
      );

      // 5. Vérifier si l'heure précédente doit être agrégée
      final now = DateTime.now();
      final lastAggHour = prefs.getInt('last_aggregated_hour') ?? -1;
      
      // Si on change d'heure (ex: il est 17:01 et on a pas agrégé 16h)
      if (now.hour != lastAggHour && lastAggHour != -1) {
        final hourToAgg = DateTime(now.year, now.month, now.day, lastAggHour);
        await service.aggregateHour(
          userId: userId,
          installationId: instId,
          hourToAggregate: hourToAgg,
        );
        await prefs.setInt('last_aggregated_hour', now.hour);
      } else if (lastAggHour == -1) {
        await prefs.setInt('last_aggregated_hour', now.hour);
      }

      return Future.value(true);
    } catch (e) {
      debugPrint("[Background] ❌ Erreur tâche de fond : $e");
      return Future.value(false);
    }
  });
}

class BackgroundService {
  static Future<void> init() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );
  }

  static Future<void> scheduleMeasurement() async {
    // Planifie une tâche périodique toutes les 15 minutes
    await Workmanager().registerPeriodicTask(
      "1",
      kMeasurementTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
    debugPrint("[BackgroundService] ⏰ Tâche périodique (15min) enregistrée.");
  }
}
