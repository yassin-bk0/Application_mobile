import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sensor_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/installation_provider.dart';
import '../widgets/live_production_dc_widget.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';

class PredictionScreen extends StatefulWidget {
  const PredictionScreen({super.key});

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Rafraîchir au premier rendu
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SensorProvider>(context, listen: false).refresh();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ── Helpers visuels ───────────────────────────────────────────────────────

  Widget _glassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.glassWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: child,
    );
  }

  Color _perfColor(String level) {
    if (level == 'Élevée') return AppTheme.primaryYellow;
    if (level == 'Moyenne') return Colors.orange;
    return Colors.blueAccent;
  }

  String _perfEmoji(String level) {
    if (level == 'Élevée') return '☀️';
    if (level == 'Moyenne') return '⛅';
    return '🌥️';
  }

  Color _getLuxColor(double lux) {
    if (lux >= 40000) return AppTheme.primaryYellow;
    if (lux >= 10000) return Colors.orange;
    return Colors.blueAccent;
  }

  // ── Jauge luminosité ──────────────────────────────────────────────────────

  Widget _buildLuxGauge(double lux) {
    // Normalise entre 0 et 100 000 lux
    final pct = (lux / 100000).clamp(0.0, 1.0);
    final color = _getLuxColor(lux);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.wb_sunny_rounded, color: color, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Luminosité',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
            Text(
              '${lux.toStringAsFixed(0)} lux',
              style: TextStyle(
                  color: color, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 10,
            backgroundColor: Colors.white.withOpacity(0.08),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('0 lux', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
            Text('100 000 lux', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
          ],
        ),
      ],
    );
  }

  // ── Thermomètre simplifié ─────────────────────────────────────────────────

  Widget _buildTempDisplay(double temp) {
    final color = temp > 50
        ? Colors.redAccent
        : temp > 35
            ? Colors.deepOrangeAccent
            : Colors.tealAccent;

    return Row(
      children: [
        Icon(Icons.thermostat_rounded, color: color, size: 36),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Température capteur',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              '${temp.toStringAsFixed(1)} °C',
              style: TextStyle(
                  color: color, fontSize: 32, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  // ── Indicateur statut capteur ─────────────────────────────────────────────

  Widget _buildStatusBadge(bool isOffline) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (_, __) => Opacity(
        opacity: isOffline ? 1.0 : _pulseAnimation.value,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: (isOffline ? Colors.redAccent : const Color(0xFF00FFC2))
                .withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: (isOffline ? Colors.redAccent : const Color(0xFF00FFC2))
                  .withOpacity(0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isOffline ? Colors.redAccent : const Color(0xFF00FFC2),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isOffline ? 'HORS LIGNE' : 'EN LIGNE',
                style: TextStyle(
                  color:
                      isOffline ? Colors.redAccent : const Color(0xFF00FFC2),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Alerte nuisance ───────────────────────────────────────────────────────

  Widget _buildNuisanceAlert(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orangeAccent.withOpacity(0.20),
            Colors.deepOrange.withOpacity(0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ALERTE NUISANCE',
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Informations de performance ───────────────────────────────────────────

  Widget _buildPerformanceBanner(SensorProvider sp) {
    final level = sp.getPerformanceLevel();
    final color = _perfColor(level);
    final emoji = _perfEmoji(level);
    final lux = sp.sensorData?.luminosite ?? 0;

    // Estimation puissance basée sur luminosité (approximation : 1 W/m² ≈ 120 lux pour ensoleillement standard)
    final irradEstimate = lux / 120.0;
    final estimatedPower = irradEstimate * 10 * 0.20; // 10 m² panneau, η=20%

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.25), AppTheme.bgCard],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 40)),
              _buildStatusBadge(sp.isOffline),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Performance estimée',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withOpacity(0.4)),
                    ),
                    child: Text(
                      'PRODUCTION $level'.toUpperCase(),
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: color),
                    ),
                  ),
                ],
              ),
              if (!sp.isOffline)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Puissance estimée',
                        style: TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(FormatUtils.formatPowerValue(estimatedPower),
                            style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: color)),
                        const SizedBox(width: 4),
                        const Text(' kW',
                            style: TextStyle(
                                fontSize: 16,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Règles de détection ───────────────────────────────────────────────────

  Widget _buildDetectionRules() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Règles de détection',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 16),
          _buildRuleRow(
            '☀️ Luminosité élevée + production faible',
            '⚠️ Nuisance probable (ombrage / saleté)',
            Colors.orangeAccent,
          ),
          const SizedBox(height: 10),
          _buildRuleRow(
            '🌥️ Luminosité faible + production faible',
            '✅ Normal (mauvaise météo)',
            Colors.tealAccent,
          ),
          const SizedBox(height: 10),
          _buildRuleRow(
            '☀️ Luminosité élevée + production normale',
            '✅ Système performant',
            AppTheme.primaryYellow,
          ),
        ],
      ),
    );
  }

  Widget _buildRuleRow(String condition, String result, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(condition,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(result,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDeep,
        title: const Text('Analyse des Capteurs'),
        actions: [
          Consumer<SensorProvider>(
            builder: (_, sp, __) => IconButton(
              icon: sp.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(color: AppTheme.primaryYellow, strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded,
                      color: AppTheme.primaryYellow),
              onPressed: sp.isLoading ? null : sp.refresh,
              tooltip: 'Actualiser',
            ),
          ),
        ],
      ),
      body: Consumer<SensorProvider>(
        builder: (context, sp, _) {
          // ── Erreur sans données ─────────────────────────────────────────
          if (sp.error != null && sp.sensorData == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sensors_off_rounded,
                      color: AppTheme.textMuted, size: 60),
                  const SizedBox(height: 16),
                  Text('Erreur : ${sp.error}',
                      style:
                          const TextStyle(color: AppTheme.textSecondary),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: sp.refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          final sd = sp.sensorData;
          final alert = sp.getNuisanceAlert();
          
          final auth = context.read<AuthProvider>();
          final installation = context.read<InstallationProvider>().installation;
          final userId = auth.user?.uid;
          final instId = installation?.id;

          return RefreshIndicator(
            color: AppTheme.primaryYellow,
            backgroundColor: AppTheme.bgCard,
            onRefresh: sp.refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: [
                // ── Bannière de performance ───────────────────────────
                _buildPerformanceBanner(sp),
                const SizedBox(height: 16),

                // ── Production DC en temps réel ───────────────────────
                if (userId != null && instId != null) ...[
                  LiveProductionDCWidget(
                    userId: userId,
                    installationId: instId,
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Alerte nuisance ───────────────────────────────────
                if (alert != null) ...[
                  _buildNuisanceAlert(alert),
                  const SizedBox(height: 16),
                ],

                // ── Carte luminosité ──────────────────────────────────
                _glassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Luminosité capteur',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 16),
                      if (sp.isOffline)
                        const Center(
                          child: Text('Capteur hors ligne',
                              style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold)),
                        )
                      else
                        _buildLuxGauge(sd?.luminosite ?? 0),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Carte température ─────────────────────────────────
                _glassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Température capteur',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 16),
                      if (sp.isOffline)
                        const Center(
                          child: Text('Capteur hors ligne',
                              style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold)),
                        )
                      else
                        _buildTempDisplay(sd?.temperature ?? 0),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Dernière mise à jour ──────────────────────────────
                if (sd != null && !sp.isOffline)
                  _glassCard(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            color: AppTheme.textMuted, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Dernière mise à jour : ${_formatTimestamp(sd.timestamp)}',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                if (sd != null && !sp.isOffline) const SizedBox(height: 16),

                // ── Règles de détection ───────────────────────────────
                _buildDetectionRules(),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatTimestamp(DateTime ts) {
    final d = ts.toLocal();
    String pad2(int n) => n.toString().padLeft(2, '0');
    return '${pad2(d.day)}/${pad2(d.month)}/${d.year} ${pad2(d.hour)}:${pad2(d.minute)}:${pad2(d.second)}';
  }
}
