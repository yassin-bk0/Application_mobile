import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pv_monitor/firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/auth_gate.dart';
import 'providers/data_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/sensor_provider.dart';
import 'providers/installation_provider.dart';

import 'services/background_logic.dart';
import 'services/measurement_scheduler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Activation de la persistance offline Firestore
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  
  // Initialisation du service d'arrière-plan (Workmanager)
  await BackgroundService.init();

  // Initialisation des données locales (pour DateFormat en français)
  await initializeDateFormatting('fr', null);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MeasurementScheduler()),
        ChangeNotifierProxyProvider<MeasurementScheduler, DataProvider>(
          create: (_) => DataProvider(),
          update: (_, scheduler, dataProvider) {
            dataProvider!.setScheduler(scheduler);
            return dataProvider;
          },
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),

        // InstallationProvider: linked to AuthProvider — loads installation on login
        ChangeNotifierProxyProvider<AuthProvider, InstallationProvider>(
          create: (_) => InstallationProvider(),
          update: (_, auth, installation) {
            installation!.updateUser(auth.user);
            return installation;
          },
        ),

        // SensorProvider: linked to AuthProvider AND InstallationProvider
        // Reads ESP32 sensor data (luminosity + temperature) from Firebase.
        ChangeNotifierProxyProvider2<AuthProvider, InstallationProvider, SensorProvider>(
          create: (_) => SensorProvider(),
          update: (_, auth, installation, sensor) {
            sensor!.updateUser(auth.user, installation.installation);
            return sensor;
          },
        ),
      ],
      child: const PvMonitorApp(),
    ),
  );
}

class PvMonitorApp extends StatelessWidget {
  const PvMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'PV Monitor',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          debugShowCheckedModeBanner: false,
          navigatorObservers: [
            FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
          ],
          // AuthGate handles Login → PVSetup → Dashboard routing automatically
          home: const AuthGate(),
        );
      },
    );
  }
}
