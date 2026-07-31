import 'package:flutter/material.dart';
import '../models/realtime_measurement.dart';
import '../services/firestore_realtime_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';

class RealtimeDashboard extends StatelessWidget {
  final String userId;
  final String installationId;

  const RealtimeDashboard({super.key, required this.userId, required this.installationId});

  @override
  Widget build(BuildContext context) {
    final rs = FirestoreRealtimeService();

    return StreamBuilder<List<RealtimeMeasurement>>(
      stream: rs.getRealtimeStream(userId: userId, installationId: installationId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryYellow));
        }

        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }

        final measurements = snapshot.data ?? [];
        if (measurements.isEmpty) {
          return const Center(child: Text('Aucune donnée en temps réel', style: TextStyle(color: AppTheme.textMuted)));
        }

        final latest = measurements.first;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildLatestCard(latest),
              const SizedBox(height: 25),
              _buildHistoryList(measurements),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLatestCard(RealtimeMeasurement m) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('DERNIÈRE MESURE', style: TextStyle(color: AppTheme.primaryYellow, letterSpacing: 1.5, fontWeight: FontWeight.bold, fontSize: 13)),
              Text(m.id.split('_').last, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 25),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.4,
            mainAxisSpacing: 15,
            crossAxisSpacing: 15,
            children: [
              _buildMetric('Consommation AC', FormatUtils.formatPower(m.consommationAC), Icons.bolt, AppTheme.primaryYellow),
              _buildMetric('Production AC', FormatUtils.formatPower(m.productionAC), Icons.wb_sunny_outlined, Colors.orange),
              _buildMetric('Production DC', FormatUtils.formatPower(m.productionDC), Icons.solar_power, Colors.blueAccent),
              _buildMetric('Rendement', '${m.rendement.toStringAsFixed(1)} %', Icons.speed, _getRendementColor(m.rendement)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildHistoryList(List<RealtimeMeasurement> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Dernières 10 mesures', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: list.length > 10 ? 10 : list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final m = list[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.bgCard.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Text(m.id.split('_').last, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  const Spacer(),
                  _buildMiniMetric(m.productionAC, Colors.orange),
                  const SizedBox(width: 15),
                  _buildMiniMetric(m.consommationAC, AppTheme.primaryYellow),
                  const SizedBox(width: 15),
                  Text('${m.rendement.toStringAsFixed(0)}%', style: TextStyle(color: _getRendementColor(m.rendement), fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMiniMetric(double val, Color color) {
    return Row(
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(FormatUtils.formatPower(val), style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  Color _getRendementColor(double val) {
    if (val >= 90) return Colors.greenAccent;
    if (val >= 70) return Colors.orangeAccent;
    return Colors.redAccent;
  }
}
