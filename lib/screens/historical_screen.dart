import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/hourly_aggregation.dart';
import '../services/firestore_historical_service.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils_helper.dart';
import '../utils/format_utils.dart';

class HistoricalScreen extends StatefulWidget {
  final String userId;
  final String installationId;

  const HistoricalScreen({super.key, required this.userId, required this.installationId});

  @override
  State<HistoricalScreen> createState() => _HistoricalScreenState();
}

class _HistoricalScreenState extends State<HistoricalScreen> {
  final _histService = FirestoreHistoricalService();
  
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      appBar: AppBar(
        title: const Text('HISTORIQUE AGREGÉ', style: TextStyle(color: AppTheme.primaryYellow, fontWeight: FontWeight.bold, letterSpacing: 1)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildDatePicker(),
          const SizedBox(height: 20),
          Expanded(child: _buildHourlyList()),
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Date sélectionnée :', style: TextStyle(color: AppTheme.textMuted)),
          TextButton.icon(
            icon: const Icon(Icons.calendar_month, color: AppTheme.primaryYellow),
            label: Text(
              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _histService.getHoursStream(
        userId: widget.userId,
        installationId: widget.installationId,
        year: _selectedDate.year,
        month: _selectedDate.month,
        day: _selectedDate.day,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryYellow));
        }

        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'Aucune agrégation pour ce jour',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final agg = HourlyAggregation.fromMap(doc.data());
            final hourLabel = doc.id;

            return _buildHourlyCard(hourLabel, agg);
          },
        );
      },
    );
  }

  Widget _buildHourlyCard(String label, HourlyAggregation agg) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: AppTheme.primaryYellow, fontWeight: FontWeight.bold, fontSize: 16)),
              _buildRendementBadge(agg.rendement_moyen),
            ],
          ),
          const Divider(height: 30, color: Colors.white10),
          Row(
            children: [
              _buildAggMetric('Cons. AC', FormatUtils.formatEnergy(agg.consommationAC_total), AppTheme.primaryYellow),
              _buildAggMetric('Prod. AC', FormatUtils.formatEnergy(agg.productionAC_total), Colors.orange),
              _buildAggMetric('Prod. DC', FormatUtils.formatEnergy(agg.productionDC_total), Colors.blueAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAggMetric(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRendementBadge(double val) {
    Color color = Colors.greenAccent;
    if (val < 70) color = Colors.orangeAccent;
    if (val < 50) color = Colors.redAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        'Rendement: ${val.toStringAsFixed(1)}%',
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
