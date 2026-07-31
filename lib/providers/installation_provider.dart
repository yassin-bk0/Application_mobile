import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/installation_pv.dart';

/// Manages the loading and saving of the user's PV installations.
/// Linked to [AuthProvider] via [ChangeNotifierProxyProvider].
class InstallationProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<InstallationPV> _installations = [];
  List<InstallationPV> get installations => _installations;

  /// Returns the first installation (for compatibility with existing UI).
  InstallationPV? get installation => _installations.isNotEmpty ? _installations.first : null;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  /// True once we've finished the initial Firestore check (even if no installation found).
  bool _checked = false;
  bool get checked => _checked;

  /// True only when we have at least one valid, complete installation.
  bool get hasInstallation => _installations.isNotEmpty;

  String? _currentUid;
  String? get currentUid => _currentUid;

  // ── Called by ChangeNotifierProxyProvider ─────────────────────────────────
  Future<void> updateUser(User? user) async {
    if (user?.uid == _currentUid) return;
    _currentUid = user?.uid;

    if (user == null) {
      _installations = [];
      _checked = false;
      notifyListeners();
      return;
    }

    await loadInstallation(user.uid);
  }

  // ── Firestore reads ───────────────────────────────────────────────────────
  Future<void> loadInstallation(String uid) async {
    _isLoading = true;
    _error = null;
    _checked = false;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('installations')
          .orderBy('createdAt', descending: false)
          .get();

      _installations = snapshot.docs.map((doc) => InstallationPV.fromFirestore(doc)).toList();
    } catch (e) {
      _error = e.toString();
      debugPrint('[InstallationProvider] load error: $e');
    } finally {
      _isLoading = false;
      _checked = true;
      notifyListeners();
    }
  }

  // ── Firestore writes ──────────────────────────────────────────────────────
  Future<bool> saveInstallation(InstallationPV installation) async {
    if (_currentUid == null || _currentUid != installation.userId) {
      _error = 'User not authenticated or mismatched user ID';
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final collectionRef = _firestore
          .collection('users')
          .doc(installation.userId)
          .collection('installations');

      DocumentReference docRef;
      if (installation.id != null && installation.id!.isNotEmpty) {
        docRef = collectionRef.doc(installation.id);
        await docRef.set(installation.toFirestore());
      } else {
        docRef = collectionRef.doc();
        await docRef.set(installation.toFirestore());
      }

      // Refresh installations list
      await loadInstallation(installation.userId);

      // Also persist primary lat/lng in users doc for WeatherProvider (compatibility)
      if (_installations.isNotEmpty && _installations.first.id == docRef.id) {
        await _firestore.collection('users').doc(installation.userId).set({
          'latitude':  installation.latitude,
          'longitude': installation.longitude,
        }, SetOptions(merge: true));
      } else if (_installations.isEmpty) {
        // If this is the very first installation being added
        await _firestore.collection('users').doc(installation.userId).set({
          'latitude':  installation.latitude,
          'longitude': installation.longitude,
        }, SetOptions(merge: true));
      }

      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('[InstallationProvider] save error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _installations = [];
    _checked = false;
    _currentUid = null;
    notifyListeners();
  }
}
