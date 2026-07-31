import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../models/installation_pv.dart';
import '../providers/installation_provider.dart';
import '../providers/auth_provider.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import 'map_picker_screen.dart';

/// Multi-step form to collect PV installation info.
/// Used both after signup and from Settings (edit mode).
class PVSetupScreen extends StatefulWidget {
  final String userId;
  final InstallationPV? existing; // non-null when editing

  const PVSetupScreen({super.key, required this.userId, this.existing});

  @override
  State<PVSetupScreen> createState() => _PVSetupScreenState();
}

class _PVSetupScreenState extends State<PVSetupScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // ── Step 1 controllers ─────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _latCtrl  = TextEditingController();
  final _lngCtrl  = TextEditingController();
  String _addressLabel = 'Appuyez pour détecter votre position';

  // ── Step 2 controllers ─────────────────────────────────────────────────────
  final _powerCtrl  = TextEditingController();
  final _panelsCtrl = TextEditingController();
  PanelType _panelType  = PanelType.monocrystallin;
  DateTime  _installDate = DateTime.now().subtract(const Duration(days: 30));

  // ── Step 3 values ──────────────────────────────────────────────────────────
  double           _tiltAngle   = 30.0;
  PanelOrientation _orientation = PanelOrientation.sud;
  final _surfaceCtrl = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      _nameCtrl.text   = ex.name;
      _latCtrl.text    = ex.latitude.toString();
      _lngCtrl.text    = ex.longitude.toString();
      _powerCtrl.text  = ex.powerKW.toString();
      _panelsCtrl.text = ex.numPanels.toString();
      _panelType       = ex.panelType;
      _installDate     = ex.installDate;
      _tiltAngle       = ex.tiltAngle;
      _orientation     = ex.orientation;
      _surfaceCtrl.text = ex.surfaceM2?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose(); _latCtrl.dispose(); _lngCtrl.dispose();
    _powerCtrl.dispose(); _panelsCtrl.dispose(); _surfaceCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  void _next() {
    if (_currentStep == 0 && !_validateStep1()) return;
    if (_currentStep == 1 && !_validateStep2()) return;
    if (_currentStep == 2) { 
      if (!_validateStep3()) return;
      _save(); 
      return; 
    }

    setState(() => _currentStep++);
    _pageController.animateToPage(_currentStep, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
  }

  void _back() {
    if (_currentStep == 0) return;
    setState(() => _currentStep--);
    _pageController.animateToPage(_currentStep, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
  }

  // ── Validation ─────────────────────────────────────────────────────────────
  bool _validateStep1() {
    if (_nameCtrl.text.trim().isEmpty) { _snack('Veuillez entrer un nom pour l\'installation'); return false; }
    final latStr = _latCtrl.text.replaceAll(',', '.');
    final lngStr = _lngCtrl.text.replaceAll(',', '.');
    final lat = double.tryParse(latStr);
    final lng = double.tryParse(lngStr);
    if (lat == null || lat < -90 || lat > 90) { _snack('Latitude invalide (entre -90 et 90)'); return false; }
    if (lng == null || lng < -180 || lng > 180) { _snack('Longitude invalide (entre -180 et 180)'); return false; }
    return true;
  }

  bool _validateStep2() {
    final powerStr = _powerCtrl.text.replaceAll(',', '.');
    final p = double.tryParse(powerStr);
    if (p == null || p <= 0) { _snack('Puissance installée invalide (doit être > 0)'); return false; }
    final n = int.tryParse(_panelsCtrl.text);
    if (n == null || n <= 0) { _snack('Nombre de panneaux invalide (doit être >= 1)'); return false; }
    return true;
  }

  bool _validateStep3() {
    final surfStr = _surfaceCtrl.text.replaceAll(',', '.');
    if (surfStr.isNotEmpty) {
      final s = double.tryParse(surfStr);
      if (s == null || s <= 0) {
        _snack('Surface totale invalide (doit être un nombre positif)');
        return false;
      }
    }
    return true;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Save ────────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    setState(() => _isSaving = true);
    
    // 1. Capture du contexte (Navigator et ScaffoldMessenger) AVANT l'opération asynchrone
    // Mettre en cache ces variables évite l'écran rouge (Crash "BuildContext invalide"
    // ou "Looking up a deactivated widget's ancestor is unsafe") qui survient si AuthGate
    // ou Navigator détruit cette page pendant que l'opération asynchrone tourne en arrière-plan.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    
    try {
      final latStr = _latCtrl.text.replaceAll(',', '.');
      final lngStr = _lngCtrl.text.replaceAll(',', '.');
      final powerStr = _powerCtrl.text.replaceAll(',', '.');
      final surfStr = _surfaceCtrl.text.replaceAll(',', '.');

      final authProvider = context.read<AuthProvider>();
      final currentUid = authProvider.user?.uid;

      if (currentUid == null) {
        messenger.showSnackBar(const SnackBar(content: Text('Session expirée. Veuillez vous reconnecter.'), backgroundColor: Colors.redAccent));
        return;
      }

      final installation = InstallationPV(
        id:          widget.existing?.id,
        userId:      currentUid, // Use the actual authenticated UID to prevent mismatches
        name:        _nameCtrl.text.trim(),
        latitude:    double.parse(latStr),
        longitude:   double.parse(lngStr),
        powerKW:     double.parse(powerStr),
        numPanels:   int.parse(_panelsCtrl.text),
        panelType:   _panelType,
        tiltAngle:   _tiltAngle,
        orientation: _orientation,
        surfaceM2:   surfStr.isEmpty ? null : double.tryParse(surfStr),
        installDate: _installDate,
        createdAt:   widget.existing?.createdAt ?? DateTime.now(),
      );

      final instProvider = Provider.of<InstallationProvider>(context, listen: false);
      final ok = await instProvider.saveInstallation(installation);

      if (ok) {
        messenger.showSnackBar(const SnackBar(content: Text('Installation sauvegardée avec succès !')));
        
        // Navigation sécurisée
        if (widget.existing != null) {
          // Mode modification (Settings) : on revient en arrière
          navigator.pop();
        } else {
          // Mode création : L'application utilise AuthGate pour rediriger automatiquement.
        }
      } else {
        // Show specific error from provider if available, otherwise fallback to generic message
        final errorMsg = instProvider.error ?? 'Erreur de sauvegarde. Vérifiez votre connexion.';
        messenger.showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.redAccent));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur lors de la sauvegarde: $e'), backgroundColor: Colors.redAccent));
    } finally {
      // 2. Toujours utiliser mounted pour éviter le "setState après dispose"
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // ── Location helpers ───────────────────────────────────────────────────────
  Future<void> _gpsLocate() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null) {
        _latCtrl.text = pos.latitude.toStringAsFixed(5);
        _lngCtrl.text = pos.longitude.toStringAsFixed(5);
        _fetchAddress(pos.latitude, pos.longitude);
      }
    } catch (e) { 
      messenger.showSnackBar(SnackBar(content: Text(e.toString()))); 
    }
  }

  Future<void> _pickOnMap() async {
    final lat = double.tryParse(_latCtrl.text) ?? 36.8;
    final lng = double.tryParse(_lngCtrl.text) ?? 10.18;
    final LatLng? result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MapPickerScreen(initialLat: lat, initialLng: lng)),
    );
    if (result != null) {
      _latCtrl.text = result.latitude.toStringAsFixed(5);
      _lngCtrl.text = result.longitude.toStringAsFixed(5);
      _fetchAddress(result.latitude, result.longitude);
    }
  }

  Future<void> _fetchAddress(double lat, double lng) async {
    setState(() => _addressLabel = 'Recherche...');
    final addr = await LocationService.getAddressFromLatLng(lat, lng);
    if (mounted) setState(() => _addressLabel = addr);
  }

  // ── UI ──────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      appBar: isEdit
          ? AppBar(backgroundColor: AppTheme.bgDeep, title: const Text('Modifier l\'installation'))
          : null,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                children: [
                  if (!isEdit) ...[
                    const Icon(Icons.wb_sunny_rounded, color: AppTheme.primaryYellow, size: 40),
                    const SizedBox(height: 10),
                    const Text('PV MONITOR', style: TextStyle(color: AppTheme.primaryYellow, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 3)),
                    const SizedBox(height: 20),
                  ],
                  Text(
                    isEdit ? 'Modifier votre installation' : 'Configurer votre installation',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  const Text('Étape par étape — toutes les données sont importantes', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 20),

                  // ── Step indicator ────────────────────────────────────────
                  Row(
                    children: List.generate(3, (i) {
                      final done    = i < _currentStep;
                      final active  = i == _currentStep;
                      return Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                height: 4,
                                decoration: BoxDecoration(
                                  color: done || active ? AppTheme.primaryYellow : Colors.white12,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            if (i < 2) const SizedBox(width: 4),
                          ],
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _stepLabel('Localisation', 0),
                      _stepLabel('Technique', 1),
                      _stepLabel('Disposition', 2),
                    ],
                  ),
                ],
              ),
            ),

            // ── Pages ────────────────────────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                ],
              ),
            ),

            // ── Nav buttons ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: _back,
                        child: const Text('Retour'),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _next,
                      child: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54))
                          : Text(_currentStep == 2 ? (isEdit ? 'Enregistrer' : 'Terminer & Accéder') : 'Continuer →'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepLabel(String text, int index) {
    final active = index == _currentStep;
    final done   = index < _currentStep;
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: active ? FontWeight.bold : FontWeight.normal,
        color: active ? AppTheme.primaryYellow : (done ? AppTheme.textSecondary : AppTheme.textMuted),
      ),
    );
  }

  // ── STEP 1: Identification & Localisation ─────────────────────────────────
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _card(
            title: '📋 Identification',
            child: _glassField(ctrl: _nameCtrl, label: 'Nom de l\'installation', hint: 'Ex: Maison Principale', icon: Icons.home_outlined),
          ),
          const SizedBox(height: 16),
          _card(
            title: '📍 Localisation',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _glassField(ctrl: _latCtrl, label: 'Latitude', hint: '36.8065', icon: Icons.location_on_outlined, keyboard: const TextInputType.numberWithOptions(decimal: true, signed: true))),
                    const SizedBox(width: 10),
                    Expanded(child: _glassField(ctrl: _lngCtrl, label: 'Longitude', hint: '10.1815', icon: Icons.location_on_outlined, keyboard: const TextInputType.numberWithOptions(decimal: true, signed: true))),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.place_outlined, color: AppTheme.textMuted, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_addressLabel, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontStyle: FontStyle.italic))),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _gpsLocate,
                        icon: const Icon(Icons.gps_fixed, size: 16),
                        label: const Text('GPS'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickOnMap,
                        icon: const Icon(Icons.map_outlined, size: 16),
                        label: const Text('Sur Carte'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── STEP 2: Technical specs ───────────────────────────────────────────────
  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _card(
            title: '⚡ Caractéristiques Techniques',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _glassField(ctrl: _powerCtrl, label: 'Puissance (kWp)', hint: '3.0', icon: Icons.bolt, keyboard: const TextInputType.numberWithOptions(decimal: true))),
                    const SizedBox(width: 10),
                    Expanded(child: _glassField(ctrl: _panelsCtrl, label: 'Nb Panneaux', hint: '10', icon: Icons.grid_view, keyboard: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 16),
                _label('Type de panneaux'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: PanelType.values.map((type) {
                    final selected = _panelType == type;
                    return GestureDetector(
                      onTap: () => setState(() => _panelType = type),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? AppTheme.primaryYellow : Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: selected ? AppTheme.primaryYellow : Colors.white24),
                        ),
                        child: Text(
                          type.label,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? AppTheme.bgDeep : AppTheme.textSecondary),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _card(
            title: '📅 Date d\'installation',
            child: GestureDetector(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _installDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                  builder: (ctx, child) => Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(primary: AppTheme.primaryYellow, surface: AppTheme.bgCard),
                    ),
                    child: child!,
                  ),
                );
                if (date != null) setState(() => _installDate = date);
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.07), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white24)),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: AppTheme.primaryYellow, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      '${_installDate.day.toString().padLeft(2, '0')} / ${_installDate.month.toString().padLeft(2, '0')} / ${_installDate.year}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down, color: AppTheme.textMuted),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── STEP 3: Disposition ────────────────────────────────────────────────────
  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _card(
            title: '📐 Inclinaison',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Angle', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: AppTheme.primaryYellowDim, borderRadius: BorderRadius.circular(8)),
                      child: Text('${_tiltAngle.round()}°', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryYellow, fontSize: 16)),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppTheme.primaryYellow,
                    inactiveTrackColor: Colors.white12,
                    thumbColor: AppTheme.primaryYellow,
                    overlayColor: AppTheme.primaryYellowDim,
                    trackHeight: 4,
                  ),
                  child: Slider(
                    min: 0, max: 90,
                    divisions: 90,
                    value: _tiltAngle,
                    onChanged: (v) => setState(() => _tiltAngle = v),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('0° (Horizontal)', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                    const Text('90° (Vertical)', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _card(
            title: '🧭 Orientation (Azimut)',
            child: Wrap(
              spacing: 8, runSpacing: 8,
              children: PanelOrientation.values.map((o) {
                final sel = _orientation == o;
                return GestureDetector(
                  onTap: () => setState(() => _orientation = o),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? AppTheme.primaryYellow : Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? AppTheme.primaryYellow : Colors.white24),
                    ),
                    child: Text(
                      o.label,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? AppTheme.bgDeep : AppTheme.textSecondary),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          _card(
            title: '📏 Surface totale (optionnel)',
            child: _glassField(ctrl: _surfaceCtrl, label: 'Surface en m²', hint: '16.5', icon: Icons.square_foot, keyboard: const TextInputType.numberWithOptions(decimal: true)),
          ),
          const SizedBox(height: 8),

          // Summary preview
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryYellowDim,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryYellow.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: AppTheme.primaryYellow),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Prêt à enregistrer ! Vérifiez vos données puis validez votre installation.',
                    style: TextStyle(color: AppTheme.primaryYellow, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared widget helpers ──────────────────────────────────────────────────
  Widget _card({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.glassWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _label(String t) => Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary));

  Widget _glassField({required TextEditingController ctrl, required String label, required String hint, required IconData icon, TextInputType? keyboard}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.07), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white24)),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
          hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
          prefixIcon: Icon(icon, color: Colors.white38, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }
}
