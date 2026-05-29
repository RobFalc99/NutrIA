import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'dart:io';
import '../../providers/app_state.dart';
import '../../domain/models.dart';
import '../../data/remote/open_food_facts_service.dart';
import 'add_meal_screen.dart'; // Per riutilizzare BarcodeScannerScreen

class AlimentiScreen extends StatefulWidget {
  const AlimentiScreen({super.key});

  @override
  State<AlimentiScreen> createState() => _AlimentiScreenState();
}

class _AlimentiScreenState extends State<AlimentiScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _openFoodFactsService = OpenFoodFactsService();

  // Colori Premium Neon Dark
  static const accentCyan = Color(0xFF00FFC2);
  static const accentPink = Color(0xFFFF007F);
  static const bgDark = Color(0xFF0F0F13);
  static const bgCard = Color(0xFF16161D);

  // Tab Cerca
  final _searchController = TextEditingController();
  final _myFoodsSearchController = TextEditingController();
  List<Food> _searchResults = [];
  bool _isSearching = false;

  // Tab AI Singolo
  final _singleFoodAiController = TextEditingController();
  final _singleFoodGramsController = TextEditingController(text: '100');
  Food? _aiSingleFoodResult;
  bool _isSingleFoodAiLoading = false;
  String? _singleFoodAiError;

  // Speech to Text properties
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  String _dictationInitialText = "";
  String _dictationLastWords = "";

  // Meal selezionato per inserimento
  String _selectedMealTarget = 'Colazione';

  // Stato Scansione Tabella Nutrizionale (Macro Label)
  bool _isMacroScanning = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initSpeech();
  }

  void _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onError: (val) => debugPrint('Errore Speech: $val'),
        onStatus: (val) => debugPrint('Stato Speech: $val'),
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Errore inizializzazione Speech: $e");
    }
  }

  void _startListening() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      // Rumore/feedback acustico e tattile premium all'avvio
      try {
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.mediumImpact();
      } catch (e) {
        debugPrint("Feedback acustico non supportato: $e");
      }

      _dictationInitialText = _singleFoodAiController.text.trim();
      _dictationLastWords = "";

      setState(() {
        _isListening = true;
      });

      await _speechToText.listen(
        onResult: (result) {
          final words = result.recognizedWords.trim();
          if (words.isEmpty) return;

          setState(() {
            // Se le nuove parole riconosciute non iniziano con quelle registrate in precedenza,
            // significa che l'engine ha riavviato una frase a causa della pausa. Committiamo l'accumulo precedente!
            if (_dictationLastWords.isNotEmpty && !words.toLowerCase().startsWith(_dictationLastWords.toLowerCase())) {
              _dictationInitialText = _dictationInitialText.isEmpty
                  ? _dictationLastWords
                  : "$_dictationInitialText $_dictationLastWords";
            }

            _dictationLastWords = words;
            _singleFoodAiController.text = _dictationInitialText.isEmpty ? words : "$_dictationInitialText $words";

            if (result.finalResult) {
              _dictationInitialText = _singleFoodAiController.text.trim();
              _dictationLastWords = "";
            }
          });
        },
        localeId: 'it_IT',
        // Il microfono non si deve staccare in automatico
        listenFor: const Duration(minutes: 10),
        pauseFor: const Duration(seconds: 60),
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permesso microfono negato per la dettatura!')),
        );
      }
    }
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
    });
  }

  @override
  void dispose() {
    _speechToText.stop();
    _tabController.dispose();
    _searchController.dispose();
    _myFoodsSearchController.dispose();
    _singleFoodAiController.dispose();
    _singleFoodGramsController.dispose();
    super.dispose();
  }

  // --- AZIONI DI RICERCA ---
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
      debugPrint('Errore ricerca alimenti: $e');
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  // --- ANALISI AI SINGOLO ALIMENTO ---
  Future<void> _analyzeSingleFoodWithAi() async {
    final text = _singleFoodAiController.text.trim();
    if (text.isEmpty) return;

    final appState = context.read<AppState>();
    final service = appState.geminiService;

    if (service == null) {
      setState(() {
        _singleFoodAiError = 'Servizio AI non configurato. Inserisci la chiave API Gemini nel profilo.';
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
      if (food != null) {
        setState(() {
          _aiSingleFoodResult = food;
        });
      } else {
        setState(() {
          _singleFoodAiError = 'Impossibile identificare l\'alimento. Riprova con una descrizione più dettagliata.';
        });
      }
    } catch (e) {
      setState(() {
        _singleFoodAiError = 'Errore durante l\'analisi AI: $e';
      });
    } finally {
      setState(() {
        _isSingleFoodAiLoading = false;
      });
    }
  }

  // --- SCANSIONE BARCODE ---
  Future<void> _startBarcodeScan() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permesso fotocamera necessario per scansionare il barcode.')),
      );
      return;
    }

    final scannedBarcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
    );

    if (scannedBarcode != null && scannedBarcode.isNotEmpty) {
      setState(() {
        _isSearching = true;
        _searchResults = [];
      });

      try {
        final product = await _openFoodFactsService.getProductByBarcode(scannedBarcode);
        if (product != null) {
          _showAddQuantityDialog(product);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Nessun alimento trovato per il barcode: $scannedBarcode')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante la ricerca del barcode: $e')),
        );
      } finally {
        setState(() {
          _isSearching = false;
        });
      }
    }
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

    setState(() => _isMacroScanning = true);

    try {
      final bytes = await image.readAsBytes();
      final appState = context.read<AppState>();
      final service = appState.geminiService;
      if (service == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Servizio AI non configurato. Inserisci la chiave API Gemini nel profilo.')),
        );
        return;
      }

      final result = await service.analyzeMacroImage(bytes);
      if (result != null) {
        final String name = result['name'] ?? 'Etichetta Scansionata';
        final String? brand = result['brand'];
        final double calories = (result['caloriesPer100g'] as num?)?.toDouble() ?? 0.0;
        final double proteins = (result['proteinsPer100g'] as num?)?.toDouble() ?? 0.0;
        final double carbs = (result['carbsPer100g'] as num?)?.toDouble() ?? 0.0;
        final double fats = (result['fatsPer100g'] as num?)?.toDouble() ?? 0.0;
        final double fibers = (result['fibersPer100g'] as num?)?.toDouble() ?? 0.0;

        final food = Food(
          id: 'scanned_macro_${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          brand: brand,
          caloriesPer100g: calories,
          proteinsPer100g: proteins,
          carbsPer100g: carbs,
          fatsPer100g: fats,
          fibersPer100g: fibers,
          isCustom: true,
        );

        _showAddQuantityDialog(food);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile estrarre i valori. Riprova con un\'immagine più nitida.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore durante la scansione: $e')));
    } finally {
      setState(() => _isMacroScanning = false);
    }
  }

  // --- DIALOG DI INSERIMENTO QUANTITÀ & DIARIO ---
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

            return AlertDialog(
              backgroundColor: bgCard,
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
                    // Selettore Pasto Target
                    const Text('Seleziona Pasto:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedMealTarget,
                        dropdownColor: bgCard,
                        isExpanded: true,
                        underline: const SizedBox(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        items: ['Colazione', 'Pranzo', 'Cena', 'Spuntini'].map((meal) {
                          return DropdownMenuItem<String>(
                            value: meal,
                            child: Text(meal),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedMealTarget = val;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

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
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [50, 100, 150, 200, 250].map((g) {
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
                    final appState = context.read<AppState>();
                    appState.saveCustomFood(food);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Alimento salvato nei tuoi alimenti!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Salva nei Preferiti', style: TextStyle(color: accentCyan, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: amount <= 0 ? null : () {
                    final appState = context.read<AppState>();
                    appState.addMealItem(_selectedMealTarget, food, amount);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${food.name} (${amount.toInt()}g) aggiunto a $_selectedMealTarget!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentPink,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Aggiungi al Diario', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDialogMacroRow(String label, String value, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        title: const Text(
          'Sezione Alimenti 🍎',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: bgDark,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: accentCyan,
          unselectedLabelColor: Colors.white38,
          indicatorColor: accentCyan,
          tabs: const [
            Tab(icon: Icon(Icons.search), text: 'Cerca'),
            Tab(icon: Icon(Icons.psychology), text: 'AI Singolo'),
            Tab(icon: Icon(Icons.folder_shared), text: 'I Miei Alimenti'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSearchTab(),
          _buildAiTab(),
          _buildMyFoodsTab(),
        ],
      ),
    );
  }

  // --- TAB 1: RICERCA SINGOLO ALIMENTO ---
  Widget _buildSearchTab() {
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
                  backgroundColor: accentCyan,
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
                ? const Center(child: CircularProgressIndicator(color: accentCyan))
                : ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      if (localFiltered.isNotEmpty) ...[
                        _sectionHeader(Icons.cloud_done, 'Cibi Personali', accentCyan),
                        const SizedBox(height: 8),
                        ...localFiltered.map((food) => _buildFoodListTile(food, accentCyan)),
                        const SizedBox(height: 20),
                      ],
                      if (_searchResults.isNotEmpty) ...[
                        _sectionHeader(Icons.language, 'Risultati OpenFoodFacts', accentPink),
                        const SizedBox(height: 8),
                        ..._searchResults.map((food) => _buildFoodListTile(food, accentPink)),
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

  // --- TAB 2: INSERIMENTO CON PROMPT AI ---
  Widget _buildAiTab() {
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
              style: ElevatedButton.styleFrom(backgroundColor: accentPink, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
            'L\'IA analizzerà il testo, identificherà l\'alimento e stimerà i suoi valori nutrizionali riferiti a 100g.',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _singleFoodAiController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Es. "una mela rossa media", "120g di petto di pollo cotto", "due cucchiai di olio d\'oliva"...',
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
              filled: true,
              fillColor: Colors.white.withOpacity(0.03),
              suffixIcon: IconButton(
                icon: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: _isListening ? const Color(0xFFFF007F) : const Color(0xFF00FFC2),
                ),
                onPressed: () {
                  if (_isListening) {
                    _stopListening();
                  } else {
                    _startListening();
                  }
                },
                tooltip: 'Dettatura vocale 🎙️',
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: accentCyan, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: _isSingleFoodAiLoading ? null : _analyzeSingleFoodWithAi,
            style: ElevatedButton.styleFrom(
              backgroundColor: accentCyan,
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
                border: Border.all(color: accentCyan.withOpacity(0.15)),
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
                          color: accentCyan.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_aiSingleFoodResult!.caloriesPer100g.toInt()} kcal/100g',
                          style: const TextStyle(color: accentCyan, fontWeight: FontWeight.bold, fontSize: 12),
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
                      _buildMiniMacro('Prot', '${_aiSingleFoodResult!.proteinsPer100g.toStringAsFixed(1)}g', accentPink),
                      _buildMiniMacro('Carb', '${_aiSingleFoodResult!.carbsPer100g.toStringAsFixed(1)}g', const Color(0xFFFFD700)),
                      _buildMiniMacro('Gras', '${_aiSingleFoodResult!.fatsPer100g.toStringAsFixed(1)}g', const Color(0xFF00E676)),
                      _buildMiniMacro('Fibr', '${_aiSingleFoodResult!.fibersPer100g.toStringAsFixed(1)}g', Colors.cyan),
                    ],
                  ),
                  const SizedBox(height: 20),

                  const Divider(color: Colors.white10),
                  const SizedBox(height: 12),

                  // Tasto per aggiungerlo direttamente
                  ElevatedButton.icon(
                    onPressed: () => _showAddQuantityDialog(_aiSingleFoodResult!),
                    icon: const Icon(Icons.add, color: Colors.white, size: 18),
                    label: const Text('Usa questo alimento', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentPink,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_singleFoodAiError != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: accentPink.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accentPink.withOpacity(0.2)),
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

  void _deleteFood(Food food) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bgCard,
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
                    backgroundColor: accentPink,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Elimina', style: TextStyle(color: accentPink, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- TAB 3: I MIEI ALIMENTI (DETTAGLI E STRUMENTI) ---
  Widget _buildMyFoodsTab() {
    final appState = context.watch<AppState>();

    // Recupera la lista di alimenti personali (customFoods) dell'utente
    final customFoods = appState.customFoods;
    final myFoodsQuery = _myFoodsSearchController.text.trim().toLowerCase();

    final filteredCustomFoods = myFoodsQuery.isEmpty
        ? customFoods
        : customFoods.where((food) => food.name.toLowerCase().contains(myFoodsQuery)).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sezione Strumenti Rapidi (Barcode / Scanner Tabella IA)
          const Text('Strumenti di Acquisizione:', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _startBarcodeScan,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.04)),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.qr_code_scanner, color: accentCyan, size: 28),
                        SizedBox(height: 8),
                        Text('Scanner Barcode', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        SizedBox(height: 2),
                        Text('Cerca barcode OFF o IA', style: TextStyle(color: Colors.white38, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: _isMacroScanning ? null : _scanMacroLabelWithAi,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.04)),
                    ),
                    child: Column(
                      children: [
                        _isMacroScanning
                            ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2, color: accentPink))
                            : const Icon(Icons.camera_alt, color: accentPink, size: 28),
                        const SizedBox(height: 8),
                        const Text('Scanner Tabella IA', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        const Text('Estrai macro da foto', style: TextStyle(color: Colors.white38, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),

          const Text('Alimenti Salvati / Dettagli Personali:', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          if (customFoods.isNotEmpty) ...[
            TextField(
              controller: _myFoodsSearchController,
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
                suffixIcon: _myFoodsSearchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54, size: 16),
                        onPressed: () {
                          _myFoodsSearchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
          ],

          Expanded(
            child: filteredCustomFoods.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open, size: 48, color: Colors.white.withOpacity(0.1)),
                        const SizedBox(height: 8),
                        Text(
                          customFoods.isEmpty
                              ? 'Nessun alimento personale salvato.\nSalva un alimento da Cerca o AI per vederlo qui.'
                              : 'Nessun risultato trovato nei tuoi cibi salvati.',
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: filteredCustomFoods.length,
                    itemBuilder: (context, index) {
                      final food = filteredCustomFoods[index];
                      final isPreset = food.id == 'online_1' || food.id == 'online_2';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.04)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          title: Text(food.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text(
                            '${food.brand ?? "Generico"} · ${food.caloriesPer100g.toInt()} kcal/100g',
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.info_outline, color: accentCyan, size: 20),
                                onPressed: () => _showFoodInfoSheet(food),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle, color: accentPink, size: 20),
                                onPressed: () => _showAddQuantityDialog(food),
                              ),
                              if (!isPreset)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.white30, size: 20),
                                  onPressed: () => _deleteFood(food),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- COMPONENTI UI RIUTILIZZABILI ---
  Widget _sectionHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 6),
        Text(title, style: TextStyle(color: color.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildFoodListTile(Food food, Color color) {
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
            IconButton(
              icon: Icon(Icons.info_outline, color: color.withOpacity(0.7), size: 20),
              onPressed: () => _showFoodInfoSheet(food),
            ),
            IconButton(
              icon: Icon(Icons.add_circle, color: color, size: 20),
              onPressed: () => _showAddQuantityDialog(food),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniMacro(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildMacroInfoRow(String label, String value, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  void _showFoodInfoSheet(Food food) {
    showModalBottomSheet(
      context: context,
      backgroundColor: bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 20),
                Text(food.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                if (food.brand != null && food.brand!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(food.brand!, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                const Text('Valori nutrizionali per 100g:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _buildMacroInfoRow('Calorie', '${food.caloriesPer100g.toStringAsFixed(1)} kcal', accentCyan, Colors.white.withOpacity(0.04)),
                _buildMacroInfoRow('Proteine', '${food.proteinsPer100g.toStringAsFixed(1)} g', accentPink, Colors.white.withOpacity(0.02)),
                _buildMacroInfoRow('Carboidrati', '${food.carbsPer100g.toStringAsFixed(1)} g', const Color(0xFFFFD700), Colors.white.withOpacity(0.04)),
                _buildMacroInfoRow('Grassi', '${food.fatsPer100g.toStringAsFixed(1)} g', const Color(0xFF00E676), Colors.white.withOpacity(0.02)),
                _buildMacroInfoRow('Fibre', '${food.fibersPer100g.toStringAsFixed(1)} g', Colors.cyan, Colors.white.withOpacity(0.04)),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}
