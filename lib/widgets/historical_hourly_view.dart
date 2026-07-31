import 'package:flutter/material.dart';
import '../models/measurement_models.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';

class HistoricalHourlyView extends StatelessWidget {
  final List<HourlyAggregation> aggregations;

  const HistoricalHourlyView({super.key, required this.aggregations});

  @override
  Widget build(BuildContext context) {
    if (aggregations.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text("Aucune donnée horaire disponible", style: TextStyle(color: AppTheme.textMuted)),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: aggregations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final agg = aggregations[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: AppTheme.primaryYellow.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    "${agg.heure}h",
                    style: const TextStyle(color: AppTheme.primaryYellow, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSimpleStat('AC', FormatUtils.formatPower(agg.productionAC_moyenne), AppTheme.primaryYellow),
                        _buildSimpleStat('DC', FormatUtils.formatPower(agg.productionDC_moyenne), Colors.amber),
                        _buildSimpleStat('Cons', FormatUtils.formatPower(agg.consommationAC_moyenne), Colors.orange),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("${agg.nbMesures} mesure(s)", style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                        Text("Rendement: ${agg.rendement_moyen.toStringAsFixed(1)}%", style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSimpleStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
        Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
