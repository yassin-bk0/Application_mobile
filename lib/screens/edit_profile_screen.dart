import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';

class EditProfileScreen extends StatefulWidget {
  final String currentName;
  final String currentEmail;
  final String currentPhone;

  const EditProfileScreen({
    super.key,
    required this.currentName,
    required this.currentEmail,
    required this.currentPhone,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _phoneController;
  String? _tempPhotoPath;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _emailController = TextEditingController(text: widget.currentEmail);
    _passwordController = TextEditingController(text: '********');
    _phoneController = TextEditingController(text: widget.currentPhone);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _tempPhotoPath = context.read<AuthProvider>().localPhotoPath;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Modifier le profil'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Avatar
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [Color(0xFFF5C842), Color(0xFFFFB300)]),
                    image: _tempPhotoPath != null && File(_tempPhotoPath!).existsSync()
                        ? DecorationImage(
                            image: FileImage(File(_tempPhotoPath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _tempPhotoPath != null && File(_tempPhotoPath!).existsSync()
                      ? null
                      : Center(
                          child: Text(
                            _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : 'U',
                            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                ),
                GestureDetector(
                  onTap: () async {
                    try {
                      final ImagePicker picker = ImagePicker();
                      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        setState(() {
                          _tempPhotoPath = image.path;
                        });
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primaryYellow, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, size: 20, color: AppTheme.primaryYellow),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _glassTextField(ctrl: _nameController, label: 'Nom complet', icon: Icons.person),
          const SizedBox(height: 16),
          _glassTextField(ctrl: _emailController, label: 'Adresse email', icon: Icons.email, keyboard: TextInputType.emailAddress),
          const SizedBox(height: 16),
          _glassTextField(
            ctrl: _passwordController,
            label: 'Mot de passe',
            icon: Icons.lock,
            obscureText: true,
            suffixIcon: TextButton(
              onPressed: () {
                _passwordController.clear();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saisissez le nouveau mot de passe...')));
              },
              child: const Text('Changer', style: TextStyle(color: AppTheme.primaryYellow, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
          _glassTextField(ctrl: _phoneController, label: 'Numéro de téléphone (optionnel)', icon: Icons.phone, keyboard: TextInputType.phone),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () async {
                final newPassword = _passwordController.text;
                // Si le mot de passe a été modifié
                if (newPassword != '********' && newPassword.isNotEmpty) {
                  try {
                    await FirebaseAuth.instance.currentUser?.updatePassword(newPassword);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mot de passe mis à jour avec succès !')));
                    }
                  } on FirebaseAuthException catch (e) {
                    if (e.code == 'requires-recent-login') {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez vous déconnecter et vous reconnecter pour changer le mot de passe pour des raisons de sécurité.')));
                    } else {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur auth: ${e.message}')));
                    }
                    return; // Ne pas fermer la page en cas d'erreur de mot de passe
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                    return;
                  }
                }

                // Sauvegarde de l'image choisie
                if (mounted && _tempPhotoPath != null) {
                   await context.read<AuthProvider>().updateLocalPhoto(_tempPhotoPath!);
                }

                // Sauvegarde du nom et téléphone sur Firestore :
                if (mounted) {
                   await context.read<AuthProvider>().updateUserProfile(
                     _nameController.text.trim(),
                     _phoneController.text.trim()
                   );
                }

                // Une fois le mot de passe géré avec succès (ou non modifié), on retourne les autres données
                if (mounted) {
                  Navigator.pop(context, {
                    'name': _nameController.text,
                    'email': _emailController.text,
                    'phone': _phoneController.text,
                  });
                }
              },
              child: const Text('Enregistrer', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
