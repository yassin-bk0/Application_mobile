import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/mesure_model.dart';
import '../services/mesure_service.dart';
import '../providers/installation_provider.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // 0: JOUR, 1: MOIS, 2: ANNÉE
  int _selectedPeriod = 0;
  
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  final MesureService _mesureService = MesureService();
  Future<List<MesureAgregee>>? _dataFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final provider = Provider.of<InstallationProvider>(context, listen: false);
    // On utilise l'ID de l'installation et de l'utilisateur
    final installationId = provider.installation?.id ?? 'test_installation';
    final userId = provider.installation?.userId ?? 'test_user';

    setState(() {
      if (_selectedPeriod == 0) {
        _dataFuture = _mesureService.getAggregatedDataByHour(userId, installationId, _selectedDay);
      } else if (_selectedPeriod == 1) {
        _dataFuture = _mesureService.getAggregatedDataByDay(userId, installationId, _selectedDay);
      } else if (_selectedPeriod == 2) {
        _dataFuture = _mesureService.getAggregatedDataByMonth(userId, installationId, _selectedDay);
      }
    });
  }

  // --- BUILDERS WIDGETS ---

  Widget _buildTopTab(String title, int periodIndex) {
    final bool isSelected = _selectedPeriod == periodIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPeriod = periodIndex;
            _loadData();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryYellow : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? AppTheme.bgDeep : AppTheme.textMuted,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.glassWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      padding: const EdgeInsets.only(bottom: 10),
      child: TableCalendar(
        locale: 'fr',
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.now().add(const Duration(days: 365)),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay; 
            _loadData();
          });
        },
        calendarStyle: CalendarStyle(
          selectedDecoration: const BoxDecoration(
            color: AppTheme.primaryYellow,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: AppTheme.primaryYellow.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          defaultTextStyle: const TextStyle(color: AppTheme.textPrimary),
          weekendTextStyle: const TextStyle(color: AppTheme.textSecondary),
          outsideTextStyle: const TextStyle(color: Colors.white12),
        ),
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
          leftChevronIcon: Icon(Icons.chevron_left, color: AppTheme.textSecondary),
          rightChevronIcon: Icon(Icons.chevron_right, color: AppTheme.textSecondary),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 12),
          weekendStyle: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.glassWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
             Icon(icon, size: 14, color: AppTheme.primaryYellow),
             const SizedBox(width: 8),
             Expanded(
               child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                 overflow: TextOverflow.ellipsis,
               ),
             ),
          ]),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String timeHeader = 'HEURE';
    if (_selectedPeriod == 1) timeHeader = 'DATE';
    if (_selectedPeriod == 2) timeHeader = 'MOIS';

    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDeep,
        title: const Text('Historique'),
        actions: [
          GestureDetector(
             onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export en cours...')));
             },
             child: Container(
                margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                   color: AppTheme.primaryYellowDim,
                   borderRadius: BorderRadius.circular(10),
                   border: Border.all(color: AppTheme.primaryYellow.withOpacity(0.4)),
                ),
                child: Row(
                   children: const [
                      Icon(Icons.download, size: 16, color: AppTheme.primaryYellow),
                      SizedBox(width: 6),
                      Text('Exporter', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryYellow, fontSize: 13)),
                   ],
                ),
             ),
          ),
        ],
      ),
      body: FutureBuilder<List<MesureAgregee>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          bool isLoading = snapshot.connectionState == ConnectionState.waiting;
          bool hasError = snapshot.hasError;
          List<MesureAgregee> data = snapshot.data ?? [];

          // Calcul des KPI
          double totalProduction = 0.0;
          double totalConsumption = 0.0;
          
          if (!isLoading && !hasError && data.isNotEmpty) {
            for (final dp in data) {
              totalProduction += dp.productionTotale;
              totalConsumption += dp.consommationTotale;
            }
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              // Sélecteur de période
              Container(
                 padding: const EdgeInsets.all(4),
                 decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                 ),
                 child: Row(children: [
                    _buildTopTab('JOUR', 0),
                    _buildTopTab('MOIS', 1),
                    _buildTopTab('ANNÉE', 2),
                 ]),
              ),
              const SizedBox(height: 20),

              // Calendrier
              _buildCalendarCard(),
              const SizedBox(height: 20),

              // Cartes de Résumé
              Row(
                 children: [
                    Expanded(child: _buildSummaryCard(Icons.flash_on, 'Prod. totale', '${totalProduction.toStringAsFixed(1)} kWh')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildSummaryCard(Icons.power_outlined, 'Cons. totale', '${totalConsumption.toStringAsFixed(1)} kWh')),
                 ],
              ),
              const SizedBox(height: 24),

              // Titre du tableau
              Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                    const Text('Détails des mesures', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    if (!isLoading && !hasError)
                      Container(
                         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                         decoration: BoxDecoration(
                            color: AppTheme.glassWhite,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.glassBorder),
                         ),
                         child: Text('${data.length} résultats', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryYellow)),
                      ),
                 ],
              ),
              const SizedBox(height: 14),

              // Contenu du tableau ou Loading/Error state
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator(color: AppTheme.primaryYellow)),
                )
              else if (hasError)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text('Erreur de chargement: ${snapshot.error}', style: const TextStyle(color: AppTheme.accentRed)),
                  ),
                )
              else if (data.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(color: AppTheme.glassWhite, borderRadius: BorderRadius.circular(20)),
                  child: const Center(child: Text("Aucune donnée disponible", style: TextStyle(color: AppTheme.textSecondary))),
                )
              else
                Container(
                   decoration: BoxDecoration(
                      color: AppTheme.glassWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.glassBorder),
                   ),
                   clipBehavior: Clip.hardEdge,
                   child: SingleChildScrollView(
                     scrollDirection: Axis.horizontal,
                     child: Theme(
                       data: Theme.of(context).copyWith(
                          dividerColor: Colors.white.withOpacity(0.05),
                       ),
                       child: DataTable(
                         columnSpacing: 35,
                         dataRowMinHeight: 48,
                         dataRowMaxHeight: 48,
                         headingRowHeight: 40,
                         columns: [
                           DataColumn(label: Text(timeHeader, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted))),
                           const DataColumn(label: Text('PROD (kWh)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted))),
                           const DataColumn(label: Text('CONS (kWh)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted))),
                         ],
                         rows: data.map((item) {
                           return DataRow(
                             cells: [
                               DataCell(Text(item.periodeLabel, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary, fontSize: 13))),
                               DataCell(Text(item.productionTotale.toStringAsFixed(2), style: const TextStyle(color: AppTheme.accentGreen, fontSize: 13, fontWeight: FontWeight.bold))),
                               DataCell(Text(item.consommationTotale.toStringAsFixed(2), style: const TextStyle(color: AppTheme.accentRed, fontSize: 13, fontWeight: FontWeight.bold))),
                             ]
                           );
                         }).toList(),
                       ),
                     ),
                   ),
                ),
            ],
          );
        }
      ),
    );
  }
}
