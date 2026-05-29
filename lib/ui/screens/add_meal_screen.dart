import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:io';
import '../../providers/app_state.dart';
import '../../domain/models.dart';
import '../../data/remote/open_food_facts_service.dart';

class AddMealScreen extends StatefulWidget {
  const AddMealScreen({super.key});

  @override
  State<AddMealScreen> createState() => _AddMealScreenState();
}

class _AddMealScreenState extends State<AddMealScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _openFoodFactsService = OpenFoodFactsService();

  // Parametri Generali
  late String _selectedMealName;
  bool _initializedMealName = false;
  final _amountController = TextEditingController(text: '100');

  // Stato Tab Cerca
  final _searchController = TextEditingController();
  List<Food> _searchResults = [];
  bool _isSearching = false;

  // Stato Tab Barcode
  final _barcodeController = TextEditingController();
  Food? _barcodeResult;
  bool _isScanning = false;
  String? _barcodeError;

  // Stato Tab Analisi IA (Singolo Alimento)
  final _singleFoodAiController = TextEditingController();
  final _singleFoodGramsController = TextEditingController(text: '100');
  Food? _aiSingleFoodResult;
  bool _isSingleFoodAiLoading = false;
  String? _singleFoodAiError;

  // Stato Tab Cibo Custom
  final _customFormKey = GlobalKey<FormState>();
  final _customNameController = TextEditingController();
  final _customBrandController = TextEditingController();
  final _customCalController = TextEditingController();
  final _customProtController = TextEditingController();
  final _customCarbController = TextEditingController();
  final _customFatController = TextEditingController();
  final _customFibController = TextEditingController();
  final _savedSearchController = TextEditingController();
  bool _saveOnline = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _customProtController.addListener(_updateCalculatedCalories);
    _customCarbController.addListener(_updateCalculatedCalories);
    _customFatController.addListener(_updateCalculatedCalories);
    _customFibController.addListener(_updateCalculatedCalories);
  }

  void _updateCalculatedCalories() {
    final protText = _customProtController.text.trim();
    final carbText = _customCarbController.text.trim();
    final fatText = _customFatController.text.trim();
    final fibText = _customFibController.text.trim();

    // Se tutti i campi sono vuoti, non forzare le calorie a zero per consentire l'inserimento libero
    if (protText.isEmpty && carbText.isEmpty && fatText.isEmpty && fibText.isEmpty) {
      return;
    }

    final prot = double.tryParse(protText) ?? 0.0;
    final carb = double.tryParse(carbText) ?? 0.0;
    final fat = double.tryParse(fatText) ?? 0.0;
    final fib = double.tryParse(fibText) ?? 0.0;

    final double calculated = (prot * 4.0) + (carb * 4.0) + (fat * 9.0) + (fib * 2.0);
    
    // Mostra il valore calcolato all'utente
    _customCalController.text = calculated.toStringAsFixed(calculated % 1 == 0 ? 0 : 1);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedMealName) {
      final args = ModalRoute.of(context)?.settings.arguments as String?;
      _selectedMealName = args ?? 'Colazione';
      _initializedMealName = true;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _searchController.dispose();
    _barcodeController.dispose();
    _singleFoodAiController.dispose();
    _singleFoodGramsController.dispose();
    _customNameController.dispose();
    _customBrandController.dispose();
    _customCalController.dispose();
    _customProtController.dispose();
    _customCarbController.dispose();
    _customFatController.dispose();
    _customFibController.dispose();
    _savedSearchController.dispose();
    super.dispose();
  }

  // --- AZIONI ---

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    try {
      final results = await _openFoodFactsService.searchProducts(query);
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      print('Errore di ricerca: $e');
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _scanBarcode(String barcode) async {
    if (barcode.trim().isEmpty) return;
    setState(() {
      _isScanning = true;
      _barcodeResult = null;
      _barcodeError = null;
    });

    try {
      final product = await _openFoodFactsService.getProductByBarcode(barcode);
      if (product != null) {
        setState(() {
          _barcodeResult = product;
        });
      } else {
        setState(() {
          _barcodeError = 'Prodotto non trovato nel database OpenFoodFacts.';
        });
      }
    } catch (e) {
      setState(() {
        _barcodeError = 'Errore di connessione durante la scansione.';
      });
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  // Apri fotocamera per scansione barcode reale
  Future<void> _openCameraForBarcode() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (status.isPermanentlyDenied) openAppSettings();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permesso fotocamera necessario per la scansione.')),
      );
      return;
    }

    final String? scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const BarcodeScannerScreen(),
      ),
    );

    if (scannedCode != null && scannedCode.isNotEmpty) {
      setState(() {
        _barcodeController.text = scannedCode;
        _barcodeError = null;
      });
      _scanBarcode(scannedCode);
    }
  }

  Future<void> _analyzeSingleFoodWithAi() async {
    final text = _singleFoodAiController.text.trim();
    if (text.isEmpty) return;

    final appState = context.read<AppState>();
    final service = appState.geminiService;

    if (service == null) {
      setState(() {
        _singleFoodAiError = 'Inserisci la tua API Key Gemini nel profilo per sbloccare l\'IA!';
      });
      return;
    }

    setState(() {
      _isSingleFoodAiLoading = true;
      _aiSingleFoodResult = null;
      _singleFoodAiError = null;
    });

    try {
      final food = await service.analyzeSingleFood(text);
      setState(() {
        if (food != null) {
          _aiSingleFoodResult = food;
        } else {
          _singleFoodAiError = 'L\'IA non ha identificato l\'alimento singolo. Prova ad essere più specifico.';
        }
      });
    } catch (e) {
      setState(() {
        _singleFoodAiError = 'Errore durante l\'analisi AI. Dettagli: $e';
      });
    } finally {
      setState(() {
        _isSingleFoodAiLoading = false;
      });
    }
  }

  void _saveCustomFoodAndAdd() {
    if (_customFormKey.currentState!.validate()) {
      final appState = context.read<AppState>();

      final newFood = Food(
        id: 'local_custom_${DateTime.now().millisecondsSinceEpoch}',
        name: _customNameController.text.trim(),
        brand: _customBrandController.text.trim().isEmpty ? null : _customBrandController.text.trim(),
        caloriesPer100g: double.tryParse(_customCalController.text) ?? 0,
        proteinsPer100g: double.tryParse(_customProtController.text) ?? 0,
        carbsPer100g: double.tryParse(_customCarbController.text) ?? 0,
        fatsPer100g: double.tryParse(_customFatController.text) ?? 0,
        fibersPer100g: double.tryParse(_customFibController.text) ?? 0,
        isCustom: true,
        isOnline: _saveOnline,
      );

      if (_saveOnline) {
        appState.saveCustomFood(newFood);
      }

      // Mostra dialogo quantità prima di aggiungere
      _showAddQuantityDialog(newFood);
    }
  }

  void _saveOnlyCustomFood() {
    if (_customFormKey.currentState!.validate()) {
      final appState = context.read<AppState>();
      final newFood = Food(
        id: 'local_custom_${DateTime.now().millisecondsSinceEpoch}',
        name: _customNameController.text.trim(),
        brand: _customBrandController.text.trim().isEmpty ? null : _customBrandController.text.trim(),
        caloriesPer100g: double.tryParse(_customCalController.text) ?? 0,
        proteinsPer100g: double.tryParse(_customProtController.text) ?? 0,
        carbsPer100g: double.tryParse(_customCarbController.text) ?? 0,
        fatsPer100g: double.tryParse(_customFatController.text) ?? 0,
        fibersPer100g: double.tryParse(_customFibController.text) ?? 0,
        isCustom: true,
        isOnline: true,
      );

      appState.saveCustomFood(newFood);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${newFood.name} salvato tra i preferiti!'),
          backgroundColor: const Color(0xFF00FFC2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _addFoodDirectly(Food food) {
    final double grams = double.tryParse(_amountController.text) ?? 100.0;
    context.read<AppState>().addMealItem(_selectedMealName, food, grams);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${food.name} (${grams.toInt()}g) aggiunto a $_selectedMealName!'),
        backgroundColor: const Color(0xFF00FFC2),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context);
  }



  // --- BOTTOM SHEET INFO ALIMENTO ---
  void _showFoodInfoSheet(Food food) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FoodInfoSheet(food: food),
    );
  }

  // --- POPUP DI SELEZIONE GRAMMATURA ---
  void _showAddQuantityDialog(Food food) {
    double amount = 100.0;
    final textController = TextEditingController(text: '100');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            double calories = (food.caloriesPer100g * amount) / 100;
            double proteins = (food.proteinsPer100g * amount) / 100;
            double carbs = (food.carbsPer100g * amount) / 100;
            double fats = (food.fatsPer100g * amount) / 100;
            double fibers = (food.fibersPer100g * amount) / 100;

            const accentCyan = Color(0xFF00FFC2);
            const accentPink = Color(0xFFFF007F);

            return AlertDialog(
              backgroundColor: const Color(0xFF16161D),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  if (food.brand != null && food.brand!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(food.brand!, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  ],
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
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Quantità (g)',
                        labelStyle: const TextStyle(color: Colors.white60),
                        suffixText: 'g',
                        suffixStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.04),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          amount = double.tryParse(val) ?? 0.0;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // Quick gram chips
                    Wrap(
                      spacing: 8,
                      children: [30, 50, 100, 150, 200, 250].map((g) {
                        return ActionChip(
                          label: Text('${g}g', style: const TextStyle(color: Colors.white, fontSize: 11)),
                          backgroundColor: Colors.white.withOpacity(0.06),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            textController.text = g.toString();
                            setDialogState(() { amount = g.toDouble(); });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('Valori calcolati:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 10),
                    _buildDialogMacroRow('Calorie', '${calories.toStringAsFixed(1)} kcal', accentCyan, Colors.white.withOpacity(0.05)),
                    _buildDialogMacroRow('Proteine', '${proteins.toStringAsFixed(1)} g', accentPink, Colors.white.withOpacity(0.03)),
                    _buildDialogMacroRow('Carboidrati', '${carbs.toStringAsFixed(1)} g', const Color(0xFFFFD700), Colors.white.withOpacity(0.05)),
                    _buildDialogMacroRow('Grassi', '${fats.toStringAsFixed(1)} g', const Color(0xFF00E676), Colors.white.withOpacity(0.03)),
                    _buildDialogMacroRow('Fibre', '${fibers.toStringAsFixed(1)} g', Colors.cyan, Colors.white.withOpacity(0.05)),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.all(16),
              actions: [
                TextButton(
                  onPressed: () {
                    final appState = this.context.read<AppState>();
                    appState.saveCustomFood(food);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('Alimento salvato nella scheda Salvati!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Salva', style: TextStyle(color: accentCyan, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: amount <= 0 ? null : () {
                    final appState = this.context.read<AppState>();
                    appState.addMealItem(_selectedMealName, food, amount);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text('Aggiunti ${amount.toInt()}g di ${food.name} a $_selectedMealName!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    Navigator.pop(context);
                    Navigator.pop(this.context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentPink,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Aggiungi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDialogMacroRow(String label, String value, Color color, Color bgColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  // --- BUILD ---

  @override
  Widget build(BuildContext context) {
    const accentCyan = Color(0xFF00FFC2);
    const accentPink = Color(0xFFFF007F);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text('Aggiungi Alimento', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: accentCyan,
          labelColor: accentCyan,
          unselectedLabelColor: Colors.white54,
          isScrollable: true,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.search), text: 'Cerca'),
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'Barcode'),
            Tab(icon: Icon(Icons.psychology), text: 'IA Singolo'),
            Tab(icon: Icon(Icons.note_add), text: 'Nuovo'),
            Tab(icon: Icon(Icons.history), text: 'Cronologia'),
            Tab(icon: Icon(Icons.bookmark), text: 'Salvati'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Selettore Pasto
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: Row(
              children: [
                const Icon(Icons.restaurant_menu, color: Colors.white38, size: 18),
                const SizedBox(width: 8),
                const Text('Pasto:', style: TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedMealName,
                        dropdownColor: const Color(0xFF16161D),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        items: ['Colazione', 'Pranzo', 'Cena', 'Spuntini']
                            .map((name) => DropdownMenuItem(value: name, child: Text(name)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedMealName = val);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSearchTab(accentCyan, accentPink),
                _buildBarcodeTab(accentCyan, accentPink),
                _buildAiTab(accentCyan, accentPink),
                _buildCustomTab(accentCyan, accentPink),
                _buildHistoryTab(accentCyan, accentPink),
                _buildSavedTab(accentCyan, accentPink),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // TAB 1: CERCA
  Widget _buildSearchTab(Color cyan, Color pink) {
    final appState = context.watch<AppState>();
    final query = _searchController.text.trim().toLowerCase();

    final List<Food> localFiltered = query.isEmpty
        ? appState.customFoods
        : appState.customFoods.where((food) => food.name.toLowerCase().contains(query)).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (val) => setState(() {}),
                  onSubmitted: (_) => _performSearch(),
                  decoration: InputDecoration(
                    hintText: 'Cerca alimento...',
                    hintStyle: const TextStyle(color: Colors.white30),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.04),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _performSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cyan,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                ),
                child: const Text('Cerca 🔍', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FFC2)))
                : ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      if (localFiltered.isNotEmpty) ...[
                        _sectionHeader(Icons.cloud_done, 'Cibi Personali', cyan),
                        const SizedBox(height: 8),
                        ...localFiltered.map((food) => _buildFoodListTile(food, cyan)),
                        const SizedBox(height: 20),
                      ],
                      if (_searchResults.isNotEmpty) ...[
                        _sectionHeader(Icons.language, 'Risultati OpenFoodFacts', pink),
                        const SizedBox(height: 8),
                        ..._searchResults.map((food) => _buildFoodListTile(food, pink)),
                      ] else if (localFiltered.isEmpty) ...[
                        const SizedBox(height: 80),
                        const Center(
                          child: Column(
                            children: [
                              Icon(Icons.search_off, size: 48, color: Colors.white24),
                              SizedBox(height: 10),
                              Text(
                                'Cerca per nome o marca.\nPremi Enter o il tasto "Cerca 🔍" per cercare su internet.',
                                style: TextStyle(color: Colors.white30, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 6),
        Text(title, style: TextStyle(color: color.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildFoodListTile(Food food, Color accentColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Text(food.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(
          '${food.brand ?? "Generico"} · ${food.caloriesPer100g.toInt()} kcal/100g',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (food.isCustom) ...[
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white30, size: 20),
                tooltip: 'Elimina',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _deleteFood(food),
              ),
              const SizedBox(width: 8),
            ],
            // Tasto Info
            IconButton(
              icon: Icon(Icons.info_outline, color: accentColor.withOpacity(0.7), size: 20),
              tooltip: 'Info macros',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _showFoodInfoSheet(food),
            ),
            const SizedBox(width: 8),
            // Tasto Aggiungi
            GestureDetector(
              onTap: () => _showAddQuantityDialog(food),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.add, color: accentColor, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // TAB 2: BARCODE
  Widget _buildBarcodeTab(Color cyan, Color pink) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Pulsante fotocamera principale
          GestureDetector(
            onTap: _openCameraForBarcode,
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cyan.withOpacity(0.25)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isScanning ? Icons.sync : Icons.camera_alt,
                        size: 48,
                        color: cyan,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _isScanning ? 'Ricerca in corso...' : 'Tocca per aprire la fotocamera',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Inquadra il codice a barre del prodotto',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                  if (_isScanning)
                    Positioned(
                      top: 80,
                      left: 20,
                      right: 20,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: cyan,
                          boxShadow: [BoxShadow(color: cyan.withOpacity(0.8), blurRadius: 10, spreadRadius: 2)],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),



          // Input Manuale
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _barcodeController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => _scanBarcode(_barcodeController.text),
                  decoration: InputDecoration(
                    hintText: 'Inserisci codice a barre...',
                    hintStyle: const TextStyle(color: Colors.white30),
                    prefixIcon: const Icon(Icons.qr_code, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.04),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _scanBarcode(_barcodeController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: pink,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Icon(Icons.search, color: Colors.white),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Risultato
          if (_barcodeResult != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cyan.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cyan.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Prodotto Trovato!', style: TextStyle(color: cyan, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('${_barcodeResult!.caloriesPer100g.toInt()} kcal/100g', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_barcodeResult!.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(_barcodeResult!.brand ?? 'Marca Sconosciuta', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showFoodInfoSheet(_barcodeResult!),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: cyan.withOpacity(0.4)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: Icon(Icons.info_outline, color: cyan, size: 16),
                          label: Text('Info', style: TextStyle(color: cyan, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () => _showAddQuantityDialog(_barcodeResult!),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cyan,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Aggiungi', style: TextStyle(color: Color(0xFF0F0F13), fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else if (_barcodeError != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: pink.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: pink.withOpacity(0.2)),
              ),
              child: Text(_barcodeError!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            ),
          ],
        ],
      ),
    );
  }


  // TAB 3: IA SINGOLO
  Widget _buildAiTab(Color cyan, Color pink) {
    final appState = context.watch<AppState>();
    final hasKey = appState.currentUser?.geminiApiKey != null;

    if (!hasKey) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.psychology_alt, size: 72, color: Colors.white24),
            const SizedBox(height: 16),
            const Text('Assistente AI Disattivato', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('Inserisci la tua API Key Gemini nel profilo per abilitare l\'analisi AI degli alimenti.', style: TextStyle(color: Colors.white54, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/profile'),
              style: ElevatedButton.styleFrom(backgroundColor: pink, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              icon: const Icon(Icons.settings, color: Colors.white),
              label: const Text('Vai alle Impostazioni', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Descrivi l\'alimento singolo da inserire:',
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'L\'IA analizzerà il testo, identificherà l\'alimento e stimerà i suoi valori nutrizionali.',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _singleFoodAiController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Es. "un piatto di pasta corta", "una mela rossa media", "120g di petto di pollo cotto", "due cucchiai di olio d\'oliva"...',
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
              filled: true,
              fillColor: Colors.white.withOpacity(0.03),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: cyan, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: _isSingleFoodAiLoading ? null : _analyzeSingleFoodWithAi,
            style: ElevatedButton.styleFrom(
              backgroundColor: cyan,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: _isSingleFoodAiLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F0F13)))
                : const Icon(Icons.auto_awesome, color: Color(0xFF0F0F13)),
            label: Text(
              _isSingleFoodAiLoading ? 'Identificazione alimento...' : 'Estrai Alimento Singolo 🪄',
              style: const TextStyle(color: Color(0xFF0F0F13), fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),

          const SizedBox(height: 24),

          if (_aiSingleFoodResult != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cyan.withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _aiSingleFoodResult!.name,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            if (_aiSingleFoodResult!.brand != null && _aiSingleFoodResult!.brand!.isNotEmpty)
                              Text(
                                _aiSingleFoodResult!.brand!,
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cyan.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_aiSingleFoodResult!.caloriesPer100g.toInt()} kcal/100g',
                          style: TextStyle(color: cyan, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  const Text('Valori per 100g stimati:', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMiniMacro('Prot', '${_aiSingleFoodResult!.proteinsPer100g.toStringAsFixed(1)}g', pink),
                      _buildMiniMacro('Carb', '${_aiSingleFoodResult!.carbsPer100g.toStringAsFixed(1)}g', const Color(0xFFFFD700)),
                      _buildMiniMacro('Gras', '${_aiSingleFoodResult!.fatsPer100g.toStringAsFixed(1)}g', const Color(0xFF00E676)),
                      _buildMiniMacro('Fibr', '${_aiSingleFoodResult!.fibersPer100g.toStringAsFixed(1)}g', Colors.cyan),
                    ],
                  ),
                  const SizedBox(height: 20),

                  const Divider(color: Colors.white10),
                  const SizedBox(height: 12),

                  // Selettore Grammi
                  Row(
                    children: [
                      const Text('Quantità:', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 45,
                          child: TextField(
                            controller: _singleFoodGramsController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              suffixText: 'g',
                              suffixStyle: const TextStyle(color: Colors.white38),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.04),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Bottoni Salva e Aggiungi
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            appState.saveCustomFood(_aiSingleFoodResult!);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${_aiSingleFoodResult!.name} salvato nei preferiti!'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          icon: Icon(Icons.favorite_border, color: cyan, size: 16),
                          label: Text('Salva', style: TextStyle(color: cyan, fontWeight: FontWeight.bold, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: cyan),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final grams = double.tryParse(_singleFoodGramsController.text) ?? 100.0;
                            appState.addMealItem(_selectedMealName, _aiSingleFoodResult!, grams);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${_aiSingleFoodResult!.name} (${grams.toInt()}g) aggiunto a $_selectedMealName!'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.add, color: Colors.white, size: 16),
                          label: const Text('Aggiungi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: pink,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else if (_singleFoodAiError != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: pink.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: pink.withOpacity(0.2)),
              ),
              child: Text(
                _singleFoodAiError!,
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniMacro(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }

  // TAB 4: NUOVO ALIMENTO - Layout a griglia compatta
  Widget _buildCustomTab(Color cyan, Color pink) {
    final appState = context.watch<AppState>();

    return Form(
      key: _customFormKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header con tasto IA
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Nuovo Alimento', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                if (appState.currentUser?.geminiApiKey != null)
                  TextButton.icon(
                    onPressed: _scanMacroLabelWithAi,
                    icon: const Icon(Icons.photo_camera, color: Color(0xFF00FFC2), size: 18),
                    label: const Text('Estrai con IA', style: TextStyle(color: Color(0xFF00FFC2), fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Nome e Marca su riga
            _buildFormInput('Nome Alimento *', _customNameController, TextInputType.name, true),
            const SizedBox(height: 10),
            _buildFormInput('Marca (opzionale)', _customBrandController, TextInputType.name, false),
            const SizedBox(height: 16),

            // Macro in griglia 2x2 (più compatta)
            const Text('Valori per 100g', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(child: _buildMacroInput('Calorie (kcal)*', _customCalController, const Color(0xFF00FFC2))),
                const SizedBox(width: 10),
                Expanded(child: _buildMacroInput('Proteine (g)*', _customProtController, const Color(0xFFFF007F))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildMacroInput('Carboidrati (g)*', _customCarbController, const Color(0xFFFFD700))),
                const SizedBox(width: 10),
                Expanded(child: _buildMacroInput('Grassi (g)*', _customFatController, const Color(0xFF00E676))),
              ],
            ),
            const SizedBox(height: 10),
            _buildMacroInput('Fibre (g)', _customFibController, Colors.cyan, required: false),

            const SizedBox(height: 16),

            // Switch cloud
            Container(
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(15)),
              child: SwitchListTile(
                value: _saveOnline,
                onChanged: (val) => setState(() => _saveOnline = val),
                dense: true,
                title: const Text('Salva nel Cloud', style: TextStyle(color: Colors.white, fontSize: 13)),
                activeColor: cyan,
              ),
            ),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saveOnlyCustomFood,
                    icon: Icon(Icons.favorite_border, color: cyan),
                    label: Text('Salva Preferiti', style: TextStyle(color: cyan, fontWeight: FontWeight.bold, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: cyan),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveCustomFoodAndAdd,
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Aggiungi Pasto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: pink,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroInput(String label, TextEditingController controller, Color accentColor, {bool required = true}) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      validator: (val) {
        if (required && (val == null || val.isEmpty)) return 'Obbligatorio';
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: accentColor.withOpacity(0.7), fontSize: 12),
        filled: true,
        fillColor: accentColor.withOpacity(0.04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentColor.withOpacity(0.5)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  // --- SCANSIONE ETICHETTA NUTRIZIONALE CON IA ---
  Future<void> _scanMacroLabelWithAi() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permesso fotocamera necessario per scansionare l\'etichetta.')),
      );
      return;
    }

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera, maxWidth: 1024, maxHeight: 1024, imageQuality: 80);
    if (image == null) return;

    setState(() => _isSearching = true);

    try {
      final bytes = await image.readAsBytes();
      final appState = context.read<AppState>();
      final service = appState.geminiService;
      if (service == null) return;

      final result = await service.analyzeMacroImage(bytes);
      if (result != null) {
        setState(() {
          _customNameController.text = result['name'] ?? '';
          _customBrandController.text = result['brand'] ?? '';
          _customCalController.text = result['caloriesPer100g']?.toString() ?? '';
          _customProtController.text = result['proteinsPer100g']?.toString() ?? '';
          _customCarbController.text = result['carbsPer100g']?.toString() ?? '';
          _customFatController.text = result['fatsPer100g']?.toString() ?? '';
          _customFibController.text = result['fibersPer100g']?.toString() ?? '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Valori estratti con successo! Verifica i campi.'), behavior: SnackBarBehavior.floating),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile estrarre i valori. Riprova con immagine più nitida.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
    } finally {
      setState(() => _isSearching = false);
    }
  }

  // TAB 5: CRONOLOGIA
  Widget _buildHistoryTab(Color cyan, Color pink) {
    final appState = context.watch<AppState>();

    return FutureBuilder<List<Food>>(
      future: appState.getFoodHistory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF00FFC2)));
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return const Center(
            child: Text(
              'Nessun alimento nella cronologia.\nAggiungi i tuoi primi alimenti!',
              style: TextStyle(color: Colors.white30, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (context, index) => _buildFoodListTile(list[index], cyan),
        );
      },
    );
  }

  void _deleteFood(Food food) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Elimina Alimento', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text('Sei sicuro di voler eliminare "${food.name}" dai tuoi alimenti salvati?', style: const TextStyle(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla', style: TextStyle(color: Colors.white54, fontSize: 13)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final appState = context.read<AppState>();
              await appState.deleteCustomFood(food.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('"${food.name}" eliminato dai salvati'),
                    backgroundColor: const Color(0xFFFF007F),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Elimina', style: TextStyle(color: Color(0xFFFF007F), fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // TAB 6: SALVATI
  Widget _buildSavedTab(Color cyan, Color pink) {
    final appState = context.watch<AppState>();
    final customFoods = appState.customFoods;
    final savedQuery = _savedSearchController.text.trim().toLowerCase();
    
    final list = savedQuery.isEmpty
        ? customFoods
        : customFoods.where((food) => food.name.toLowerCase().contains(savedQuery)).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (customFoods.isNotEmpty) ...[
            TextField(
              controller: _savedSearchController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              onChanged: (val) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Cerca tra i salvati...',
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 18),
                filled: true,
                fillColor: Colors.white.withOpacity(0.03),
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                suffixIcon: _savedSearchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54, size: 16),
                        onPressed: () {
                          _savedSearchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Text(
                      customFoods.isEmpty
                          ? 'Nessun alimento salvato.\nPremi "Salva" nel dialogo di aggiunta per salvarli qui.'
                          : 'Nessun risultato trovato nei tuoi cibi salvati.',
                      style: const TextStyle(color: Colors.white30, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: list.length,
                    itemBuilder: (context, index) => _buildFoodListTile(list[index], cyan),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormInput(String label, TextEditingController controller, TextInputType keyboardType, bool required) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      validator: (val) {
        if (required && (val == null || val.isEmpty)) return 'Campo obbligatorio';
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00FFC2)),
        ),
      ),
    );
  }
}

// --- SCHEDA INFO ALIMENTO (Bottom Sheet) ---
class _FoodInfoSheet extends StatefulWidget {
  final Food food;
  const _FoodInfoSheet({required this.food});

  @override
  State<_FoodInfoSheet> createState() => _FoodInfoSheetState();
}

class _FoodInfoSheetState extends State<_FoodInfoSheet> {
  double _grams = 100.0;
  final _gramController = TextEditingController(text: '100');

  @override
  void dispose() {
    _gramController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;

    final double cal = (food.caloriesPer100g * _grams) / 100;
    final double prot = (food.proteinsPer100g * _grams) / 100;
    final double carbs = (food.carbsPer100g * _grams) / 100;
    final double fats = (food.fatsPer100g * _grams) / 100;
    final double fibers = (food.fibersPer100g * _grams) / 100;

    const cyan = Color(0xFF00FFC2);
    const pink = Color(0xFFFF007F);
    const yellow = Color(0xFFFFD700);
    const green = Color(0xFF00E676);

    // Calcola tot per proporzioni
    final double totalMacroKcal = (prot * 4) + (carbs * 4) + (fats * 9);
    final double protPct = totalMacroKcal > 0 ? (prot * 4 / totalMacroKcal) : 0;
    final double carbPct = totalMacroKcal > 0 ? (carbs * 4 / totalMacroKcal) : 0;
    final double fatPct = totalMacroKcal > 0 ? (fats * 9 / totalMacroKcal) : 0;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF16161D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          controller: controller,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Titolo
                    Text(food.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                    if (food.brand != null && food.brand!.isNotEmpty)
                      Text(food.brand!, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                    const SizedBox(height: 20),

                    // Selettore quantità
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Simula quantità', style: TextStyle(color: Colors.white54, fontSize: 12)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _gramController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                  decoration: InputDecoration(
                                    suffixText: 'g',
                                    suffixStyle: TextStyle(color: Colors.white38),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.05),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                  onChanged: (val) => setState(() => _grams = double.tryParse(val) ?? 100.0),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Quick chips
                          Wrap(
                            spacing: 6,
                            children: [30, 50, 100, 150, 200, 250, 300].map((g) {
                              final selected = _grams == g.toDouble();
                              return ChoiceChip(
                                label: Text('${g}g', style: TextStyle(color: selected ? Colors.black : Colors.white, fontSize: 11)),
                                selected: selected,
                                selectedColor: cyan,
                                backgroundColor: Colors.white.withOpacity(0.06),
                                padding: EdgeInsets.zero,
                                onSelected: (_) {
                                  _gramController.text = g.toString();
                                  setState(() => _grams = g.toDouble());
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Calorie grande
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [cyan.withOpacity(0.15), cyan.withOpacity(0.03)]),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: cyan.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Calorie', style: TextStyle(color: cyan.withOpacity(0.7), fontSize: 13)),
                              Text('${cal.toStringAsFixed(1)} kcal', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 26)),
                            ],
                          ),
                          Text('per ${_grams.toInt()}g', style: TextStyle(color: Colors.white38, fontSize: 12)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Macro Cards
                    Row(
                      children: [
                        Expanded(child: _buildMacroCard('Proteine', prot, 'g', pink, protPct)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildMacroCard('Carboidrati', carbs, 'g', yellow, carbPct)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildMacroCard('Grassi', fats, 'g', green, fatPct)),
                      ],
                    ),

                    const SizedBox(height: 8),

                    _buildFiberCard(fibers, Colors.cyan),

                    const SizedBox(height: 16),

                    // Barra distribuzione macros
                    if (totalMacroKcal > 0) ...[
                      const Text('Distribuzione macros (% kcal)', style: TextStyle(color: Colors.white38, fontSize: 11)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          children: [
                            Flexible(flex: (protPct * 100).toInt().clamp(1, 100), child: Container(height: 12, color: pink)),
                            Flexible(flex: (carbPct * 100).toInt().clamp(1, 100), child: Container(height: 12, color: yellow)),
                            Flexible(flex: (fatPct * 100).toInt().clamp(1, 100), child: Container(height: 12, color: green)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('P ${(protPct * 100).toInt()}%', style: TextStyle(color: pink, fontSize: 11, fontWeight: FontWeight.bold)),
                          Text('C ${(carbPct * 100).toInt()}%', style: TextStyle(color: yellow, fontSize: 11, fontWeight: FontWeight.bold)),
                          Text('G ${(fatPct * 100).toInt()}%', style: TextStyle(color: green, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Riferimento per 100g
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildRef100g('Kcal', food.caloriesPer100g.toStringAsFixed(0), cyan),
                          _buildRef100g('Prot', food.proteinsPer100g.toStringAsFixed(1), pink),
                          _buildRef100g('Carb', food.carbsPer100g.toStringAsFixed(1), yellow),
                          _buildRef100g('Gras', food.fatsPer100g.toStringAsFixed(1), green),
                          _buildRef100g('Fibre', food.fibersPer100g.toStringAsFixed(1), Colors.cyan),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(child: Text('Valori di riferimento per 100g', style: TextStyle(color: Colors.white24, fontSize: 10))),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacroCard(String label, double value, String unit, Color color, double pct) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 11)),
          const SizedBox(height: 4),
          Text('${value.toStringAsFixed(1)}$unit', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            backgroundColor: Colors.white.withOpacity(0.06),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 3,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      ),
    );
  }

  Widget _buildFiberCard(double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Fibre', style: TextStyle(color: color.withOpacity(0.7), fontSize: 13)),
          Text('${value.toStringAsFixed(1)} g', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildRef100g(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }
}

// ── BARCODE REAL-TIME SCANNER ─────────────
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _hasDetected = false;
  bool _isAiExtracting = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _captureAndExtractBarcode() async {
    final appState = context.read<AppState>();
    if (appState.currentUser?.geminiApiKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configura la chiave API Gemini per l\'estrazione IA.')),
      );
      return;
    }

    final picker = ImagePicker();
    try {
      await controller.stop();

      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) {
        await controller.start();
        return;
      }

      setState(() {
        _isAiExtracting = true;
      });

      final bytes = await image.readAsBytes();
      final scannedCode = await appState.geminiService!.extractBarcodeFromImage(bytes);

      setState(() {
        _isAiExtracting = false;
      });

      if (scannedCode != null && scannedCode.isNotEmpty) {
        _hasDetected = true;
        if (mounted) {
          Navigator.pop(context, scannedCode);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossibile rilevare il codice a barre. Riprova con una foto più nitida e ravvicinata.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await controller.start();
      }
    } catch (e) {
      setState(() {
        _isAiExtracting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore estrazione: $e')),
      );
      await controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scansiona Barcode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            color: Colors.white,
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: controller,
              builder: (context, state, child) {
                switch (state.torchState) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off, color: Colors.grey);
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Color(0xFF00FFC2));
                  default:
                    return const Icon(Icons.flash_off, color: Colors.grey);
                }
              },
            ),
            iconSize: 20.0,
            onPressed: () => controller.toggleTorch(),
          ),
          IconButton(
            color: Colors.white,
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: controller,
              builder: (context, state, child) {
                switch (state.cameraDirection) {
                  case CameraFacing.front:
                    return const Icon(Icons.camera_front);
                  case CameraFacing.back:
                    return const Icon(Icons.camera_rear);
                  default:
                    return const Icon(Icons.camera_rear);
                }
              },
            ),
            iconSize: 20.0,
            onPressed: () => controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (_hasDetected || _isAiExtracting) return;
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String? code = barcodes.first.rawValue;
                if (code != null && code.isNotEmpty) {
                  _hasDetected = true;
                  Navigator.pop(context, code);
                }
              }
            },
          ),

          // Elegant scanning guidelines box
          Center(
            child: Container(
              width: 280,
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF00FFC2), width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Inquadra il codice a barre',
                    style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),

          // Horizontal red laser line
          Center(
            child: Container(
              width: 260,
              height: 2,
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withOpacity(0.5),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),

          // Pulsante scatto manuale con IA
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton(
                    heroTag: 'capture_barcode_fab',
                    backgroundColor: const Color(0xFF00FFC2),
                    onPressed: _isAiExtracting ? null : _captureAndExtractBarcode,
                    child: const Icon(Icons.camera_alt, color: Color(0xFF0F0F13)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Fai una foto se la scansione automatica fallisce',
                    style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          // Loading overlay when Gemini is extracting barcode
          if (_isAiExtracting)
            Container(
              color: Colors.black87,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF00FFC2)),
                    SizedBox(height: 16),
                    Text(
                      'Lettura codice a barre con IA...',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Gemini sta analizzando l\'immagine...',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

