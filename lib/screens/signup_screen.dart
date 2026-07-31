import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../theme/app_theme.dart';
import 'pv_setup_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _usernameController = TextEditingController();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible   = false;
  bool _isLoading           = false;

  // ── Auth logic ────────────────────────────────────────────────────────────
  Future<void> _signUp() async {
    final username = _usernameController.text.trim();
    final email    = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      _snack('Tous les champs sont requis.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email, password: password,
      );

      final user = credential.user;
      if (user != null) {
        // Save basic user profile
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'username':  username,
          'email':     email,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await FirebaseAnalytics.instance.setUserId(id: user.uid);
        await FirebaseAnalytics.instance.logSignUp(signUpMethod: 'email');

        if (mounted) {
          // ✅ Pop back to AuthGate.
          // Since the user is now authenticated and has no installation,
          // AuthGate will automatically swap its child to PVSetupScreen!
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Une erreur est survenue';
      if (e.code == 'weak-password')        message = 'Mot de passe trop faible (min. 6 caractères).';
      if (e.code == 'email-already-in-use') message = 'Un compte existe déjà avec cet e-mail.';
      if (e.code == 'invalid-email')        message = 'Adresse e-mail invalide.';
      _snack(message);
    } catch (e) {
      _snack('Erreur: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            'https://images.unsplash.com/photo-1509391366360-2e959784a276?w=800&q=80',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: AppTheme.bgDeep),
          ),
          Container(color: Colors.black.withOpacity(0.50)),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 48),

                    // Logo
                    Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primaryYellow.withOpacity(0.15),
                        border: Border.all(color: AppTheme.primaryYellow.withOpacity(0.5), width: 1.5),
                      ),
                      child: const Icon(Icons.wb_sunny_rounded, color: AppTheme.primaryYellow, size: 32),
                    ),
                    const SizedBox(height: 12),
                    const Text('P V   M O N I T O R',
                      style: TextStyle(color: AppTheme.primaryYellow, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 4)),

                    const SizedBox(height: 28),

                    // Étape indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryYellowDim,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.primaryYellow.withOpacity(0.4)),
                      ),
                      child: const Text(
                        '① Créer un compte  ·  ② Installation PV  ·  ③ Dashboard',
                        style: TextStyle(color: AppTheme.primaryYellow, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Glass card
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.15)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Créer un compte', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text('Étape 1 sur 2 — Informations personnelles',
                              style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 13)),
                            const SizedBox(height: 28),

                            _fieldLabel('NOM D\'UTILISATEUR'),
                            const SizedBox(height: 8),
                            _glassField(ctrl: _usernameController, hint: 'Jean Dupont', icon: Icons.person_outline_rounded),
                            const SizedBox(height: 18),

                            _fieldLabel('EMAIL'),
                            const SizedBox(height: 8),
                            _glassField(ctrl: _emailController, hint: 'name@company.com', icon: Icons.email_outlined, keyboard: TextInputType.emailAddress),
                            const SizedBox(height: 18),

                            _fieldLabel('MOT DE PASSE'),
                            const SizedBox(height: 8),
                            _glassPasswordField(),
                            const SizedBox(height: 28),

                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _signUp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryYellow,
                                  foregroundColor: Colors.black87,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                ),
                                child: _isLoading
                                    ? const SizedBox(width: 22, height: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black54))
                                    : const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('Continuer vers l\'installation', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                          SizedBox(width: 8),
                                          Icon(Icons.arrow_forward_rounded, size: 18),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Déjà un compte ? ', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: const Text('Se connecter', style: TextStyle(color: AppTheme.primaryYellow, fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String t) => Text(t, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2));

  Widget _glassField({required TextEditingController ctrl, required String hint, required IconData icon, TextInputType? keyboard}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.15))),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.5), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _glassPasswordField() {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.15))),
      child: TextField(
        controller: _passwordController,
        obscureText: !_isPasswordVisible,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: '••••••••',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
          prefixIcon: Icon(Icons.lock_outline_rounded, color: Colors.white.withOpacity(0.5), size: 20),
          suffixIcon: IconButton(
            icon: Icon(_isPasswordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: Colors.white.withOpacity(0.5), size: 20),
            onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
