import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/models.dart';
import '../../providers/app_state.dart';
import '../../data/remote/open_food_facts_service.dart';
import 'add_meal_screen.dart'; // Per BarcodeScannerScreen
import 'dashboard_screen.dart'; // Per WholeMealAiDialog

class QuickFoodLoggerSheet extends StatefulWidget {
  final String initialMeal;

  const QuickFoodLoggerSheet({super.key, required this.initialMeal});

  static Future<void> show(BuildContext context, {required String initialMeal}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuickFoodLoggerSheet(initialMeal: initialMeal),
    );
  }

  @override
  State<QuickFoodLoggerSheet> createState() => _QuickFoodLoggerSheetState();
}

class _QuickFoodLoggerSheetState extends State<QuickFoodLoggerSheet> {
  static const accentCyan = Color(0xFF00FFC2);
  static const accentPink = Color(0xFFFF007F);
  static const accentYellow = Color(0xFFFFD700);
  static const bgCard = Color(0xFF16161D);
  static const bgDark = Color(0xFF0F0F13);

  late String _selectedMeal;
  final TextEditingController _searchController = TextEditingController();
  final OpenFoodFactsService _offService = OpenFoodFactsService();
  Timer? _debounceTimer;

  bool _isSearching = false;
  List<Food> _webResults = [];
  List<Food> _recentFoods = [];
  bool _isLoadingRecents = true;

  // Staging / Carrello Multi-Add
  final List<MealItem> _stagedCart = [];

  // Filtro categoria
  int _filterIndex = 0; // 0: Tutti, 1: Miei / Ricette, 2: Web

  final List<String> _meals = ['Colazione', 'Pranzo', 'Cena', 'Spuntini'];

  @override
  void initState() {
    super.initState();
    _selectedMeal = widget.initialMeal;
    _loadRecentsForMeal();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRecentsForMeal() async {
    setState(() => _isLoadingRecents = true);
    final appState = context.read<AppState>();
    final recents = await appState.getRecentFoodsForMeal(_selectedMeal, limit: 10);
    if (mounted) {
      setState(() {
        _recentFoods = recents;
        _isLoadingRecents = false;
      });
    }
  }

  void _onMealChanged(String newMeal) {
    if (_selectedMeal != newMeal) {
      setState(() {
        _selectedMeal = newMeal;
      });
      _loadRecentsForMeal();
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _webResults = [];
        _isSearching = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _isSearching = true);
      try {
        final results = await _offService.searchProducts(query.trim());
        if (mounted) {
          setState(() {
            _webResults = results;
            _isSearching = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  Future<void> _openBarcodeScanner() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (barcode != null && barcode.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ricerca codice: $barcode...'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
      final product = await _offService.getProductByBarcode(barcode);
      if (product != null && mounted) {
        _showPortionPicker(product);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prodotto non trovato su Open Food Facts.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openAiLogger() {
    Navigator.pop(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WholeMealAiDialog(defaultMeal: _selectedMeal, isMealFixed: true),
    );
  }

  void _showPortionPicker(Food food) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PortionPickerSheet(
        food: food,
        mealName: _selectedMeal,
        onAddImmediate: (item) {
          final appState = context.read<AppState>();
          appState.addMealItem(_selectedMeal, item.food, item.amountGrams);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Aggiunti ${item.amountGrams.toInt()}g di ${item.food.name} a $_selectedMeal!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(ctx);
          if (_stagedCart.isEmpty) {
            Navigator.pop(context);
          }
        },
        onStageMultiAdd: (item) {
          setState(() {
            _stagedCart.add(item);
          });
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Aggiunto al carrello pasto (${_stagedCart.length} elementi)'),
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  Future<void> _commitStagedCart() async {
    if (_stagedCart.isEmpty) return;
    final appState = context.read<AppState>();
    await appState.addMultipleMealItems(_selectedMeal, _stagedCart);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registrati ${_stagedCart.length} alimenti in $_selectedMeal! 🥗'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final query = _searchController.text.trim().toLowerCase();

    // Filtra alimenti personalizzati e ricette
    final allCustom = appState.customFoods;
    final matchingCustom = query.isEmpty
        ? allCustom
        : allCustom.where((f) => f.name.toLowerCase().contains(query) || (f.brand?.toLowerCase().contains(query) ?? false)).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: bgDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // Header con selezione pasto
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.flash_on, color: accentCyan, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Registra Pasto',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Selettore Pasto Orizzontale a Chip
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: _meals.map((m) {
                final isSelected = m == _selectedMeal;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(m),
                    selected: isSelected,
                    onSelected: (_) => _onMealChanged(m),
                    selectedColor: accentCyan.withOpacity(0.2),
                    backgroundColor: Colors.white.withOpacity(0.04),
                    labelStyle: TextStyle(
                      color: isSelected ? accentCyan : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide(color: isSelected ? accentCyan : Colors.transparent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }).toList(),
            ),
          ),

          // Barra di Ricerca Unificata con Barcode e IA
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Container(
              decoration: BoxDecoration(
                color: bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.search, color: accentCyan, size: 22),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      onChanged: _onSearchChanged,
                      decoration: const InputDecoration(
                        hintText: 'Cerca alimento o ricetta...',
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    ),
                  // Scorciatoia Barcode Scanner
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner, color: accentPink, size: 22),
                    tooltip: 'Scansiona Barcode',
                    onPressed: _openBarcodeScanner,
                  ),
                  // Scorciatoia IA
                  IconButton(
                    icon: const Icon(Icons.auto_awesome, color: accentCyan, size: 22),
                    tooltip: 'Inserisci con IA',
                    onPressed: _openAiLogger,
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),

          // Chips Filtro quando c'è una ricerca
          if (query.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _buildFilterChip(0, 'Tutti (${matchingCustom.length + _webResults.length})'),
                  const SizedBox(width: 8),
                  _buildFilterChip(1, 'I Miei (${matchingCustom.length})'),
                  const SizedBox(width: 8),
                  _buildFilterChip(2, 'Web (${_webResults.length})'),
                ],
              ),
            ),

          // Lista Risultati o Sezione Recenti
          Expanded(
            child: query.isEmpty
                ? _buildEmptySearchBody(matchingCustom)
                : _buildSearchResultsBody(matchingCustom),
          ),

          // Carrello Multi-Add Fisso in Basso (se ci sono elementi)
          if (_stagedCart.isNotEmpty) _buildMultiAddCartBanner(),
        ],
      ),
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final isSelected = _filterIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _filterIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? accentCyan.withOpacity(0.15) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? accentCyan : Colors.white10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? accentCyan : Colors.white60,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySearchBody(List<Food> myFoods) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // Sezione Recenti / Abituali per questo pasto
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Abituali a $_selectedMeal ⚡',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            if (_isLoadingRecents)
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: accentCyan)),
          ],
        ),
        const SizedBox(height: 8),
        if (!_isLoadingRecents && _recentFoods.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(12)),
            child: const Text(
              'Nessun cibo registrato di recente a questo pasto. Cerca in alto o usa il barcode!',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _recentFoods.map((f) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: Icon(
                      f.isRecipe ? Icons.soup_kitchen : Icons.fastfood,
                      color: f.isRecipe ? accentPink : accentCyan,
                      size: 16,
                    ),
                    label: Text(
                      '${f.name} ${f.customServingGrams != null ? "(${f.customServingGrams!.toInt()}g)" : ""}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    backgroundColor: bgCard,
                    side: const BorderSide(color: Colors.white12),
                    onPressed: () => _showPortionPicker(f),
                  ),
                );
              }).toList(),
            ),
          ),

        const SizedBox(height: 20),

        // Sezione I Miei Alimenti & Ricette
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'I Miei Alimenti e Ricette Salvate',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            Text(
              '${myFoods.length} totali',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...myFoods.map((food) => _buildFoodListTile(food)),
      ],
    );
  }

  Widget _buildSearchResultsBody(List<Food> matchingCustom) {
    if (_isSearching && _webResults.isEmpty && matchingCustom.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: accentCyan),
      );
    }

    final itemsToShow = <Widget>[];

    // Sezione Miei Alimenti / Ricette
    if (_filterIndex == 0 || _filterIndex == 1) {
      if (matchingCustom.isNotEmpty) {
        itemsToShow.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'I Miei Alimenti e Ricette (${matchingCustom.length})',
              style: const TextStyle(color: accentCyan, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        );
        itemsToShow.addAll(matchingCustom.map((f) => _buildFoodListTile(f)));
      }
    }

    // Sezione Web Open Food Facts
    if (_filterIndex == 0 || _filterIndex == 2) {
      if (_webResults.isNotEmpty) {
        itemsToShow.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text(
                  'Database Open Food Facts',
                  style: TextStyle(color: accentPink, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                if (_isSearching) ...[
                  const SizedBox(width: 8),
                  const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: accentPink)),
                ],
              ],
            ),
          ),
        );
        itemsToShow.addAll(_webResults.map((f) => _buildFoodListTile(f)));
      }
    }

    if (itemsToShow.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, color: Colors.white24, size: 48),
            const SizedBox(height: 12),
            const Text('Nessun risultato trovato.', style: TextStyle(color: Colors.white60)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _openBarcodeScanner,
              icon: const Icon(Icons.qr_code_scanner, color: accentPink),
              label: const Text('Prova a scansionare il barcode', style: TextStyle(color: accentPink)),
            ),
          ],
        ),
      );
    }

    return ListView(children: itemsToShow);
  }

  Widget _buildFoodListTile(Food food) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: food.isRecipe ? accentPink.withOpacity(0.12) : accentCyan.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            food.isRecipe ? Icons.soup_kitchen : (food.isCustom ? Icons.bookmark : Icons.public),
            color: food.isRecipe ? accentPink : accentCyan,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                food.name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (food.customServingGrams != null)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accentYellow.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: accentYellow.withOpacity(0.3)),
                ),
                child: Text(
                  '${food.customServingGrams!.toInt()}g',
                  style: const TextStyle(color: accentYellow, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${food.caloriesPer100g.toStringAsFixed(0)} kcal/100g • P:${food.proteinsPer100g.toStringAsFixed(1)}g C:${food.carbsPer100g.toStringAsFixed(1)}g F:${food.fatsPer100g.toStringAsFixed(1)}g Fib:${food.fibersPer100g.toStringAsFixed(1)}g',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        trailing: const Icon(Icons.add_circle_outline, color: accentCyan, size: 22),
        onTap: () => _showPortionPicker(food),
      ),
    );
  }

  Widget _buildMultiAddCartBanner() {
    final totalKcal = _stagedCart.fold(0.0, (sum, i) => sum + i.calories);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F28),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, -2)),
        ],
        border: const Border(top: BorderSide(color: accentCyan, width: 1.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_stagedCart.length} alimenti nel carrello',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    'Totale: ${totalKcal.toStringAsFixed(0)} kcal',
                    style: const TextStyle(color: accentCyan, fontSize: 12),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _commitStagedCart,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentCyan,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Salva nel Diario', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal di selezione quantità con evidenza della PORZIONE PERSONALIZZATA
class _PortionPickerSheet extends StatefulWidget {
  final Food food;
  final String mealName;
  final ValueChanged<MealItem> onAddImmediate;
  final ValueChanged<MealItem> onStageMultiAdd;

  const _PortionPickerSheet({
    required this.food,
    required this.mealName,
    required this.onAddImmediate,
    required this.onStageMultiAdd,
  });

  @override
  State<_PortionPickerSheet> createState() => _PortionPickerSheetState();
}

class _PortionPickerSheetState extends State<_PortionPickerSheet> {
  static const accentCyan = Color(0xFF00FFC2);
  static const accentPink = Color(0xFFFF007F);
  static const accentYellow = Color(0xFFFFD700);
  static const bgCard = Color(0xFF16161D);

  late TextEditingController _amountController;
  late double _amountGrams;

  @override
  void initState() {
    super.initState();
    // Default: usa la porzione personalizzata se presente, altrimenti 100g
    final initialGrams = widget.food.customServingGrams ?? 100.0;
    _amountGrams = initialGrams;
    _amountController = TextEditingController(text: initialGrams.toInt().toString());
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _setGrams(double grams) {
    setState(() {
      _amountGrams = grams;
      _amountController.text = grams.toInt().toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    final cal = (food.caloriesPer100g * _amountGrams) / 100;
    final prot = (food.proteinsPer100g * _amountGrams) / 100;
    final carbs = (food.carbsPer100g * _amountGrams) / 100;
    final fats = (food.fatsPer100g * _amountGrams) / 100;
    final fibers = (food.fibersPer100g * _amountGrams) / 100;

    final hasCustomPortion = food.customServingGrams != null && food.customServingGrams! > 0;
    final customGrams = food.customServingGrams ?? 100.0;
    final portionLabel = food.customServingName ?? 'Porzione';

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),

            // Titolo Alimento
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food.name,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (food.brand != null && food.brand!.isNotEmpty)
                        Text(food.brand!, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.mealName,
                    style: const TextStyle(color: accentCyan, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // SEZIONE EVIDENZIATA: PORZIONE PERSONALIZZATA (se presente)
            if (hasCustomPortion) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentCyan.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accentCyan.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star, color: accentYellow, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Porzione Abituale: $portionLabel (${customGrams.toInt()}g)',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildMultiplierChip(0.5, customGrams),
                        const SizedBox(width: 8),
                        _buildMultiplierChip(1.0, customGrams, isPrimary: true),
                        const SizedBox(width: 8),
                        _buildMultiplierChip(1.5, customGrams),
                        const SizedBox(width: 8),
                        _buildMultiplierChip(2.0, customGrams),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Input Grammatura Manuale
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Grammatura (g)',
                      labelStyle: const TextStyle(color: Colors.white60),
                      suffixText: 'g',
                      suffixStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.04),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _amountGrams = double.tryParse(val) ?? 0.0;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Chips grammature standard
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [25, 50, 80, 100, 150, 200, 250].map((g) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text('${g}g', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      backgroundColor: Colors.white.withOpacity(0.04),
                      side: const BorderSide(color: Colors.white10),
                      padding: EdgeInsets.zero,
                      onPressed: () => _setGrams(g.toDouble()),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Valori Nutrizionali Calcolati
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMacroCol('Calorie', '${cal.toStringAsFixed(0)} kcal', accentCyan),
                  _buildMacroCol('Proteine', '${prot.toStringAsFixed(1)}g', accentPink),
                  _buildMacroCol('Carboidrati', '${carbs.toStringAsFixed(1)}g', accentYellow),
                  _buildMacroCol('Grassi', '${fats.toStringAsFixed(1)}g', const Color(0xFF00E676)),
                  _buildMacroCol('Fibre', '${fibers.toStringAsFixed(1)}g', Colors.cyan),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Bottoni Azione
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _amountGrams <= 0
                        ? null
                        : () {
                            widget.onStageMultiAdd(
                              MealItem(food: food, amountGrams: _amountGrams, targetMeal: widget.mealName),
                            );
                          },
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: const Text('+ Carrello'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accentCyan,
                      side: const BorderSide(color: accentCyan),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _amountGrams <= 0
                        ? null
                        : () {
                            widget.onAddImmediate(
                              MealItem(food: food, amountGrams: _amountGrams, targetMeal: widget.mealName),
                            );
                          },
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Registra Subito'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentPink,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiplierChip(double multiplier, double baseGrams, {bool isPrimary = false}) {
    final calcGrams = baseGrams * multiplier;
    final isSelected = (_amountGrams - calcGrams).abs() < 0.5;

    return Expanded(
      child: GestureDetector(
        onTap: () => _setGrams(calcGrams),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? accentCyan
                : (isPrimary ? accentCyan.withOpacity(0.15) : Colors.white.withOpacity(0.04)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? accentCyan : Colors.white12),
          ),
          child: Column(
            children: [
              Text(
                '${multiplier}x',
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                '${calcGrams.toInt()}g',
                style: TextStyle(
                  color: isSelected ? Colors.black87 : Colors.white60,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacroCol(String label, String val, Color col) {
    return Column(
      children: [
        Text(val, style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }
}
