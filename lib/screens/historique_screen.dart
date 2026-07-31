import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/mesure_model.dart';
import '../services/mesure_service.dart';
import '../providers/installation_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';

class HistoriqueScreen extends StatefulWidget {
  const HistoriqueScreen({super.key});

  @override
  State<HistoriqueScreen> createState() => _HistoriqueScreenState();
}

class _HistoriqueScreenState extends State<HistoriqueScreen> {
  final MesureService _mesureService = MesureService();

  DateTime _selectedDate = DateTime.now();
  int _currentPeriodIndex = 0; // 0: JOUR, 1: MOIS, 2: ANNÉE

  // ── Stream temps réel (remplace le Future) ─────────────────────────────────
  Stream<List<MesureAgregee>>? _dataStream;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    // Post-frame pour que context.read soit disponible
    WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildStream());
  }

  /// Recrée le stream Firestore à chaque changement de date / période.
  /// Firestore envoie les mises à jour automatiquement via snapshots().
  void _rebuildStream() {
    final auth = context.read<AuthProvider>();
    final installation = context.read<InstallationProvider>().installation;
    final user = auth.user;

    if (user == null || installation?.id == null) {
      debugPrint('[HistoriqueScreen] ⚠️ User ou installation manquants.');
      return;
    }

    final userId = user.uid;
    final instId = installation!.id!;

    Stream<List<MesureAgregee>> newStream;

    if (_currentPeriodIndex == 0) {
      newStream = _mesureService.streamAggregatedDataByHour(userId, instId, _selectedDate);
    } else if (_currentPeriodIndex == 1) {
      newStream = _mesureService.streamAggregatedDataByDay(userId, instId, _selectedDate);
    } else {
      newStream = _mesureService.streamAggregatedDataByMonth(userId, instId, _selectedDate);
    }

    setState(() {
      _dataStream = newStream;
    });

    debugPrint('[HistoriqueScreen] 🔄 Stream Firestore recréé — période: $_currentPeriodIndex, date: $_selectedDate');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'HISTORIQUE',
          style: TextStyle(
            color: AppTheme.primaryYellow,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── SÉLECTEUR DE PÉRIODE ──────────────────────────────────────────
            _buildPeriodSelector(),

            // ── CALENDRIER (Visible uniquement en mode JOUR ou MOIS) ─────────
            if (_currentPeriodIndex < 2) _buildCalendar(),

            const SizedBox(height: 10),

            // ── StreamBuilder unique : alimente RÉSUMÉ + TABLEAU ─────────────
            StreamBuilder<List<MesureAgregee>>(
              stream: _dataStream ?? const Stream.empty(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint('[HistoriqueScreen] ❌ Erreur stream: ${snapshot.error}');
                  return Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Text(
                        'Erreur Firestore : ${snapshot.error}',
                        style: const TextStyle(color: AppTheme.accentRed, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final isLoading = snapshot.connectionState == ConnectionState.waiting;
                final data = snapshot.data ?? [];

                // Totaux
                double totalProd = 0, totalProdDC = 0, totalCons = 0;
                for (final m in data) {
                  totalProd += m.productionTotale;
                  totalProdDC += m.productionDCTotale;
                  totalCons += m.consommationTotale;
                }

                return Column(
                  children: [
                    // ── RÉSUMÉ ─────────────────────────────────────────────
                    _buildSummarySection(
                      isLoading: isLoading,
                      totalProd: totalProd,
                      totalProdDC: totalProdDC,
                      totalCons: totalCons,
                    ),

                    // ── TABLEAU ────────────────────────────────────────────
                    _buildDataTable(isLoading: isLoading, data: data),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────────────

  Widget _buildPeriodSelector() {
    final periods = ['JOUR', 'MOIS', 'ANNÉE'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: Row(
        children: List.generate(periods.length, (index) {
          final isSelected = _currentPeriodIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _currentPeriodIndex = index);
                _rebuildStream();
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryYellow : AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryYellow : Colors.white12,
                  ),
                ),
                child: Text(
                  periods[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.black87 : AppTheme.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.now(),
        focusedDay: _selectedDate,
        calendarFormat: _calendarFormat,
        startingDayOfWeek: StartingDayOfWeek.monday,
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(color: AppTheme.primaryYellow, fontWeight: FontWeight.bold),
          leftChevronIcon: Icon(Icons.chevron_left, color: AppTheme.primaryYellow),
          rightChevronIcon: Icon(Icons.chevron_right, color: AppTheme.primaryYellow),
        ),
        calendarStyle: const CalendarStyle(
          defaultTextStyle: TextStyle(color: Colors.white70),
          weekendTextStyle: TextStyle(color: Colors.white38),
          selectedDecoration: BoxDecoration(color: AppTheme.primaryYellow, shape: BoxShape.circle),
          todayDecoration: BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
        ),
        selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() => _selectedDate = selectedDay);
          _rebuildStream();
        },
      ),
    );
  }

  Widget _buildSummarySection({
    required bool isLoading,
    required double totalProd,
    required double totalProdDC,
    required double totalCons,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              _buildSummaryCard("Production DC", isLoading ? null : totalProdDC, "kW", Icons.solar_power_rounded, Colors.amber),
              const SizedBox(width: 12),
              _buildSummaryCard("Production AC", isLoading ? null : totalProd, "kW", Icons.wb_sunny_rounded, Colors.orange),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSummaryCard("Consommation AC", isLoading ? null : totalCons, "kW", Icons.bolt_rounded, AppTheme.primaryYellow),
              const SizedBox(width: 12),
              _buildSummaryCard(
                "Bilan Net",
                isLoading ? null : (totalProd - totalCons),
                "kW",
                Icons.account_balance_wallet_rounded,
                isLoading ? Colors.grey : ((totalProd - totalCons) >= 0 ? Colors.green : Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, double? value, String unit, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            value == null
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryYellow))
                : Text(
                    "${FormatUtils.formatPowerValue(value)} $unit",
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable({required bool isLoading, required List<MesureAgregee> data}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: isLoading
          ? const Padding(
              padding: EdgeInsets.all(40.0),
              child: Center(child: CircularProgressIndicator(color: AppTheme.primaryYellow)),
            )
          : data.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Center(
                    child: Text("Aucune donnée enregistrée", style: TextStyle(color: AppTheme.textMuted)),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
                      child: Row(
                        children: const [
                          Expanded(flex: 3, child: Text("PÉRIODE", style: TextStyle(color: AppTheme.primaryYellow, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1))),
                          Expanded(flex: 2, child: Text("DC", textAlign: TextAlign.right, style: TextStyle(color: AppTheme.primaryYellow, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1))),
                          Expanded(flex: 2, child: Text("AC", textAlign: TextAlign.right, style: TextStyle(color: AppTheme.primaryYellow, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1))),
                          Expanded(flex: 2, child: Text("CONS", textAlign: TextAlign.right, style: TextStyle(color: AppTheme.primaryYellow, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1))),
                          Expanded(flex: 2, child: Text("NET", textAlign: TextAlign.right, style: TextStyle(color: AppTheme.primaryYellow, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1))),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(15),
                      itemCount: data.length,
                      separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (context, index) {
                        final item = data[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Expanded(flex: 3, child: Text(item.periodeLabel, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))),
                              Expanded(flex: 2, child: Text(FormatUtils.formatPowerValue(item.productionDCTotale), textAlign: TextAlign.right, style: const TextStyle(color: Colors.amber, fontSize: 11))),
                              Expanded(flex: 2, child: Text(FormatUtils.formatPowerValue(item.productionTotale), textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontSize: 11))),
                              Expanded(flex: 2, child: Text(FormatUtils.formatPowerValue(item.consommationTotale), textAlign: TextAlign.right, style: const TextStyle(color: AppTheme.accentRed, fontSize: 11))),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  FormatUtils.formatPowerValue(item.bilantNet),
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: item.bilantNet >= 0 ? Colors.greenAccent : Colors.redAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
    );
  }
}
