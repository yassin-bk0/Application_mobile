import 'dart:math';
import 'dart:async';
import '../models/pv_data.dart';

/// Service de génération de données PV **déterministes** simulant
/// une installation de 3 kWc en Tunisie.
///
/// Règles physiques respectées :
/// - Production = 0 la nuit (avant 06h et après 18h30)
/// - Courbe en cloche sinusoïdale, pic ~2850W à 12h30
/// - Rendement onduleur fixé à 95%
/// - Consommation avec profils horaires fixes (matin/midi/soir)
/// - Bilan net = prodAC - consAC
/// - Batterie : charge si bilan > 0, décharge si bilan < 0
/// - SOC : simulé par intégration du bilan sur 24h (entre 20% et 95%)
/// - gridImport / gridExport corrélés au bilan
///
/// **Pas de Random() pur** — les valeurs sont reproductibles à chaque appel
/// pour le même timestamp. Un bruit de ±2% est calculé via sin(time) pour
/// rester déterministe tout en semblant "vivant".
class FakeDataService {
  // ── Constantes physiques ─────────────────────────────────────────────────
  static const double _peakDC = 3000.0; // W — puissance crête panneau
  static const double _inverterEff = 0.95; // rendement onduleur
  static const double _sunrise = 6.0; // h
  static const double _sunset = 18.5; // h
  static const double _batteryCapacity = 5000.0; // Wh (batterie 5kWh)
  static const double _maxBatteryPower = 1500.0; // W charge/décharge max

  Timer? _timer;
  final StreamController<PvData> _streamController =
      StreamController<PvData>.broadcast();

  Stream<PvData> get dataStream => _streamController.stream;

  // ── API publique ─────────────────────────────────────────────────────────

  /// Démarre le stream fake — émet un nouveau point toutes les 15 minutes.
  void startStream() {
    _timer?.cancel();
    // Émet immédiatement un premier point
    _streamController.add(generateForTime(DateTime.now()));
    // Puis toutes les 15 minutes
    _timer = Timer.periodic(const Duration(minutes: 15), (_) {
      if (!_streamController.isClosed) {
        _streamController.add(generateForTime(DateTime.now()));
      }
    });
  }

  /// Arrête le stream.
  void stopStream() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stopStream();
    _streamController.close();
  }

  // ── Génération d'un point à un instant donné ─────────────────────────────

  /// Génère un [PvData] réaliste et **déterministe** pour un [time] donné.
  static PvData generateForTime(DateTime time) {
    final double t = time.hour + time.minute / 60.0;

    // ─── Production DC (cloche sinusoïdale) ───────────────────────────────
    double prodDC = 0.0;
    if (t > _sunrise && t < _sunset) {
      final double progress = (t - _sunrise) / (_sunset - _sunrise);
      // Sinus → forme en cloche parfaite
      prodDC = _peakDC * sin(progress * pi);
      // Bruit déterministe ±2% basé sur les secondes (pas de Random)
      final double noise = 0.02 * sin(time.second * 0.1 + time.minute * 0.7);
      prodDC *= (1.0 + noise);
      if (prodDC < 0) prodDC = 0.0;
    }

    // ─── Production AC (après onduleur) ───────────────────────────────────
    final double prodAC = prodDC * _inverterEff;

    // ─── Tension & courant PV ─────────────────────────────────────────────
    // Tension proportionnelle à l'ensoleillement, courant déduit
    final double vPv = prodDC > 0 ? 250.0 + 10.0 * (prodDC / _peakDC) : 0.0;
    final double iPv = vPv > 0 ? prodDC / vPv : 0.0;

    // ─── Irradiation (proportionnelle à la production DC) ─────────────────
    // Max ~1000 W/m² à midi pour 3 kWc
    final double irradiation = (prodDC / _peakDC) * 1000.0;

    // ─── Consommation AC (profils fixes) ──────────────────────────────────
    double consAC = _baseConsumption(t);

    // ─── Bilan net ────────────────────────────────────────────────────────
    final double bilan = prodAC - consAC;

    // ─── Batterie ─────────────────────────────────────────────────────────
    // La batterie absorbe le surplus ou comble le déficit, dans les limites
    double batteryPower = bilan.clamp(-_maxBatteryPower, _maxBatteryPower);

    // SOC simulé : intégration sur 24h (0h = 40%, pic à 17h = 90%)
    final double batterySOC = _estimateSOC(t);

    // Si SOC >= 95% : plus de charge (bilan positif exporté)
    if (batterySOC >= 95.0 && batteryPower > 0) batteryPower = 0.0;
    // Si SOC <= 20% : plus de décharge
    if (batterySOC <= 20.0 && batteryPower < 0) batteryPower = 0.0;

    // ─── Échanges réseau ──────────────────────────────────────────────────
    // Export : surplus non absorbé par la batterie
    double gridExport = 0.0;
    double gridImport = 0.0;

    if (bilan > 0) {
      // Surplus : batterie absorbe en priorité, le reste part au réseau
      final double absorbed = batteryPower.clamp(0.0, _maxBatteryPower);
      gridExport = (bilan - absorbed).clamp(0.0, double.infinity);
    } else if (bilan < 0) {
      // Déficit : batterie compense en priorité, le reste du réseau
      final double discharged = (-batteryPower).clamp(0.0, _maxBatteryPower);
      gridImport = (-bilan - discharged).clamp(0.0, double.infinity);
    }

    // ─── Température onduleur ─────────────────────────────────────────────
    // Corrélée à la production (25°C idle → 55°C pleine puissance)
    final double inverterTemp = 25.0 + 30.0 * (prodAC / (_peakDC * _inverterEff));

    // ─── Température ambiante ─────────────────────────────────────────────
    double temp = 15.0;
    if (t > _sunrise && t < _sunset) {
      final double progress = (t - _sunrise) / (_sunset - _sunrise);
      temp += 18.0 * sin(progress * pi);
    }

    // ─── Humidité (inversement corrélée à la temp) ────────────────────────
    final double humidity = (75.0 - (temp - 15.0)).clamp(30.0, 90.0);

    // ─── Tension / courant consommateur ───────────────────────────────────
    const double vCons = 230.0;
    final double iCons = consAC / vCons;

    // ─── Fréquence réseau ─────────────────────────────────────────────────
    // 50 Hz ± 0.1 Hz — variation déterministe basée sur l'heure
    final double frequency = 50.0 + 0.1 * sin(t * 0.5);

    return PvData(
      irradiance: irradiation,
      temperature: temp,
      humidity: humidity,
      vPv: vPv,
      iPv: iPv,
      pPv: prodAC,
      vConsumer: vCons,
      iConsumer: iCons,
      pConsumer: consAC,
      timestamp: time,
      batteryPower: batteryPower,
      batterySOC: batterySOC,
      gridImport: gridImport,
      gridExport: gridExport,
      inverterTemp: inverterTemp,
      frequency: frequency,
    );
  }

  /// Génère 24h d'historique (1 point toutes les 10 minutes = 144 points).
  static List<PvData> generateHistory24h() {
    final List<PvData> history = [];
    final DateTime now = DateTime.now();
    for (int i = 144; i >= 0; i--) {
      final DateTime ts = now.subtract(Duration(minutes: i * 10));
      history.add(generateForTime(ts));
    }
    return history;
  }

  // ── Helpers privés ───────────────────────────────────────────────────────

  /// Consommation AC de base selon l'heure (W) — valeurs fixes et réalistes.
  static double _baseConsumption(double t) {
    // Nuit profonde : 22h → 06h → 300 W (veille, frigo, etc.)
    if (t < 6.0 || t >= 22.0) return 300.0;
    // Réveil : 06h → 07h — montre lente
    if (t < 7.0) return 400.0 + 200.0 * ((t - 6.0) / 1.0);
    // Pic matin : 07h → 09h (douche, bouilloire, grille-pain)
    if (t < 9.0) return 1100.0;
    // Creux matin : 09h → 12h (travail)
    if (t < 12.0) return 500.0;
    // Pic midi : 12h → 14h (cuisine, clim)
    if (t < 14.0) return 900.0;
    // Après-midi : 14h → 17h (clim, TV)
    if (t < 17.0) return 700.0;
    // Fin d'après-midi : 17h → 18h30 (préparation repas)
    if (t < 18.5) return 800.0;
    // Pic soir : 18h30 → 22h (repas, TV, clim)
    return 1500.0;
  }

  /// Estime le SOC (%) à l'heure [t] sur une journée typique.
  ///
  /// Modèle :
  /// - 00h → 06h : décharge de 70% à 40% (consommation nocturne)
  /// - 06h → 16h : charge de 40% à 90% (production dépasse conso)
  /// - 16h → 22h : décharge de 90% à 55% (production baisse, conso monte)
  /// - 22h → 00h : décharge de 55% à 40%
  static double _estimateSOC(double t) {
    if (t < 6.0) {
      // 70% → 40% pendant la nuit (6h de décharge)
      return 70.0 - (t / 6.0) * 30.0;
    } else if (t < 16.0) {
      // 40% → 90% pendant la journée solaire (10h de charge nette)
      return 40.0 + ((t - 6.0) / 10.0) * 50.0;
    } else if (t < 22.0) {
      // 90% → 55% en soirée (6h)
      return 90.0 - ((t - 16.0) / 6.0) * 35.0;
    } else {
      // 55% → 40% fin de soirée (2h)
      return 55.0 - ((t - 22.0) / 2.0) * 15.0;
    }
  }
}
