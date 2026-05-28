import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../data/local/entities/daily_log_entity.dart';
import '../../domain/models.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedWaterMl = 250; // Quantità di acqua selezionata di default (ml)

  String _formatSelectedDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));
    
    final cleanDate = DateTime(date.year, date.month, date.day);
    
    if (cleanDate == today) return 'Oggi';
    if (cleanDate == yesterday) return 'Ieri';
    if (cleanDate == tomorrow) return 'Domani';
    
    final weekdays = ['Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'];
    final months = [
      'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
      'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'
    ];
    
    return '${weekdays[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
  }

  // Mostra il foglio modale con le opzioni di aggiunta
  void _showAddMealOptions(BuildContext context, String defaultMeal) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16161D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return AddMealOptionsSheet(defaultMeal: defaultMeal);
      },
    );
  }

  // Dialogo modifica quantità alimento già inserito
  void _showEditQuantityDialog(
    BuildContext context,
    AppState appState,
    String mealName,
    int itemIndex,
    MealItemEntity item,
  ) {
    double amount = item.amountGrams;
    final textController = TextEditingController(text: item.amountGrams.toInt().toString());

    const accentCyan = Color(0xFF00FFC2);
    const accentPink = Color(0xFFFF007F);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final cal = (item.caloriesPer100g * amount) / 100;
          final prot = (item.proteinsPer100g * amount) / 100;
          final carbs = (item.carbsPer100g * amount) / 100;
          final fats = (item.fatsPer100g * amount) / 100;
          final fibers = (item.fibersPer100g * amount) / 100;

          return AlertDialog(
            backgroundColor: const Color(0xFF16161D),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.edit, color: accentCyan, size: 18),
                    const SizedBox(width: 8),
                    const Text('Modifica quantità', style: TextStyle(color: Colors.white54, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.foodName ?? 'Alimento',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: textController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    decoration: InputDecoration(
                      labelText: 'Quantità (g)',
                      labelStyle: const TextStyle(color: Colors.white60),
                      suffixText: 'g',
                      suffixStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.04),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                    onChanged: (val) => setDialogState(() => amount = double.tryParse(val) ?? 0.0),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    children: [30, 50, 100, 150, 200, 250].map((g) => ActionChip(
                      label: Text('${g}g', style: const TextStyle(color: Colors.white, fontSize: 11)),
                      backgroundColor: Colors.white.withOpacity(0.06),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        textController.text = g.toString();
                        setDialogState(() => amount = g.toDouble());
                      },
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Valori calcolati:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 8),
                  _buildEditMacroRow('Calorie', '${cal.toStringAsFixed(1)} kcal', accentCyan),
                  _buildEditMacroRow('Proteine', '${prot.toStringAsFixed(1)} g', accentPink),
                  _buildEditMacroRow('Carbs', '${carbs.toStringAsFixed(1)} g', const Color(0xFFFFD700)),
                  _buildEditMacroRow('Grassi', '${fats.toStringAsFixed(1)} g', const Color(0xFF00E676)),
                  _buildEditMacroRow('Fibre', '${fibers.toStringAsFixed(1)} g', Colors.cyan),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.all(16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annulla', style: TextStyle(color: Colors.white38)),
              ),
              ElevatedButton(
                onPressed: amount <= 0 ? null : () {
                  appState.updateMealItemAmount(mealName, itemIndex, amount);
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentCyan,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Salva', style: TextStyle(color: Color(0xFF0F0F13), fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEditMacroRow(String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ],
          ),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.currentUser;
    final currentDay = appState.currentDayLog;

    if (user == null || currentDay == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F13),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00FFC2)),
        ),
      );
    }

    // Colori Neon Premium
    const accentCyan = Color(0xFF00FFC2);
    const accentPink = Color(0xFFFF007F);
    const accentYellow = Color(0xFFFFD700);
    const accentGreen = Color(0xFF00E676);

    // Calcoli Macro e Calorie
    final double calGoal = user.goalCalories;
    final double currentCal = appState.currentCalories;
    final double calProgress = (calGoal > 0) ? (currentCal / calGoal).clamp(0.0, 1.0) : 0.0;

    final double proteinGoal = user.goalProteins;
    final double currentProt = appState.currentProteins;
    final double proteinProgress = (proteinGoal > 0) ? (currentProt / proteinGoal).clamp(0.0, 1.0) : 0.0;

    final double carbGoal = user.goalCarbs;
    final double currentCarb = appState.currentCarbs;
    final double carbProgress = (carbGoal > 0) ? (currentCarb / carbGoal).clamp(0.0, 1.0) : 0.0;

    final double fatGoal = user.goalFats;
    final double currentFat = appState.currentFats;
    final double fatProgress = (fatGoal > 0) ? (currentFat / fatGoal).clamp(0.0, 1.0) : 0.0;

    final double fiberGoal = user.goalFibers;
    final double currentFib = appState.currentFibers;
    final double fiberProgress = (fiberGoal > 0) ? (currentFib / fiberGoal).clamp(0.0, 1.0) : 0.0;

    final trackingMode = user.trackingMode;

    // Statistiche Settimanali 80/20
    final stats = appState.weeklyStats;
    final int trackedDaysCount = stats.trackedDays.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'k',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: 0,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: accentCyan.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Cali',
                style: TextStyle(
                  color: accentCyan,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Selettore Data Premium (Glassmorphic)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: accentCyan, size: 20),
                    onPressed: () => appState.previousDay(),
                  ),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: appState.selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: accentCyan,
                                onPrimary: Colors.black,
                                surface: Color(0xFF16161D),
                                onSurface: Colors.white,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        appState.setSelectedDate(picked);
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_rounded, color: accentCyan, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _formatSelectedDate(appState.selectedDate),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (appState.selectedDate.isAfter(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: accentYellow.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: accentYellow.withOpacity(0.3)),
                            ),
                            child: const Text(
                              'PIANIFICAZIONE',
                              style: TextStyle(
                                color: accentYellow,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios_rounded, color: accentCyan, size: 20),
                    onPressed: () => appState.nextDay(),
                  ),
                ],
              ),
            ),

            // 80/20 Cheat Day Toggle (Elegante Glassmorphic Card)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: currentDay.isTracked 
                    ? Colors.white.withOpacity(0.03)
                    : accentPink.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: currentDay.isTracked 
                      ? Colors.white.withOpacity(0.06)
                      : accentPink.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    currentDay.isTracked ? Icons.check_circle_outline : Icons.celebration,
                    color: currentDay.isTracked ? accentCyan : accentPink,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentDay.isTracked ? 'Giorno Tracciato' : 'Cheat Day / Giorno Libero',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          currentDay.isTracked 
                              ? 'I dati nutrizionali di oggi sono inclusi nelle medie settimanali.'
                              : 'Escluso dalle statistiche settimanali per la regola 80/20.',
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: currentDay.isTracked,
                    onChanged: (val) {
                      appState.toggleTrackedCurrentDay();
                    },
                    activeColor: accentCyan,
                    activeTrackColor: accentCyan.withOpacity(0.2),
                    inactiveThumbColor: accentPink,
                    inactiveTrackColor: accentPink.withOpacity(0.2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Cerchio Calorie & Macro Progress
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.02)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Circular indicator
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            height: 140,
                            width: 140,
                            child: CircularProgressIndicator(
                              value: calProgress,
                              strokeWidth: 10,
                              backgroundColor: Colors.white.withOpacity(0.05),
                              color: currentDay.isTracked ? accentCyan : accentPink,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${currentCal.toInt()}',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              const Text(
                                'kcal assunte',
                                style: TextStyle(fontSize: 11, color: Colors.white54),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '/ ${calGoal.toInt()} goal',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: currentDay.isTracked ? accentCyan : accentPink,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Side macro metrics quick overview
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildQuickMacroBadge('Proteine', currentProt, proteinGoal, accentCyan),
                          if (trackingMode != 'light') ...[
                            const SizedBox(height: 10),
                            _buildQuickMacroBadge('Carbo', currentCarb, carbGoal, accentYellow),
                            const SizedBox(height: 10),
                            _buildQuickMacroBadge('Grassi', currentFat, fatGoal, accentPink),
                          ],
                          if (trackingMode == 'custom') ...[
                            const SizedBox(height: 10),
                            _buildQuickMacroBadge('Fibre', currentFib, fiberGoal, accentGreen),
                          ],
                        ],
                      ),
                    ],
                  ),

                  // Linear Macro Progress Bars
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 10),
                  
                  // Proteine (Light, Standard, Custom)
                  _buildLinearMacroBar('Proteine', currentProt, proteinGoal, proteinProgress, accentCyan),
                  
                  if (trackingMode != 'light') ...[
                    const SizedBox(height: 12),
                    _buildLinearMacroBar('Carboidrati', currentCarb, carbGoal, carbProgress, accentYellow),
                    const SizedBox(height: 12),
                    _buildLinearMacroBar('Grassi', currentFat, fatGoal, fatProgress, accentPink),
                  ],

                  if (trackingMode == 'custom') ...[
                    const SizedBox(height: 12),
                    _buildLinearMacroBar('Fibre', currentFib, fiberGoal, fiberProgress, accentGreen),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sezione Diaristica Pasti
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Diario Alimentare',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAddMealOptions(context, 'Colazione'),
                  icon: const Icon(Icons.add_circle, color: accentCyan, size: 20),
                  label: const Text('Aggiungi', style: TextStyle(color: accentCyan, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            _buildMealSection(context, 'Colazione', currentDay.meals.firstWhere((m) => m.name == 'Colazione', orElse: () => MealEntity()), appState),
            _buildMealSection(context, 'Pranzo', currentDay.meals.firstWhere((m) => m.name == 'Pranzo', orElse: () => MealEntity()), appState),
            _buildMealSection(context, 'Cena', currentDay.meals.firstWhere((m) => m.name == 'Cena', orElse: () => MealEntity()), appState),
            _buildMealSection(context, 'Spuntini', currentDay.meals.firstWhere((m) => m.name == 'Spuntini', orElse: () => MealEntity()), appState),

            const SizedBox(height: 24),

            // Water Tracker (Polished Glassmorphism)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_drink, color: Colors.blueAccent, size: 28),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Idratazione',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              Text(
                                '${(currentDay.waterMl == 0 && currentDay.waterGlasses > 0) ? currentDay.waterGlasses * 250 : currentDay.waterMl} ml totali',
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.white54),
                            onPressed: () => appState.removeWaterMl(_selectedWaterMl),
                          ),
                          Text(
                            '${(currentDay.waterMl == 0 && currentDay.waterGlasses > 0) ? currentDay.waterGlasses * 250 : currentDay.waterMl}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle, color: Colors.blueAccent),
                            onPressed: () => appState.addWaterMl(_selectedWaterMl),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [100, 250, 500, 750].map((ml) {
                      final isSelected = _selectedWaterMl == ml;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: ChoiceChip(
                            label: Text('$ml ml'),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedWaterMl = ml;
                                });
                              }
                            },
                            selectedColor: Colors.blueAccent.withOpacity(0.3),
                            backgroundColor: Colors.white.withOpacity(0.03),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.white54,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Statistiche Settimanali 80/20 (Glassmorphic & Responsive Card)
            if (user.use8020Mode) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentCyan.withOpacity(0.08), accentPink.withOpacity(0.04)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Analisi Settimanale 80/20',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$trackedDaysCount/7 Giorni Tracciati',
                            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Media ultimi 7 giorni (escluso oggi). Le medie escludono i Cheat Days.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    if (!appState.hasEnoughDataForAverage) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.hourglass_empty, color: Colors.white38, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Dati insufficienti — registra almeno 7 giorni per vedere le medie.',
                                style: TextStyle(color: Colors.white38, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: _buildWeeklyStatBox(
                              'Calorie Medie',
                              '${stats.averageCalories.toInt()} kcal',
                              (stats.averageCalories <= user.goalCalories) ? accentCyan : accentPink,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildWeeklyStatBox(
                              'Proteine Medie',
                              '${stats.averageProteins.toInt()} g',
                              (stats.averageProteins >= user.goalProteins) ? accentCyan : accentYellow,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],

          ],
        ),
      ),
    );
  }

  Widget _buildQuickMacroBadge(String label, double current, double goal, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 5),
            Text(
              '${current.toInt()}g / ${goal.toInt()}g',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLinearMacroBar(String label, double current, double goal, double progress, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
            Text('${current.toInt()} / ${goal.toInt()} g', style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: Colors.white.withOpacity(0.05),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildMealSection(BuildContext context, String mealName, MealEntity meal, AppState appState) {
    final items = meal.items;
    final totalCalories = items.fold(0.0, (sum, item) => sum + ((item.caloriesPer100g * item.amountGrams) / 100));
    final hasItems = items.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(mealName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            Text(
              '${totalCalories.toInt()} kcal',
              style: const TextStyle(color: Color(0xFF00FFC2), fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
        subtitle: Text(
          hasItems ? '${items.length} alimenti inseriti' : 'Nessun alimento consumato',
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        leading: Icon(
          _getMealIcon(mealName),
          color: hasItems ? const Color(0xFFFF007F) : Colors.white30,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.add_circle_outline, color: Colors.white54),
          onPressed: () => _showAddMealOptions(context, mealName),
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          if (!hasItems)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Vuoi aggiungere alimenti a questo pasto?',
                style: TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final itemCal = (item.caloriesPer100g * item.amountGrams) / 100;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.foodName ?? 'Sconosciuto',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${item.amountGrams.toInt()}g - ${item.caloriesPer100g.toInt()} kcal/100g',
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '${itemCal.toInt()} kcal',
                            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Color(0xFF00FFC2), size: 16),
                            onPressed: () => _showEditQuantityDialog(context, appState, mealName, index, item),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.white38, size: 16),
                            onPressed: () => appState.removeMealItem(mealName, index),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
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

  IconData _getMealIcon(String name) {
    switch (name.toLowerCase()) {
      case 'colazione':
        return Icons.coffee;
      case 'pranzo':
        return Icons.restaurant;
      case 'cena':
        return Icons.dinner_dining;
      default:
        return Icons.apple;
    }
  }

  Widget _buildWeeklyStatBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// --- OPTION SHEET BOTTOM MODAL WIDGET ---

class AddMealOptionsSheet extends StatelessWidget {
  final String defaultMeal;

  const AddMealOptionsSheet({super.key, required this.defaultMeal});

  @override
  Widget build(BuildContext context) {
    const accentCyan = Color(0xFF00FFC2);
    const accentPink = Color(0xFFFF007F);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: const BoxDecoration(
          color: Color(0xFF16161D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Aggiungi Pasto a: $defaultMeal',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Option 1: Pasto Completo con IA
            _buildOptionCard(
              context: context,
              title: 'Pasto Completo con IA 🪄',
              description: 'Descrivi il pasto a parole tue e Gemini estrarrà automaticamente tutti gli alimenti, pesi e calorie!',
              color: accentCyan,
              icon: Icons.auto_awesome,
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => WholeMealAiDialog(defaultMeal: defaultMeal),
                );
              },
            ),
            const SizedBox(height: 16),

            // Option 2: Inserimento Manuale
            _buildOptionCard(
              context: context,
              title: 'Inserimento Avanzato 🛠️',
              description: 'Cerca cibi nel database OFF, scansiona codici a barre o inserisci alimenti personalizzati.',
              color: accentPink,
              icon: Icons.menu_book,
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/addMeal', arguments: defaultMeal);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required String title,
    required String description,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white30),
          ],
        ),
      ),
    );
  }
}

// --- DIALOG PASTO COMPLETO CON IA ---

class WholeMealAiDialog extends StatefulWidget {
  final String defaultMeal;

  const WholeMealAiDialog({super.key, required this.defaultMeal});

  @override
  State<WholeMealAiDialog> createState() => _WholeMealAiDialogState();
}

class _WholeMealAiDialogState extends State<WholeMealAiDialog> {
  final _textController = TextEditingController();
  late String _selectedMeal;
  List<MealItem> _estimatedItems = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedMeal = widget.defaultMeal;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _analyzeMeal() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final appState = context.read<AppState>();
    final service = appState.geminiService;

    if (service == null) {
      setState(() {
        _error = 'Inserisci la tua API Key di Gemini nella scheda Profilo per sbloccare l\'IA nutrizionale!';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _estimatedItems = [];
      _error = null;
    });

    try {
      final items = await service.analyzeTextToMeals(text);
      setState(() {
        _estimatedItems = items;
        if (items.isEmpty) {
          _error = 'L\'IA non ha identificato alimenti. Prova ad essere più specifico.';
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Errore di connessione o API non valida. Dettagli: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _editItemGrams(int index) {
    final item = _estimatedItems[index];
    final controller = TextEditingController(text: item.amountGrams.toInt().toString());
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1B1B22),
          title: Text('Modifica Grammi per ${item.food.name}', style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              suffixText: 'g',
              suffixStyle: TextStyle(color: Colors.white54),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FFC2))),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () {
                final double? newGrams = double.tryParse(controller.text);
                if (newGrams != null && newGrams > 0) {
                  setState(() {
                    _estimatedItems[index] = MealItem(
                      food: item.food,
                      amountGrams: newGrams,
                    );
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('Salva', style: TextStyle(color: Color(0xFF00FFC2), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _removeItem(int index) {
    setState(() {
      _estimatedItems.removeAt(index);
    });
  }

  void _approveAndAdd() {
    final appState = context.read<AppState>();
    for (var item in _estimatedItems) {
      appState.addMealItem(_selectedMeal, item.food, item.amountGrams);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pasto aggiunto con successo a $_selectedMeal!'),
        backgroundColor: const Color(0xFF00FFC2),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const accentCyan = Color(0xFF00FFC2);
    const accentPink = Color(0xFFFF007F);
    final appState = context.watch<AppState>();
    final hasKey = appState.currentUser?.geminiApiKey != null;

    final double totalCalories = _estimatedItems.fold(0.0, (sum, item) => sum + item.calories);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13).withOpacity(0.95),
      appBar: AppBar(
        title: const Text('Aggiungi Pasto con IA 🪄', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!hasKey) ...[
              // No key warnings
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: accentPink.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accentPink.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.vpn_key_off, color: accentPink, size: 40),
                    const SizedBox(height: 12),
                    const Text(
                      'Chiave API Gemini assente!',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Per utilizzare la stima ad intelligenza artificiale dell\'intero pasto con modelli avanzati di Google, inserisci la tua chiave API nelle impostazioni del tuo profilo.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/profile');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentPink,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Configura Profilo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Pasto Selector and Input Text
              Row(
                children: [
                  const Text('Inserisci pasto in:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedMeal,
                          dropdownColor: const Color(0xFF16161D),
                          style: const TextStyle(color: accentCyan, fontWeight: FontWeight.bold),
                          items: ['Colazione', 'Pranzo', 'Cena', 'Spuntini']
                              .map((name) => DropdownMenuItem(value: name, child: Text(name)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedMeal = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const Text(
                'Descrivi l\'intero pasto (es. quantità, olio, alimenti secondari):',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _textController,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Scrivi qui... (es. "Pasta corta con passata di pomodoro circa 100g, scatoletta di tonno sott\'olio sgocciolata da 80g e due cucchiai di parmigiano reggiano")',
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.03),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: accentCyan, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              ElevatedButton.icon(
                onPressed: _isLoading ? null : _analyzeMeal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentCyan,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F0F13)))
                    : const Icon(Icons.auto_awesome, color: Color(0xFF0F0F13)),
                label: Text(
                  _isLoading ? 'Elaborazione pasto...' : 'Stima Intero Pasto 🪄',
                  style: const TextStyle(color: Color(0xFF0F0F13), fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),

              const SizedBox(height: 24),

              // Renders parsed items list
              if (_estimatedItems.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accentCyan.withOpacity(0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Ingredienti Rilevati:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: accentCyan.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                            child: Text('${totalCalories.toInt()} kcal totali', style: const TextStyle(color: accentCyan, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text('Verifica e modifica la grammatura stimata o rimuovi alimenti non corretti prima del salvataggio:', style: TextStyle(color: Colors.white54, fontSize: 11)),
                      const SizedBox(height: 16),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _estimatedItems.length,
                        separatorBuilder: (context, index) => const Divider(color: Colors.white10),
                        itemBuilder: (context, index) {
                          final item = _estimatedItems[index];
                          return Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.food.name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                    Text(
                                      '${item.amountGrams.toInt()}g • P: ${item.proteins.toInt()}g | C: ${item.carbs.toInt()}g | F: ${item.fats.toInt()}g',
                                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  Text('${item.calories.toInt()} kcal', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: accentCyan, size: 18),
                                    onPressed: () => _editItemGrams(index),
                                    constraints: const BoxConstraints(),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: accentPink, size: 18),
                                    onPressed: () => _removeItem(index),
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _approveAndAdd,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentPink,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text('Approva ed Inserisci a $_selectedMeal', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ],
                  ),
                ),
              ] else if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: accentPink.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accentPink.withOpacity(0.2)),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
