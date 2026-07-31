import 'dart:async';
import 'package:flutter/foundation.dart';
import 'firestore_historical_service.dart';

class AggregationScheduler {
  static final AggregationScheduler _instance = AggregationScheduler._internal();
  factory AggregationScheduler() => _instance;
  AggregationScheduler._internal();

  Timer? _timer;
  final FirestoreHistoricalService _histService = FirestoreHistoricalService();
  String? _currentUserId;
  String? _currentInstallationId;

  /// Démarre le planificateur. 
  /// Vérifie chaque seconde s'il est temps d'agréger.
  void start({required String userId, required String installationId}) {
    if (_timer != null) stop();
    _currentUserId = userId;
    _currentInstallationId = installationId;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      
      // On déclenche à HH:59:55
      if (now.minute == 59 && now.second == 55) {
        _triggerAggregation(now);
      }
    });
    
    debugPrint('[AggregationScheduler] Started for $installationId (User: $userId)');
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    debugPrint('[AggregationScheduler] Stopped');
  }

  Future<void> _triggerAggregation(DateTime time) async {
    if (_currentInstallationId == null || _currentUserId == null) return;

    debugPrint('[AggregationScheduler] ⏳ Triggering aggregation for hour ${time.hour}...');
    
    try {
      // On agrège l'heure qui vient de se passer (celle de 'time')
      await _histService.aggregateLastHour(
        userId: _currentUserId!,
        installationId: _currentInstallationId!,
        hourToAggregate: time,
      );
      debugPrint('[AggregationScheduler] ✅ Aggregation complete.');
    } catch (e) {
      debugPrint('[AggregationScheduler] ❌ Error during scheduled aggregation: $e');
    }
  }
}
