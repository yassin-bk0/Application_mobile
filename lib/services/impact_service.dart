class ImpactService {
  static const double rateTNDperKWh = 0.280; // Standard STEG Tunisia
  static const double kgCO2perKWh = 0.45;    // Standard Tunisia
  static const double kgCO2perTree = 15.0;   // Estimated

  static double calculateSavings(double totalKWh) {
    return totalKWh * rateTNDperKWh;
  }

  static double calculateCO2(double totalKWh) {
    return totalKWh * kgCO2perKWh;
  }

  static int calculateTrees(double totalKWh) {
    return (calculateCO2(totalKWh) / kgCO2perTree).floor();
  }
}
