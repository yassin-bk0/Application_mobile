import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/measurement_scheduler.dart';
import '../theme/app_theme.dart';

class CountdownTimerWidget extends StatelessWidget {
  const CountdownTimerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final scheduler = context.watch<MeasurementScheduler>();
    final minutes = scheduler.remainingTime.inMinutes.toString().padLeft(2, '0');
    final seconds = (scheduler.remainingTime.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(45),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icone
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.timer_outlined, color: Color(0xFFFFD54F), size: 28),
          ),
          const SizedBox(width: 16),
          // Texte descriptif
          const Expanded(
            child: Text(
              'PROCHAINE\nMESURE DANS',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                height: 1.3,
              ),
            ),
          ),
          // Chiffres
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    minutes,
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, height: 1),
                  ),
                  const Text('MIN', style: TextStyle(color: AppTheme.textMuted, fontSize: 8, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    seconds,
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, height: 1),
                  ),
                  const Text('SEC', style: TextStyle(color: AppTheme.textMuted, fontSize: 8, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
