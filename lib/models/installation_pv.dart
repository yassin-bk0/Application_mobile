import 'package:cloud_firestore/cloud_firestore.dart';

/// Supported solar panel types.
enum PanelType {
  monocrystallin('Monocristallin'),
  polycrystallin('Polycristallin'),
  bifacial('Bifacial'),
  amorphe('Amorphe (Couche mince)');

  const PanelType(this.label);
  final String label;

  static PanelType fromString(String value) =>
      PanelType.values.firstWhere((e) => e.name == value, orElse: () => PanelType.monocrystallin);
}

/// Supported cardinal orientations (azimuth).
enum PanelOrientation {
  sud('Sud ↓', 0),
  sudEst('Sud-Est ↘', 45),
  est('Est →', 90),
  nordEst('Nord-Est ↗', 135),
  nord('Nord ↑', 180),
  nordOuest('Nord-Ouest ↖', 225),
  ouest('Ouest ←', 270),
  sudOuest('Sud-Ouest ↙', 315);

  const PanelOrientation(this.label, this.azimuth);
  final String label;
  final int azimuth;

  static PanelOrientation fromString(String value) =>
      PanelOrientation.values.firstWhere((e) => e.name == value, orElse: () => PanelOrientation.sud);
}

/// Data model for a PV installation.
class InstallationPV {
  final String? id;
  final String userId;
  final String name;
  final double latitude;
  final double longitude;
  final double powerKW;         // Installed peak power in kWp
  final int numPanels;          // Number of solar panels
  final PanelType panelType;
  final double tiltAngle;       // Inclination angle 0–90°
  final PanelOrientation orientation;
  final double? surfaceM2;      // Optional total surface
  final DateTime installDate;
  final DateTime createdAt;

  const InstallationPV({
    this.id,
    required this.userId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.powerKW,
    required this.numPanels,
    required this.panelType,
    required this.tiltAngle,
    required this.orientation,
    this.surfaceM2,
    required this.installDate,
    required this.createdAt,
  });

  // ── Firestore serialization ────────────────────────────────────────────────

  Map<String, dynamic> toFirestore() => {
    'userId':      userId,
    'name':        name,
    'latitude':    latitude,
    'longitude':   longitude,
    'powerKW':     powerKW,
    'numPanels':   numPanels,
    'panelType':   panelType.name,
    'tiltAngle':   tiltAngle,
    'orientation': orientation.name,
    'surfaceM2':   surfaceM2,
    'installDate': Timestamp.fromDate(installDate),
    'createdAt':   Timestamp.fromDate(createdAt),
  };

  factory InstallationPV.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InstallationPV(
      id:          doc.id,
      userId:      data['userId'] as String? ?? '',
      name:        data['name'] as String? ?? 'Mon Installation',
      latitude:    (data['latitude'] as num?)?.toDouble() ?? 36.8,
      longitude:   (data['longitude'] as num?)?.toDouble() ?? 10.18,
      powerKW:     (data['powerKW'] as num?)?.toDouble() ?? 1.0,
      numPanels:   (data['numPanels'] as num?)?.toInt() ?? 1,
      panelType:   PanelType.fromString(data['panelType'] as String? ?? ''),
      tiltAngle:   (data['tiltAngle'] as num?)?.toDouble() ?? 30.0,
      orientation: PanelOrientation.fromString(data['orientation'] as String? ?? ''),
      surfaceM2:   (data['surfaceM2'] as num?)?.toDouble(),
      installDate: (data['installDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt:   (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  InstallationPV copyWith({
    String? name,
    double? latitude,
    double? longitude,
    double? powerKW,
    int? numPanels,
    PanelType? panelType,
    double? tiltAngle,
    PanelOrientation? orientation,
    double? surfaceM2,
    DateTime? installDate,
  }) =>
      InstallationPV(
        id:          id,
        userId:      userId,
        name:        name        ?? this.name,
        latitude:    latitude    ?? this.latitude,
        longitude:   longitude   ?? this.longitude,
        powerKW:     powerKW     ?? this.powerKW,
        numPanels:   numPanels   ?? this.numPanels,
        panelType:   panelType   ?? this.panelType,
        tiltAngle:   tiltAngle   ?? this.tiltAngle,
        orientation: orientation ?? this.orientation,
        surfaceM2:   surfaceM2   ?? this.surfaceM2,
        installDate: installDate ?? this.installDate,
        createdAt:   createdAt,
      );
}
