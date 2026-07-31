import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/installation_provider.dart';
import 'login_screen.dart';
import 'main_screen.dart';
import 'pv_setup_screen.dart';

/// Smart router that bridges Authentication ↔ Installation state.
///
/// Flow:
///   not logged in  → LoginScreen
///   loading        → Splash (loading indicator)
///   logged in, no installation → PVSetupScreen
///   logged in, has installation → MainScreen
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth         = context.watch<AuthProvider>();
    final installation = context.watch<InstallationProvider>();

    // ── Not authenticated ────────────────────────────────────────────────────
    if (!auth.isLoading && auth.user == null) {
      return const LoginScreen();
    }

    // ── Auth still loading or installation still checking ────────────────────
    if (auth.isLoading || (auth.user != null && !installation.checked)) {
      return const _SplashScreen();
    }

    // ── Authenticated but no installation → force setup ──────────────────────
    if (!installation.hasInstallation) {
      return PVSetupScreen(userId: auth.user!.uid);
    }

    // ── All good → Dashboard ─────────────────────────────────────────────────
    return const MainScreen();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF5C842).withOpacity(0.15),
                border: Border.all(color: const Color(0xFFF5C842).withOpacity(0.5), width: 2),
              ),
              child: const Icon(Icons.wb_sunny_rounded, color: Color(0xFFF5C842), size: 42),
            ),
            const SizedBox(height: 24),
            const Text('PV MONITOR', style: TextStyle(color: Color(0xFFF5C842), fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 4)),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: Color(0xFFF5C842), strokeWidth: 2),
          ],
        ),
      ),
    );
  }
}
