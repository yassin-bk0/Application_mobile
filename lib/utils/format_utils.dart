class FormatUtils {
  /// Converts power from Watts to Kilowatts and formats it as a string with unit
  /// Example: 2500 -> "2.50 kW"
  static String formatPower(double? watts) {
    if (watts == null) return "0.00 kW";
    double kw = watts / 1000.0;
    return "${kw.toStringAsFixed(2)} kW";
  }

  /// Converts power from Watts to Kilowatts and formats it as a string without unit
  /// Example: 2500 -> "2.50"
  static String formatPowerValue(double? watts) {
    if (watts == null) return "0.00";
    double kw = watts / 1000.0;
    return kw.toStringAsFixed(2);
  }

  /// Converts energy from Wh to kWh and formats it with unit.
  ///
  /// Usage : chaque point horaire = puissance moyenne (W) × 1h = Wh.
  /// La somme de N points horaires est donc en Wh → divisé par 1000 = kWh.
  ///
  /// Example: 5400 Wh -> "5.40 kWh"
  static String formatEnergy(double? wh) {
    if (wh == null) return "0.00 kWh";
    final kwh = wh / 1000.0;
    if (kwh.abs() >= 10) return "${kwh.toStringAsFixed(1)} kWh";
    return "${kwh.toStringAsFixed(2)} kWh";
  }

  /// Signe + ou - en préfixe (pour le bilan net).
  /// Example: 1200 Wh -> "+1.20 kWh", -500 Wh -> "-0.50 kWh"
  static String formatEnergyWithSign(double? wh) {
    if (wh == null) return "0.00 kWh";
    final sign = (wh >= 0) ? '+' : '';
    return '$sign${formatEnergy(wh)}';
  }
}

