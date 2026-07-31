import 'package:flutter/material.dart';
import '../models/energy_data_model.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';

class EnergyHourDisplayWidget extends StatelessWidget {
  final String userId;
  final String installationId;
  final int annee;
  final int mois;
  final int jour;
  final String heure; // ex: "16h"

  const EnergyHourDisplayWidget({
    super.key,
    required this.userId,
    required this.installationId,
    required this.annee,
    required this.mois,
    required this.jour,
    required this.heure,
  });

  @override
  Widget build(BuildContext context) {
    final firebaseService = FirebaseService();

    return StreamBuilder<EnergyHourData>(
      stream: firebaseService.getHeureStream(
        userId: userId,
        installationId: installationId,
        annee: annee,
        mois: mois,
        jour: jour,
        heure: heure,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryYellow));
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)),
          );
        }

        final data = snapshot.data;
        if (data == null) {
          return const Center(child: Text("Document inexistant", style: TextStyle(color: AppTheme.textMuted)));
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Mesures de l\'heure',
                    style: TextStyle(color: AppTheme.primaryYellow, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    heure,
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Grid de mesures
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _buildMetricTile(
                    'Consommation AC',
                    FormatUtils.formatPower(data.consommationAC),
                    Icons.bolt,
                    AppTheme.primaryYellow,
                  ),
                  _buildMetricTile(
                    'Production AC',
                    FormatUtils.formatPower(data.productionAC),
                    Icons.wb_sunny_outlined,
                    Colors.orange,
                  ),
                  _buildMetricTile(
                    'Production DC',
                    data.productionDC != null ? FormatUtils.formatPower(data.productionDC!) : 'Non mesuré',
                    Icons.solar_power,
                    Colors.blueAccent,
                  ),
                  _buildMetricTile(
                    'Rendement',
                    data.rendement != null ? '${data.rendement!.toStringAsFixed(1)} %' : '--',
                    Icons.speed,
                    _getRendementColor(data.rendement),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Color _getRendementColor(double? rendement) {
    if (rendement == null) return AppTheme.textMuted;
    if (rendement >= 90) return Colors.greenAccent;
    if (rendement >= 70) return Colors.orangeAccent;
    return Colors.redAccent;
  }
}
