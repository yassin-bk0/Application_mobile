import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _localPhotoPath;

  User? get user => _user;
  Map<String, dynamic>? get userData => _userData;
  bool get isLoading => _isLoading;
  String get username => _userData?['username'] ?? 'Utilisateur';
  String get phone => _userData?['phone'] ?? '';
  String? get localPhotoPath => _localPhotoPath;

  AuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      if (_user != null) {
        _fetchUserData(_user!.uid);
      } else {
        _userData = null;
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  Future<void> _fetchUserData(String uid) async {
    _isLoading = true;
    notifyListeners();

    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _userData = doc.data() as Map<String, dynamic>?;
      }
      final prefs = await SharedPreferences.getInstance();
      _localPhotoPath = prefs.getString('profile_photo_$uid');
    } catch (e) {
      debugPrint("Erreur de récupération des données utilisateur: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateLocalPhoto(String path) async {
    if (_user == null) return;
    _localPhotoPath = path;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_photo_${_user!.uid}', path);
  }

  Future<void> updateUserProfile(String newName, String newPhone) async {
    if (_user == null) return;
    try {
      await _firestore.collection('users').doc(_user!.uid).set({
        'username': newName,
        'phone': newPhone,
      }, SetOptions(merge: true));
      
      if (_userData != null) {
        _userData!['username'] = newName;
        _userData!['phone'] = newPhone;
      } else {
        _userData = {'username': newName, 'phone': newPhone};
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Erreur lors de la mise à jour du profil: $e");
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}
