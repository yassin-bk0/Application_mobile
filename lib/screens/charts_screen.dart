import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/auth_provider.dart';
import '../providers/installation_provider.dart';
import '../services/firestore_measurement_service.dart';
import '../models/measurement_models.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';

class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  // 0 = 1H, 1 = 6H, 2 = 24H
  int _selectedTime = 1;
  final FirestoreMeasurementService _firestoreService = FirestoreMeasurementService();

  Stream<List<RealtimeMeasurement>>? _chartStream;
  String? _currentUserId;
  String? _currentInstId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildStream());
  }

  /// Recrée le stream Firestore à chaque changement d'onglet.
  void _rebuildStream() {
    final auth = context.read<AuthProvider>();
    final installation = context.read<InstallationProvider>().installation;

    if (auth.user == null || installation?.id == null) return;

    final userId = auth.user!.uid;
    final instId = installation!.id!;

    _currentUserId = userId;
    _currentInstId = instId;

    setState(() {
      _chartStream = _firestoreService.getChartStream(
        userId: userId,
        installationId: instId,
        window: _getDuration(),
      );
    });

    debugPrint('[ChartsScreen] 🔄 Stream recréé — onglet: ${_getTabLabel()} | fenêtre: ${_getDuration().inHours}h');
  }

  Duration _getDuration() {
    if (_selectedTime == 0) return const Duration(hours: 1);
    if (_selectedTime == 1) return const Duration(hours: 6);
    return const Duration(hours: 24);
  }

  String _getTabLabel() {
    if (_selectedTime == 0) return '1H';
    if (_selectedTime == 1) return '6H';
    return '24H';
  }

  // ── BUILDERS ──────────────────────────────────────────────────────────────

  Widget _buildSegment(String text, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryYellow : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? AppTheme.bgDeep : AppTheme.textMuted,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          _buildSegment('1H',  _selectedTime == 0, () {
            setState(() => _selectedTime = 0);
            _rebuildStream();
          }),
          _buildSegment('6H',  _selectedTime == 1, () {
            setState(() => _selectedTime = 1);
            _rebuildStream();
          }),
          _buildSegment('24H', _selectedTime == 2, () {
            setState(() => _selectedTime = 2);
            _rebuildStream();
          }),
        ],
      ),
    );
  }

  Widget _buildStatBox(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(title.toUpperCase(),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color, letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color c) =>
      Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle));

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Si les IDs changent (ex: reconnexion), on recrée le stream
    final auth = context.watch<AuthProvider>();
    final installation = context.watch<InstallationProvider>().installation;

    if (auth.user?.uid != _currentUserId || installation?.id != _currentInstId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildStream());
    }

    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDeep,
        elevation: 0,
        title: const Text('Bilan de Puissance', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: (auth.user == null || installation?.id == null)
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryYellow))
          : StreamBuilder<List<RealtimeMeasurement>>(
              stream: _chartStream ?? const Stream.empty(),
              builder: (context, snapshot) {
                // État de chargement initial (avant le premier event)
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return Column(
                    children: [
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildTimeSelector(),
                      ),
                      const Expanded(
                        child: Center(child: CircularProgressIndicator(color: AppTheme.primaryYellow)),
                      ),
                    ],
                  );
                }

                if (snapshot.hasError) {
                  return Column(
                    children: [
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildTimeSelector(),
                      ),
                      Expanded(
                        child: Center(
                          child: Text('Erreur : ${snapshot.error}',
                              style: const TextStyle(color: AppTheme.accentRed, fontSize: 12)),
                        ),
                      ),
                    ],
                  );
                }

                final history = snapshot.data ?? [];
                final duration = _getDuration();
                final now = DateTime.now();
                final cutoffTime = now.subtract(duration);

                // ── Cas : aucune donnée ──────────────────────────────────────
                if (history.isEmpty) {
                  return Column(
                    children: [
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildTimeSelector(),
                      ),
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bar_chart_outlined, color: AppTheme.textMuted.withOpacity(0.4), size: 64),
                              const SizedBox(height: 16),
                              Text(
                                'Aucune donnée pour les ${_getTabLabel()}',
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Les données apparaîtront dès que\nle système enregistrera des mesures.',
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }

                // ── Construire les spots fl_chart ────────────────────────────
                final List<FlSpot> spotsProduction  = [];
                final List<FlSpot> spotsConsumption = [];
                final double totalSeconds = duration.inSeconds.toDouble();

                // ── SÉPARATION : point live vs. agrégations horaires ──────────
                // PROBLÈME CORRIGÉ : Le point `current_data` est une valeur instantanée
                // (ex: 22h51 = pic de consommation soir). Si on l'inclut dans la moyenne
                // il pèse 1/7 en 6H mais seulement 1/25 en 24H → incohérence entre onglets.
                //
                // SOLUTION : 
                //   - Cartes stats (PROD. AC / CONS. AC / BILAN NET) = moyenne des points
                //     HORAIRES uniquement (id != 'current_data'), filtrés sur la fenêtre exacte.
                //   - "BILAN ACTUEL" en haut = valeur instantanée de current_data.
                //   - Les deux calculs sont indépendants et cohérents.

                // Point live (valeur instantanée)
                RealtimeMeasurement? livePoint;

                // Somme pour les cartes (agrégations horaires uniquement)
                double sumProd = 0;
                double sumCons = 0;
                int validCount = 0;

                for (final m in history) {
                  final double rawX = m.timestamp.difference(cutoffTime).inSeconds.toDouble();
                  if (rawX > totalSeconds + 3600) continue; // point futur → ignorer

                  // ── Point live : traiter séparément ──
                  if (m.id == 'current_data') {
                    livePoint = m;
                    // Toujours placé au bord droit du graphique
                    if (spotsProduction.isNotEmpty && spotsProduction.last.x == totalSeconds) {
                      spotsProduction.removeLast();
                      spotsConsumption.removeLast();
                    }
                    spotsProduction.add(FlSpot(totalSeconds, m.productionAC / 1000.0));
                    spotsConsumption.add(FlSpot(totalSeconds, m.consommationAC / 1000.0));
                    continue; // NE PAS inclure dans la moyenne des cartes
                  }

                  // ── Agrégations horaires : inclure dans la moyenne ──
                  // La moyenne est calculée uniquement sur les points STRICTEMENT
                  // dans la fenêtre sélectionnée (rawX >= 0).
                  if (rawX >= 0) {
                    sumProd += m.productionAC;
                    sumCons += m.consommationAC;
                    validCount++;
                  }

                  // Clamp graphique : point avant la fenêtre → bord gauche (x=0)
                  final double x = rawX.clamp(0.0, totalSeconds);

                  if (spotsProduction.isNotEmpty && spotsProduction.last.x == x) {
                    spotsProduction.removeLast();
                    spotsConsumption.removeLast();
                  }
                  spotsProduction.add(FlSpot(x, m.productionAC / 1000.0));
                  spotsConsumption.add(FlSpot(x, m.consommationAC / 1000.0));
                }

                // Fallback : si un seul spot, dupliquer à droite pour que fl_chart puisse tracer
                if (spotsProduction.length == 1) {
                  spotsProduction.add(FlSpot(totalSeconds, spotsProduction.first.y));
                  spotsConsumption.add(FlSpot(totalSeconds, spotsConsumption.first.y));
                }

                // ── Énergie totale sur la période (somme, sans current_data) ──
                // Chaque point horaire stocke une puissance moyenne (W) sur 1 heure.
                // puissance_moyenne(W) × 1h = Wh d'énergie pour cette heure.
                // Somme de N points = énergie totale en Wh sur la fenêtre.
                //
                // Garantie de cohérence :
                //   énergie 24H  ≥  énergie 6H  ≥  énergie 1H  (toujours, car somme croissante)
                //
                // Fallback sur le point live × (durée fenêtre en h) si aucun point horaire.
                final double totalProdWh = validCount > 0
                    ? sumProd          // sumProd déjà en W×h = Wh (1 point = 1 heure)
                    : (livePoint?.productionAC ?? 0.0) * (duration.inHours);
                final double totalConsWh = validCount > 0
                    ? sumCons
                    : (livePoint?.consommationAC ?? 0.0) * (duration.inHours);
                final double totalBilanWh = totalProdWh - totalConsWh;

                // ── Bilan instantané pour "BILAN ACTUEL" (toujours en kW) ──
                final double currentBilan = livePoint != null
                    ? livePoint.productionAC - livePoint.consommationAC
                    : totalBilanWh / (duration.inHours > 0 ? duration.inHours : 1);

                // Y max pour le graphique
                final allY = [...spotsProduction, ...spotsConsumption].map((s) => s.y);
                final double maxY = allY.isEmpty ? 1.0 : (allY.reduce((a, b) => a > b ? a : b) * 1.2).ceilToDouble();
                final double hInterval = (maxY / 4).clamp(0.1, double.infinity);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                  children: [
                    _buildTimeSelector(),
                    const SizedBox(height: 20),

                    // ── Graphique ────────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // En-tête
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('PROD. VS CONS. (kW)',
                                  style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              Row(children: [
                                _dot(AppTheme.primaryYellow), const SizedBox(width: 4),
                                const Text('PROD.', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                                const SizedBox(width: 12),
                                _dot(AppTheme.accentRed), const SizedBox(width: 4),
                                const Text('CONS.', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                              ]),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Bilan actuel (valeur instantanée = current_data)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('BILAN ACTUEL',
                                  style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                              Text(
                                FormatUtils.formatPower(currentBilan),
                                style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: currentBilan >= 0 ? AppTheme.accentGreen : AppTheme.accentRed),
                              ),
                              Text(
                                '${validCount} point${validCount > 1 ? 's' : ''} sur ${_getTabLabel()} · moy. ${_getTabLabel()}',
                                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // LineChart
                          SizedBox(
                            height: 220,
                            child: spotsProduction.length < 2
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _dot(AppTheme.primaryYellow),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Un seul point disponible\n(graphique dispo à partir de 2 mesures)',
                                          style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  )
                                : LineChart(
                                    LineChartData(
                                      minX: 0,
                                      maxX: totalSeconds,
                                      minY: 0,
                                      maxY: maxY,
                                      lineBarsData: [
                                        LineChartBarData(
                                          spots: spotsProduction,
                                          isCurved: true,
                                          color: AppTheme.primaryYellow,
                                          barWidth: 3,
                                          isStrokeCapRound: true,
                                          dotData: FlDotData(
                                            show: history.length <= 12,
                                            getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                                              radius: 4,
                                              color: AppTheme.primaryYellow,
                                              strokeColor: AppTheme.bgCard,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                          belowBarData: BarAreaData(
                                            show: true,
                                            gradient: LinearGradient(
                                              colors: [AppTheme.primaryYellow.withOpacity(0.2), AppTheme.primaryYellow.withOpacity(0)],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                            ),
                                          ),
                                        ),
                                        LineChartBarData(
                                          spots: spotsConsumption,
                                          isCurved: true,
                                          color: AppTheme.accentRed,
                                          barWidth: 3,
                                          isStrokeCapRound: true,
                                          dotData: FlDotData(
                                            show: history.length <= 12,
                                            getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                                              radius: 4,
                                              color: AppTheme.accentRed,
                                              strokeColor: AppTheme.bgCard,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                          belowBarData: BarAreaData(
                                            show: true,
                                            gradient: LinearGradient(
                                              colors: [AppTheme.accentRed.withOpacity(0.2), AppTheme.accentRed.withOpacity(0)],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                            ),
                                          ),
                                        ),
                                      ],
                                      titlesData: const FlTitlesData(show: false),
                                      gridData: FlGridData(
                                        show: true,
                                        drawHorizontalLine: true,
                                        horizontalInterval: hInterval,
                                        getDrawingHorizontalLine: (_) => FlLine(
                                          color: Colors.white.withOpacity(0.05),
                                          strokeWidth: 1,
                                        ),
                                      ),
                                      borderData: FlBorderData(show: false),
                                      lineTouchData: LineTouchData(
                                        touchTooltipData: LineTouchTooltipData(
                                          getTooltipItems: (spots) => spots.map((s) {
                                            final isProd = s.barIndex == 0;
                                            return LineTooltipItem(
                                              '${s.y.toStringAsFixed(2)} kW',
                                              TextStyle(
                                                color: isProd ? AppTheme.primaryYellow : AppTheme.accentRed,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ),
                          ),

                          // Labels horaires
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(4, (i) {
                              final secondsOffset = (totalSeconds * i / 3).round();
                              final time = cutoffTime.add(Duration(seconds: secondsOffset));
                              final timeStr =
                                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                              return Text(timeStr,
                                  style: const TextStyle(fontSize: 9, color: AppTheme.textMuted));
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Cartes stats (énergie totale sur la période) ──────────
                    // Chaque valeur = somme des énergies horaires en kWh.
                    // Garantie : 24H ≥ 6H ≥ 1H (la somme croît avec la fenêtre).
                    Row(
                      children: [
                        _buildStatBox(
                          'PROD. ${_getTabLabel()}',
                          FormatUtils.formatEnergy(totalProdWh),
                          AppTheme.primaryYellow,
                        ),
                        const SizedBox(width: 12),
                        _buildStatBox(
                          'CONS. ${_getTabLabel()}',
                          FormatUtils.formatEnergy(totalConsWh),
                          AppTheme.accentRed,
                        ),
                        const SizedBox(width: 12),
                        _buildStatBox(
                          'BILAN NET',
                          FormatUtils.formatEnergyWithSign(totalBilanWh),
                          totalBilanWh >= 0 ? AppTheme.accentGreen : AppTheme.accentRed,
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
    );
  }
}
