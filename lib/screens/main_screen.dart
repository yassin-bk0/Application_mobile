import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../providers/installation_provider.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'charts_screen.dart';
import 'historique_screen.dart';
import 'settings_screen.dart';
import '../services/aggregation_scheduler.dart';
import '../services/background_logic.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [];

  void _initScreens({required String userId, required String installationId}) {
    if (_screens.isNotEmpty) return;
    _screens.addAll([
      const DashboardScreen(),
      const ChartsScreen(),
      const HistoriqueScreen(),
      const SettingsScreen(),
    ]);
  }

  @override
  void initState() {
    super.initState();
    _connectData();
  }

  void _connectData() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProvider = context.read<AuthProvider>();
      final uid = authProvider.user?.uid;

      final installationProvider = context.read<InstallationProvider>();
      final installation = installationProvider.installation;
      
      if (uid != null && installation != null) {
        if (_screens.isEmpty) {
          setState(() {
            _initScreens(userId: uid, installationId: installation.id!);
          });
        }

        final dataProvider = context.read<DataProvider>();
        if (dataProvider.isConnected) return; // Déjà connecté

        print('[MainScreen] Démarrage DataProvider avec UID: $uid et Installation: ${installation.id}');
        
        // Stocker les IDs pour le background service
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', uid);
        await prefs.setString('installationId', installation.id!);

        // Planifier la tâche Workmanager (1 minute / 15 min natif)
        await BackgroundService.scheduleMeasurement();

        // DÉMARRAGE DU SCHEDULER D'AGRÉGATION AVEC USERID
        AggregationScheduler().start(userId: uid, installationId: installation.id!);

        // ⚠️ SUPPRIMÉ : triggerManualMeasurement() au démarrage.
        // Cet appel écrasait current_data avec des données en mémoire nulles/mock
        // AVANT que le RTDB ait eu le temps de répondre.
        // Le MeasurementScheduler déclenchera automatiquement la mesure
        // à la prochaine tranche de 15 minutes, avec de vraies données RTDB.

        dataProvider.connectAndStart(
          userId: uid,
          installationId: installation.id,
        );

      } else {
        print('[MainScreen] UID ou Installation non trouvés au démarrage. En attente...');
        Future.delayed(const Duration(seconds: 1), _connectData);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_screens.isEmpty) {
      return const Scaffold(
        backgroundColor: AppTheme.bgDeep,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryYellow)),
      );
    }

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          border: Border(
            top: BorderSide(color: AppTheme.primaryYellow.withOpacity(0.2), width: 1),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, -5)),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          backgroundColor: Colors.transparent,
          elevation: 0,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard_rounded), label: 'Tableau'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart_rounded), label: 'Graphiques'),
            BottomNavigationBarItem(icon: Icon(Icons.history_outlined), activeIcon: Icon(Icons.history_rounded), label: 'Historique'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings_rounded), label: 'Réglages'),
          ],
        ),
      ),
    );
  }
}
