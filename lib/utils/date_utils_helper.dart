import 'package:intl/intl.dart';

class DateUtilsHelper {
  /// Génère un identifiant de document Firestore compatible (pas de '/')
  /// Format : "yyyy-MM-dd_HH:mm:ss"
  static String generateRealtimeDocId(DateTime ts) {
    return DateFormat('yyyy-MM-dd_HH:mm:ss').format(ts);
  }

  /// Formate une heure pour l'historique (ex: "16h")
  static String formatHourLabel(int hour) {
    return '${hour.toString().padLeft(2, '0')}h';
  }

  /// Retourne le nom du mois avec padding (ex: "04")
  static String formatMonth(int month) {
    return month.toString().padLeft(2, '0');
  }

  /// Retourne le jour avec padding (ex: "07")
  static String formatDay(int day) {
    return day.toString().padLeft(2, '0');
  }
}
