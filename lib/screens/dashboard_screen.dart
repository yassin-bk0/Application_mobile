import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/installation_provider.dart';
import '../providers/sensor_provider.dart';
import '../services/measurement_scheduler.dart';
import '../services/firestore_measurement_service.dart';
import '../theme/app_theme.dart';
import '../models/measurement_models.dart';
import '../widgets/last_measurement_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  final FirestoreMeasurementService _firestoreService = FirestoreMeasurementService();
  RealtimeMeasurement? _lastMeasurement;
  Stream<RealtimeMeasurement?>? _measurementStream;
  String? _currentInstId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDashboardData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[DashboardScreen] 🔄 Application revenue au premier plan. Reconnexion du stream...');
      _loadDashboardData();
    }
  }

  Future<void> _loadDashboardData() async {
    final auth = context.read<AuthProvider>();
    final installation = context.read<InstallationProvider>().installation;
    
    debugPrint('[DashboardScreen] 🔄 Chargement initial des données...');
    
    if (auth.user != null && installation?.id != null) {
      final userId = auth.user!.uid;
      final instId = installation!.id!;
      _currentInstId = instId;

      try {
        // Initialiser le Stream
        _measurementStream = _firestoreService.getLastMeasurementStream(userId, instId);
        
        final last = await _firestoreService.getLastMeasurement(userId, instId);
        
        if (mounted) {
          setState(() {
            _lastMeasurement = last;
          });
        }
      } catch (e) {
        debugPrint('[DashboardScreen] ❌ Erreur chargement données: $e');
      } finally {
        if (mounted) {
           setState(() {});
        }
      }
    } else {
      debugPrint('[DashboardScreen] ⚠️ IDs manquants au démarrage.');
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final installationProvider = context.watch<InstallationProvider>();
    final installation = installationProvider.installation;

    // RE-SYNCHRONISATION GÉRÉE : Si l'ID change ou devient disponible après le initState
    if (auth.user != null && installation?.id != null && installation!.id != _currentInstId) {
      _currentInstId = installation.id;
      final uid = auth.user!.uid;
      debugPrint('[DashboardScreen] 🔍 Tentative de flux pour UID: $uid / Inst: $_currentInstId');
      _measurementStream = _firestoreService.getLastMeasurementStream(uid, _currentInstId!);
    }

    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      body: SafeArea(
        child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            children: [
              _buildHeader(),
              const SizedBox(height: 10),
              
              // 0. CAPTEURS ESP32 (TOP)
              _buildSensorSection(),
              const SizedBox(height: 24),
              
              // TITRES PRINCIPAUX
              const Text(
                '☀️ DASHBOARD PRINCIPAL',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              const SizedBox(height: 8),
              Text(
                installation?.name ?? 'Mon Installation',
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),

              // 2. DERNIÈRE MESURE
              StreamBuilder<RealtimeMeasurement?>(
                stream: _measurementStream ?? const Stream.empty(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    debugPrint('[DashboardScreen] ❌ Erreur Stream Firestore: ${snapshot.error}');
                    return Center(child: Text("Erreur flux: ${snapshot.error}", style: const TextStyle(color: Colors.red, fontSize: 10)));
                  }

                  final measurement = snapshot.data ?? _lastMeasurement;
                  
                  if (snapshot.connectionState == ConnectionState.waiting && measurement == null) {
                    return const Center(child: CircularProgressIndicator(color: AppTheme.primaryYellow));
                  }
                  
                  final sensorProvider = context.read<SensorProvider>();
                  
                  // Synchronise la production avec SensorProvider pour la détection de nuisances
                  if (measurement != null) {
                    sensorProvider.updateProduction(measurement.productionAC);
                  }

                  return Column(
                    children: [
                      // Alerte nuisance si détectée
                      if (sensorProvider.getNuisanceAlert() != null)
                        _buildNuisanceAlert(sensorProvider.getNuisanceAlert()!),
                      if (sensorProvider.getNuisanceAlert() != null)
                        const SizedBox(height: 16),
                      LastMeasurementCard(
                        measurement: measurement,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 30),


              // 4. IMPACT ÉCONOMIQUE & ENVIRONNEMENTAL
              _buildImpactSection(),
              
              const SizedBox(height: 40),
            ],
          ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryYellow.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.solar_power_rounded, color: AppTheme.primaryYellow, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'PV MONITOR',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF003D2E).withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF00FFC2).withOpacity(0.3)),
            boxShadow: [
              BoxShadow(color: const Color(0xFF00FFC2).withOpacity(0.1), blurRadius: 10, spreadRadius: 1),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(color: Color(0xFF00FFC2), shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              const Text(
                'CONNECTED',
                style: TextStyle(color: Color(0xFF00FFC2), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImpactSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.query_stats_rounded, color: AppTheme.primaryYellow.withOpacity(0.7), size: 18),
            const SizedBox(width: 10),
            const Text(
              'IMPACT ÉCONOMIQUE & ENVIRONNEMENTAL',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Carte Économies
        _buildImpactCard(
          label: 'ÉCONOMIES RÉALISÉES',
          value: '142.500',
          unit: 'TND',
          subtext: 'ce mois-ci',
          icon: Icons.account_balance_wallet_rounded,
          color: Colors.blueGrey,
        ),
        const SizedBox(height: 12),
        
        // Carte Planète
        _buildImpactCard(
          label: 'IMPACT PLANÈTE',
          value: '12.4',
          unit: 'kg CO₂',
          subtext: 'Équivalent à 2 arbres plantés 🌲',
          icon: Icons.eco_rounded,
          color: const Color(0xFF004D40),
        ),
      ],
    );
  }

  Widget _buildImpactCard({
    required String label,
    required String value,
    required String unit,
    required String subtext,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white70, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(value, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(unit, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(subtext, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── SECTION CAPTEURS ────────────────────────────────────────────────────

  Widget _buildSensorSection() {
    return Consumer<SensorProvider>(
      builder: (context, sp, _) {
        final sd = sp.sensorData;
        final now = DateTime.now();
        final dateStr = '${now.day.toString().padLeft(2,'0')}/${now.month.toString().padLeft(2,'0')}/${now.year}';
        final timeStr = '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.sensors_rounded, color: AppTheme.primaryYellow.withOpacity(0.7), size: 18),
                    const SizedBox(width: 10),
                    const Text(
                      'CAPTEURS EN TEMPS RÉEL',
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ],
                ),
                Text(
                  '$dateStr • $timeStr',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  _buildSensorRow(
                    Icons.wb_sunny_rounded,
                    'Luminosité',
                    (sp.isOffline || sd == null) ? '45000 lux' : '${sd.luminosite.toStringAsFixed(0)} lux',
                    _getLuxColor((sp.isOffline || sd == null) ? 45000 : sd.luminosite),
                  ),
                  _buildSensorRow(
                    Icons.thermostat_outlined,
                    'Température',
                    (sp.isOffline || sd == null) ? '24.5 °C' : '${sd.temperature.toStringAsFixed(1)} °C',
                    Colors.deepOrangeAccent,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    decoration: BoxDecoration(
                      color: _perfColor((sp.isOffline || sd == null) ? 'Élevée' : sp.getPerformanceLevel()).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _perfColor((sp.isOffline || sd == null) ? 'Élevée' : sp.getPerformanceLevel()).withOpacity(0.3)),
                    ),
                    child: Text(
                      _perfLabel((sp.isOffline || sd == null) ? 'Élevée' : sp.getPerformanceLevel()),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _perfColor((sp.isOffline || sd == null) ? 'Élevée' : sp.getPerformanceLevel()),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }



  Widget _buildSensorRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 14),
          Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildNuisanceAlert(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.5)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Colors.orangeAccent,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Color _getLuxColor(double lux) {
    if (lux >= 40000) return AppTheme.primaryYellow;
    if (lux >= 10000) return Colors.orange;
    return Colors.blueAccent;
  }

  String _perfLabel(String level) {
    if (level == 'Élevée') return '☀️ Production élevée attendue';
    if (level == 'Moyenne') return '⛅ Production modérée';
    if (level == 'Faible') return '🌥️ Luminosité insuffisante';
    return '📡 Données indisponibles';
  }

  Color _perfColor(String level) {
    if (level == 'Élevée') return AppTheme.primaryYellow;
    if (level == 'Moyenne') return Colors.orange;
    return Colors.blueAccent;
  }
}
