import 'package:flutter/material.dart';
import '../models/measurement_models.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';

class LastMeasurementCard extends StatelessWidget {
  final RealtimeMeasurement? measurement;

  const LastMeasurementCard({
    super.key,
    required this.measurement,
  });

  @override
  Widget build(BuildContext context) {
    if (measurement == null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(child: Text("Aucune mesure disponible", style: TextStyle(color: Colors.white54))),
      );
    }

    // Affichage en heure locale de l'appareil
    final localTime = measurement!.timestamp.toLocal();
    final dateStr = DateFormat('dd/MM HH:mm').format(localTime);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('RÉCAPITULATIF SYSTÈME', 
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 6),
          Text('Dernière mesure: $dateStr', 
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          
          // MÉTRIQUES VERTICALES
          _buildMetricRow(
            label: 'CONS. AC',
            value: measurement!.consommationAC.toStringAsFixed(1),
            unit: 'Watts',
            icon: Icons.bolt_rounded,
            color: Colors.orangeAccent,
          ),
          const SizedBox(height: 16),
          _buildMetricRow(
            label: 'PROD. AC',
            value: measurement!.productionAC.toStringAsFixed(1),
            unit: 'Watts',
            icon: Icons.wb_sunny_rounded,
            color: AppTheme.primaryYellow,
          ),
          const SizedBox(height: 16),
          _buildMetricRow(
            label: 'PROD. DC',
            value: measurement!.productionDC.toStringAsFixed(1),
            unit: 'Watts',
            icon: Icons.solar_power_rounded,
            color: Colors.blueAccent,
          ),
          const SizedBox(height: 16),
          _buildMetricRow(
            label: 'RENDEMENT ONDULEUR',
            value: measurement!.rendement.toStringAsFixed(1),
            unit: 'Efficacité',
            icon: Icons.percent_rounded,
            color: const Color(0xFF00E676),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow({
    required String label,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.01)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(value, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    Text(unit, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
