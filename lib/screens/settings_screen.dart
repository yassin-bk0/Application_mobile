import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import 'auth_gate.dart';
import 'pv_setup_screen.dart';
import 'edit_profile_screen.dart';
import '../providers/installation_provider.dart';
import '../providers/data_provider.dart';
import '../services/seed_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Optionnel: charger des données météo si besoin, 
        // mais les controllers lat/lng sont supprimés.
      }
    });
  }




  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _sectionLabel(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryYellow, letterSpacing: 0.5)),
  );

  Widget _glassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.glassWhite : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppTheme.glassBorder : Colors.black.withOpacity(0.05)),
        boxShadow: isDark ? null : [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }

  Widget _glassTextField({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    TextInputType? keyboard,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.08)),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        obscureText: obscureText,
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.5)),
          prefixIcon: Icon(icon, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4), size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _instRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.textMuted),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Réglages'),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final displayName = authProvider.username;
          final displayEmail = authProvider.user?.email ?? '';
          final displayPhone = authProvider.phone;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              // ── Profil Utilisateur ──────────────────────────────────────────────
              _sectionLabel('PROFIL UTILISATEUR'),
              _glassCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(colors: [Color(0xFFF5C842), Color(0xFFFFB300)]),
                            image: authProvider.localPhotoPath != null && File(authProvider.localPhotoPath!).existsSync()
                                ? DecorationImage(
                                    image: FileImage(File(authProvider.localPhotoPath!)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: authProvider.localPhotoPath != null && File(authProvider.localPhotoPath!).existsSync()
                              ? null // L'image cache le texte
                              : Center(
                                  child: Text(
                                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(displayName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.titleLarge?.color)),
                              const SizedBox(height: 4),
                              Text(displayEmail, style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color)),
                              if (displayPhone.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(displayPhone, style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color)),
                              ]
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditProfileScreen(
                                currentName: displayName,
                                currentEmail: displayEmail,
                                currentPhone: displayPhone,
                              ),
                            ),
                          );
                          // Plus besoin de setState ici car on écoute le Provider 
                          // qui sera notifié par l'écran d'édition !
                          if (result != null && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil mis à jour')));
                          }
                        },
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Modifier le profil'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              _sectionLabel('MON INSTALLATION'),
              Consumer<InstallationProvider>(
                builder: (context, instProvider, _) {
                  final inst = instProvider.installation;
                  if (inst == null) {
                    return _glassCard(
                      child: const Text('Aucune installation configurée.', style: TextStyle(color: AppTheme.textSecondary)),
                    );
                  }
                  return _glassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(inst.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: AppTheme.primaryYellowDim, borderRadius: BorderRadius.circular(8)),
                              child: Text('${inst.powerKW} kWp', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryYellow, fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _instRow(Icons.grid_view, '${inst.numPanels} panneaux (${inst.panelType.label})'),
                        _instRow(Icons.explore_outlined, '${inst.orientation.label} (Inclinaison: ${inst.tiltAngle.round()}°)'),
                        _instRow(Icons.location_on_outlined, 'Lat: ${inst.latitude.toStringAsFixed(4)}, Lng: ${inst.longitude.toStringAsFixed(4)}'),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => PVSetupScreen(userId: inst.userId, existing: inst)),
                              );
                            },
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text('Modifier l\'installation'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),
              _sectionLabel('À PROPOS'),
              _glassCard(
                child: const Row(
                  children: [
                    Icon(Icons.wb_sunny_rounded, color: AppTheme.primaryYellow, size: 28),
                    SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PV Monitor', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                        Text('Version 2.0.0', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
              



              
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentRed.withOpacity(0.15),
                    foregroundColor: AppTheme.accentRed,
                    side: BorderSide(color: AppTheme.accentRed.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text('Déconnexion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  onPressed: () async {
                    // 1. Capturer le Navigator racine AVANT la déconnexion
                    final navigator = Navigator.of(context, rootNavigator: true);
                    
                    // 2. Déconnexion via les providers (Data et Auth)
                    context.read<DataProvider>().disconnect();
                    await authProvider.logout();
                    
                    // 3. Redirection forcée vers AuthGate (qui reverra l'utilisateur vers Login)
                    navigator.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const AuthGate()),
                      (route) => false,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
