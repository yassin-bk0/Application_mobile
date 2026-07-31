import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [HourlyArchiveService]
/// ─────────────────────────────────────────────────────────────────────────────
/// Responsabilités :
///   1. Détecter chaque changement d'heure (ex: 17h → 18h).
///   2. À la fin de chaque heure, créer le document `{heure}h` dans Firestore
///      sous la structure : historique/annees/docs/{year}/mois/{month}/jours/{day}/heures/{hh}h
///   3. Au démarrage, détecter si des heures ont été manquées (app fermée, PC éteint)
///      et les recréer automatiquement depuis `current_data` si disponible.
///   4. Ne jamais écraser un document existant (sécurité contre la perte de données).
///   5. Recalculer automatiquement le rendement à chaque sauvegarde.
///   6. Mettre à jour les documents parents (jours, mois, annees) après chaque archivage horaire.
/// ─────────────────────────────────────────────────────────────────────────────
class HourlyArchiveService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Identifiants de l'utilisateur et de l'installation.
  String? _userId;
  String? _installationId;

  /// Timer qui vérifie chaque minute si l'heure a changé.
  Timer? _hourCheckTimer;

  /// L'heure courante suivie par le service.
  int _currentHour = -1;

  // ─── Démarrage ────────────────────────────────────────────────────────────

  /// Démarre le service. À appeler après login utilisateur.
  /// [userId] : UID Firebase Auth.
  /// [installationId] : ID de l'installation PV.
  Future<void> start({
    required String userId,
    required String installationId,
  }) async {
    _userId = userId;
    _installationId = installationId;
    _currentHour = DateTime.now().hour;

    debugPrint('[HourlyArchive] 🚀 Démarrage pour $userId / $installationId, heure courante: ${_currentHour}h');

    // 1. Récupérer les heures manquées depuis le dernier arrêt de l'app.
    await _recoverMissedHours();

    // 2. Démarrer la surveillance des changements d'heure (vérif chaque 30 sec).
    _hourCheckTimer?.cancel();
    _hourCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkHourChange();
    });
  }

  /// Arrête le service et libère les ressources.
  void stop() {
    _hourCheckTimer?.cancel();
    _hourCheckTimer = null;
    _userId = null;
    _installationId = null;
    debugPrint('[HourlyArchive] 🛑 Service arrêté.');
  }

  // ─── Détection du changement d'heure ──────────────────────────────────────

  /// Vérifie si l'heure a changé. Si oui, archive l'heure précédente.
  Future<void> _checkHourChange() async {
    final now = DateTime.now();
    if (now.hour != _currentHour) {
      // L'heure vient de changer !
      final hourJustEnded = _currentHour;
      final dayOfHourEnded = now.subtract(const Duration(hours: 1)); // l'heure passée appartient à hier si on vient de passer minuit

      _currentHour = now.hour;

      debugPrint('[HourlyArchive] ⏰ Changement d\'heure détecté : ${hourJustEnded}h → ${now.hour}h');

      // Archiver l'heure qui vient de se terminer.
      await _archiveHour(
        year: dayOfHourEnded.year,
        month: dayOfHourEnded.month,
        day: dayOfHourEnded.day,
        hour: hourJustEnded,
      );

      // Sauvegarder l'heure archivée dans SharedPreferences pour la récupération.
      await _saveLastArchivedHour(dayOfHourEnded, hourJustEnded);
    }
  }

  // ─── Archivage d'une heure ────────────────────────────────────────────────

  /// Archive une heure spécifique.
  /// Lit les données depuis `current_data` et les copie dans le document horaire.
  /// N'écrase JAMAIS un document existant complet.
  Future<void> _archiveHour({
    required int year,
    required int month,
    required int day,
    required int hour,
  }) async {
    if (_userId == null || _installationId == null) return;

    final yearStr = year.toString();
    final monthStr = month.toString().padLeft(2, '0');
    final dayStr = day.toString().padLeft(2, '0');
    final hourLabel = '${hour.toString().padLeft(2, '0')}h';

    final hourDocPath = 'users/$_userId/installations/$_installationId'
        '/historique/annees/docs/$yearStr/mois/$monthStr/jours/$dayStr/heures/$hourLabel';

    debugPrint('[HourlyArchive] 💾 Archivage de $hourDocPath ...');

    try {
      final hourDocRef = _firestore.doc(hourDocPath);

      // 1. Vérifier si le document existe déjà et est complet.
      final existing = await hourDocRef.get();
      if (existing.exists) {
        final data = existing.data()!;
        // Si le document a déjà des valeurs non nulles → on ne touche pas.
        final hasRealData = (data['productionAC'] != null && (data['productionAC'] as num) > 0)
                         || (data['consommationAC'] != null && (data['consommationAC'] as num) > 0);
        if (hasRealData) {
          debugPrint('[HourlyArchive] ⏭️ Document $hourLabel existe déjà avec données réelles. Ignoré.');
          return;
        }
      }

      // 2. Lire les dernières données depuis `current_data` (source de vérité temps réel).
      final currentDataRef = _firestore
          .collection('users')
          .doc(_userId)
          .collection('installations')
          .doc(_installationId)
          .collection('real_time')
          .doc('current_data');

      final currentSnap = await currentDataRef.get();
      if (!currentSnap.exists) {
        debugPrint('[HourlyArchive] ⚠️ current_data introuvable. Archive vide créée pour $hourLabel.');
        // Créer un document vide pour marquer que l'heure a été traitée.
        await hourDocRef.set({
          'productionAC': 0.0,
          'productionDC': 0.0,
          'consommationAC': 0.0,
          'rendement': 0.0,
          'nbMesures': 0,
          'source': 'auto_archive_empty',
          'timestamp_update': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      }

      final liveData = currentSnap.data()!;

      // 3. Extraire et calculer les valeurs.
      final prodAC = (liveData['productionAC'] as num?)?.toDouble() ?? 0.0;
      final prodDC = (liveData['productionDC'] as num?)?.toDouble() ?? 0.0;
      final consAC = (liveData['consommationAC'] as num?)?.toDouble() ?? 0.0;

      // Recalcul du rendement (ProdAC / ProdDC * 100).
      final rendement = prodDC > 0 ? (prodAC / prodDC) * 100.0 : 0.0;

      // 4. Créer le document horaire dans Firestore.
      await hourDocRef.set({
        'productionAC': prodAC,
        'productionDC': prodDC,
        'consommationAC': consAC,
        'rendement': rendement,
        'source': 'auto_archive',
        'timestamp_update': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // merge:true = ne supprime pas les champs manuels existants

      debugPrint('[HourlyArchive] ✅ Document $hourLabel créé : prodAC=$prodAC, rendement=${rendement.toStringAsFixed(1)}%');

      // 5. Recalculer et mettre à jour les totaux du parent (jour).
      await _updateParentTotals(
        yearStr: yearStr, monthStr: monthStr, dayStr: dayStr,
      );

    } catch (e) {
      debugPrint('[HourlyArchive] ❌ Erreur archivage $hourLabel: $e');
    }
  }

  // ─── Mise à jour des totaux parents ──────────────────────────────────────

  /// Lit toutes les heures du jour et recalcule les totaux dans le document `jour`.
  Future<void> _updateParentTotals({
    required String yearStr,
    required String monthStr,
    required String dayStr,
  }) async {
    if (_userId == null || _installationId == null) return;

    try {
      final heuresRef = _firestore
          .collection('users').doc(_userId)
          .collection('installations').doc(_installationId)
          .collection('historique').doc('annees')
          .collection('docs').doc(yearStr)
          .collection('mois').doc(monthStr)
          .collection('jours').doc(dayStr)
          .collection('heures');

      final heuresSnap = await heuresRef.get();

      double totalProd = 0, totalProdDC = 0, totalCons = 0;
      for (final doc in heuresSnap.docs) {
        final d = doc.data();
        totalProd += (d['productionAC'] as num?)?.toDouble() ?? 0.0;
        totalProdDC += (d['productionDC'] as num?)?.toDouble() ?? 0.0;
        totalCons += (d['consommationAC'] as num?)?.toDouble() ?? 0.0;
      }

      final dayDocRef = _firestore
          .collection('users').doc(_userId)
          .collection('installations').doc(_installationId)
          .collection('historique').doc('annees')
          .collection('docs').doc(yearStr)
          .collection('mois').doc(monthStr)
          .collection('jours').doc(dayStr);

      await dayDocRef.set({
        'total_production': totalProd,
        'total_productionDC': totalProdDC,
        'total_consommation': totalCons,
        'timestamp_update': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('[HourlyArchive] 📊 Totaux jour $dayStr/$monthStr/$yearStr mis à jour : prod=$totalProd, cons=$totalCons');

      // Recalculer également les totaux du mois.
      await _updateMonthTotals(yearStr: yearStr, monthStr: monthStr);

    } catch (e) {
      debugPrint('[HourlyArchive] ❌ Erreur mise à jour totaux jour: $e');
    }
  }

  /// Lit tous les jours du mois et recalcule les totaux du document `mois`.
  Future<void> _updateMonthTotals({
    required String yearStr,
    required String monthStr,
  }) async {
    if (_userId == null || _installationId == null) return;

    try {
      final joursRef = _firestore
          .collection('users').doc(_userId)
          .collection('installations').doc(_installationId)
          .collection('historique').doc('annees')
          .collection('docs').doc(yearStr)
          .collection('mois').doc(monthStr)
          .collection('jours');

      final joursSnap = await joursRef.get();
      double totalProd = 0, totalProdDC = 0, totalCons = 0;
      for (final doc in joursSnap.docs) {
        final d = doc.data();
        totalProd += (d['total_production'] as num?)?.toDouble() ?? 0.0;
        totalProdDC += (d['total_productionDC'] as num?)?.toDouble() ?? 0.0;
        totalCons += (d['total_consommation'] as num?)?.toDouble() ?? 0.0;
      }

      await _firestore
          .collection('users').doc(_userId)
          .collection('installations').doc(_installationId)
          .collection('historique').doc('annees')
          .collection('docs').doc(yearStr)
          .collection('mois').doc(monthStr)
          .set({
            'total_production': totalProd,
            'total_productionDC': totalProdDC,
            'total_consommation': totalCons,
            'timestamp_update': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      debugPrint('[HourlyArchive] 📅 Totaux mois $monthStr/$yearStr mis à jour.');
    } catch (e) {
      debugPrint('[HourlyArchive] ❌ Erreur mise à jour totaux mois: $e');
    }
  }

  // ─── Récupération des heures manquées ────────────────────────────────────

  /// Au démarrage de l'app, vérifie directement dans Firestore quelles heures
  /// manquent pour aujourd'hui (et hier si on vient de passer minuit).
  /// Recrée TOUS les documents horaires manquants.
  ///
  /// Avantage : Fonctionne dès le premier démarrage même sans SharedPreferences.
  Future<void> _recoverMissedHours() async {
    if (_userId == null || _installationId == null) return;

    final now = DateTime.now();
    debugPrint('[HourlyArchive] 🔍 Vérification des heures manquantes pour aujourd\'hui (${now.day}/${now.month}/${now.year})...');

    // 1. Vérifier et compléter les heures d'AUJOURD'HUI (de 00h jusqu'à l'heure précédente)
    await _fillMissingHoursForDay(
      year: now.year,
      month: now.month,
      day: now.day,
      upToHour: now.hour, // On n'archive pas l'heure actuelle (encore en cours)
    );

    // 2. Si on est en début de journée (heure < 2), vérifier aussi HIER
    // (car l'app a pu être fermée avant minuit et certaines heures de la nuit manquent)
    if (now.hour < 2) {
      final yesterday = now.subtract(const Duration(days: 1));
      debugPrint('[HourlyArchive] 🔍 Vérification également du ${yesterday.day}/${yesterday.month}/${yesterday.year} (début de journée)...');
      await _fillMissingHoursForDay(
        year: yesterday.year,
        month: yesterday.month,
        day: yesterday.day,
        upToHour: 24, // Toutes les heures de la journée précédente
      );
    }

    // 3. Mettre à jour SharedPreferences avec l'heure actuelle
    await _saveLastArchivedHour(now, now.hour > 0 ? now.hour - 1 : 0);
    debugPrint('[HourlyArchive] ✅ Vérification et récupération terminées.');
  }

  /// Vérifie quelles heures manquent dans Firestore pour un jour donné
  /// et les crée automatiquement.
  Future<void> _fillMissingHoursForDay({
    required int year,
    required int month,
    required int day,
    required int upToHour, // Exclusif : archive 0h à (upToHour - 1)h
  }) async {
    if (upToHour == 0) return; // Rien à archiver si on est à 00h00

    final yearStr = year.toString();
    final monthStr = month.toString().padLeft(2, '0');
    final dayStr = day.toString().padLeft(2, '0');

    // Lire les documents d'heures existants depuis Firestore
    final heuresRef = _firestore
        .collection('users').doc(_userId)
        .collection('installations').doc(_installationId)
        .collection('historique').doc('annees')
        .collection('docs').doc(yearStr)
        .collection('mois').doc(monthStr)
        .collection('jours').doc(dayStr)
        .collection('heures');

    final snap = await heuresRef.get();

    // Construire l'ensemble des heures existantes (ex: {0, 1, 5, 8})
    final existingHours = snap.docs.map((doc) {
      return int.tryParse(doc.id.replaceAll('h', '')) ?? -1;
    }).toSet();

    debugPrint('[HourlyArchive] 📋 Heures existantes pour $dayStr/$monthStr: $existingHours');

    // Pour chaque heure de 00h jusqu'à upToHour (exclusif)
    for (int h = 0; h < upToHour; h++) {
      if (!existingHours.contains(h)) {
        // Heure manquante → créer le document
        debugPrint('[HourlyArchive] 🔁 Création heure manquante : ${h.toString().padLeft(2,'0')}h');
        await _archiveHour(year: year, month: month, day: day, hour: h);
        // Petite pause pour éviter de saturer Firestore avec des écritures en rafale
        await Future.delayed(const Duration(milliseconds: 200));
      } else {
        debugPrint('[HourlyArchive] ✅ Heure ${h.toString().padLeft(2,'0')}h déjà présente, ignorée.');
      }
    }
  }


  // ─── SharedPreferences : Suivi du dernier archivage ──────────────────────

  /// Sauvegarde localement le timestamp de la dernière heure archivée.
  Future<void> _saveLastArchivedHour(DateTime day, int hour) async {
    final archived = DateTime(day.year, day.month, day.day, hour);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('hourly_archive_last_timestamp', archived.millisecondsSinceEpoch);
    debugPrint('[HourlyArchive] 💾 Dernière heure archivée sauvegardée : ${hour}h');
  }

  // ─── API Publique : Forcer un archivage manuel ────────────────────────────

  /// Permet de forcer manuellement l'archivage d'une heure.
  /// Utile pour les tests ou la récupération manuelle.
  Future<void> forceArchiveHour({
    required int year,
    required int month,
    required int day,
    required int hour,
  }) async {
    await _archiveHour(year: year, month: month, day: day, hour: hour);
  }

  /// Retourne les heures manquantes d'un jour donné depuis Firestore.
  /// Utile pour l'interface de diagnostic.
  Future<List<int>> getMissingHours({
    required int year,
    required int month,
    required int day,
  }) async {
    if (_userId == null || _installationId == null) return [];

    final yearStr = year.toString();
    final monthStr = month.toString().padLeft(2, '0');
    final dayStr = day.toString().padLeft(2, '0');

    final heuresRef = _firestore
        .collection('users').doc(_userId)
        .collection('installations').doc(_installationId)
        .collection('historique').doc('annees')
        .collection('docs').doc(yearStr)
        .collection('mois').doc(monthStr)
        .collection('jours').doc(dayStr)
        .collection('heures');

    final snap = await heuresRef.get();
    final existingHours = snap.docs.map((doc) {
      return int.tryParse(doc.id.replaceAll('h', '')) ?? -1;
    }).toSet();

    // Retourner les heures de 0 à heure_actuelle - 1 qui sont absentes.
    final currentHour = DateTime.now().hour;
    final missing = <int>[];
    for (int h = 0; h < currentHour; h++) {
      if (!existingHours.contains(h)) missing.add(h);
    }
    return missing;
  }
}
