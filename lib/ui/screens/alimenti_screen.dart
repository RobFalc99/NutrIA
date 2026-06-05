import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'dart:io';
import '../../providers/app_state.dart';
import '../../providers/translations.dart';
import '../../domain/models.dart';
import '../../data/remote/open_food_facts_service.dart';
import 'add_meal_screen.dart'; // Per riutilizzare BarcodeScannerScreen

class AlimentiScreen extends StatefulWidget {
  final String? initialMealTarget;
  final bool isActive;
  const AlimentiScreen({super.key, this.initialMealTarget, this.isActive = true});

  @override
  State<AlimentiScreen> createState() => _AlimentiScreenState();
}

class _AlimentiScreenState extends State<AlimentiScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _openFoodFactsService = OpenFoodFactsService();
  bool _tabIndexInitialized = false;

  // Colori Premium Neon Dark
  static const accentCyan = Color(0xFF00FFC2);
  static const accentPink = Color(0xFFFF007F);
  static const bgDark = Color(0xFF0F0F13);
  static const bgCard = Color(0xFF16161D);

  // Tab Cerca
  final _searchController = TextEditingController();
  final _myFoodsSearchController = TextEditingController();
  final _brandController = TextEditingController();
  bool _showAdvancedSearch = false;
  List<Food> _searchResults = [];
  bool _isSearching = false;

  // Tab Cronologia
  final _historySearchController = TextEditingController();

  // Tab AI Singolo / Popup
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
    _tabController = TabController(length: 4, vsync: this);
    _initSpeech();
    if (widget.initialMealTarget != null) {
      _selectedMealTarget = widget.initialMealTarget!;
    }
  }

  @override
  void didUpdateWidget(AlimentiScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      // Screen became active, unfocus any active inputs/buttons to avoid keyboard or tooltip/focus overlays
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
      });
    }
  }

  void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/thinking.png',
                  height: 120,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: accentCyan),
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr(message),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, height: 1.4),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onError: (val) => debugPrint('Errore Speech: $val'),
        onStatus: (val) {
          debugPrint('Stato Speech: $val');
          if (val == 'notListening' || val == 'done') {
            setState(() {
              _isListening = false;
            });
          }
        },
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
            if (_dictationLastWords.isNotEmpty && !words.toLowerCase().startsWith(_dictationLastWords.toLowerCase())) {
              _dictationInitialText = _dictationInitialText.isEmpty
                  ? _dictationLastWords
                  : "$_dictationInitialText $_dictationLastWords";
            }
            _dictationLastWords = words;

            _singleFoodAiController.text = _dictationInitialText.isEmpty
                ? words
                : "$_dictationInitialText $words";

            if (result.finalResult) {
              _dictationInitialText = _singleFoodAiController.text.trim();
              _dictationLastWords = "";
            }
          });
        },
        localeId: 'it_IT',
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
    _brandController.dispose();
    _historySearchController.dispose();
    _singleFoodAiController.dispose();
    _singleFoodGramsController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    var query = _searchController.text.trim();
    if (query.isEmpty) return;

    final brand = _brandController.text.trim();
    if (_showAdvancedSearch && brand.isNotEmpty) {
      query = '$query $brand';
    }

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

  Future<ImageSource?> _showImageSourceDialog() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: accentCyan),
                title: const Text('Fotocamera', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: accentCyan),
                title: const Text('Galleria', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- SCANSIONE BARCODE ---
  Future<void> _startBarcodeScan() async {
    final source = await _showImageSourceDialog();
    if (source == null) return;

    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permesso fotocamera necessario per scansionare il barcode.')),
        );
        return;
      }
    }

    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 80);
    if (image == null) return;

    _showLoadingDialog(context, 'Lettura del codice a barre con l\'IA...');

    try {
      final bytes = await image.readAsBytes();
      final appState = context.read<AppState>();
      final service = appState.geminiService;
      if (service == null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Servizio AI non configurato. Inserisci la chiave API Gemini nel profilo.')),
        );
        return;
      }

      final scannedBarcode = await service.extractBarcodeFromImage(bytes);
      Navigator.pop(context);

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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile estrarre il codice a barre. Inquadralo da vicino e riprova.')),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante la scansione del barcode: $e')),
      );
    }
  }

  // --- SCANSIONE ETICHETTA NUTRIZIONALE CON IA ---
  Future<void> _scanMacroLabelWithAi() async {
    final source = await _showImageSourceDialog();
    if (source == null) return;

    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permesso fotocamera necessario per scansionare l\'etichetta.')),
        );
        return;
      }
    }

    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 80);
    if (image == null) return;

    _showLoadingDialog(context, 'Analisi tabella nutrizionale con l\'IA...');
    setState(() => _isMacroScanning = true);

    try {
      final bytes = await image.readAsBytes();
      final appState = context.read<AppState>();
      final service = appState.geminiService;
      if (service == null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Servizio AI non configurato. Inserisci la chiave API Gemini nel profilo.')),
        );
        return;
      }

      final result = await service.analyzeMacroImage(bytes);
      Navigator.pop(context);

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
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore durante la scansione: $e')));
    } finally {
      setState(() => _isMacroScanning = false);
    }
  }

  // --- DIALOG DI INSERIMENTO QUANTITÀ & DIARIO ---
  void _showAddQuantityDialog(Food food, {bool showSaveFavorite = true}) {
    double amount = food.estimatedAmountGrams ?? 100.0;
    final initialText = amount == amount.toInt() ? amount.toInt().toString() : amount.toStringAsFixed(1);
    final textController = TextEditingController(text: initialText);
    final nameController = TextEditingController(text: food.name);
    final brandController = TextEditingController(text: food.brand ?? '');

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
              insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text(
                'Inserimento Alimento',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Nome Alimento',
                        labelStyle: const TextStyle(color: Colors.white60),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.03),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: brandController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Marca / Brand',
                        labelStyle: const TextStyle(color: Colors.white60),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.03),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: textController,
                      keyboardType: TextInputType.number,
                      autofocus: false,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Quantità (g)',
                        labelStyle: const TextStyle(color: Colors.white60),
                        suffixText: 'g',
                        suffixStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.04),
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
                      children: [5, 10, 25, 50, 100, 150, 200, 250].map((g) {
                        return ActionChip(
                          label: Text('${g}g', style: const TextStyle(color: Colors.white, fontSize: 11)),
                          backgroundColor: Colors.white.withValues(alpha: 0.06),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            textController.text = g.toString();
                            setDialogState(() { amount = g.toDouble(); });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    _buildCompactMacroVisualizer(
                      kcal: calories,
                      proteins: proteins,
                      carbs: carbs,
                      fats: fats,
                      fibers: fibers,
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (showSaveFavorite)
                      TextButton.icon(
                        onPressed: () {
                          final finalName = nameController.text.trim();
                          if (finalName.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Inserisci un nome per l\'alimento'), backgroundColor: accentPink, behavior: SnackBarBehavior.floating),
                            );
                            return;
                          }
                          final finalBrand = brandController.text.trim().isEmpty ? null : brandController.text.trim();
                          
                          final updatedFood = Food(
                            id: food.id,
                            name: finalName,
                            brand: finalBrand,
                            caloriesPer100g: food.caloriesPer100g,
                            proteinsPer100g: food.proteinsPer100g,
                            carbsPer100g: food.carbsPer100g,
                            fatsPer100g: food.fatsPer100g,
                            fibersPer100g: food.fibersPer100g,
                            isCustom: food.isCustom,
                            isOnline: food.isOnline,
                          );

                          final appState = context.read<AppState>();
                          appState.saveCustomFood(updatedFood);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Alimento salvato nei tuoi alimenti!'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.bookmark_add_rounded, color: accentCyan, size: 18),
                        label: const Text('Salva', style: TextStyle(color: accentCyan, fontWeight: FontWeight.bold, fontSize: 12)),
                      )
                    else
                      const SizedBox.shrink(),
                    ElevatedButton(
                      onPressed: amount <= 0 ? null : () {
                        final finalName = nameController.text.trim();
                        if (finalName.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Inserisci un nome per l\'alimento'), backgroundColor: accentPink, behavior: SnackBarBehavior.floating),
                          );
                          return;
                        }
                        final finalBrand = brandController.text.trim().isEmpty ? null : brandController.text.trim();
                        
                        final updatedFood = Food(
                          id: food.id,
                          name: finalName,
                          brand: finalBrand,
                          caloriesPer100g: food.caloriesPer100g,
                          proteinsPer100g: food.proteinsPer100g,
                          carbsPer100g: food.carbsPer100g,
                          fatsPer100g: food.fatsPer100g,
                          fibersPer100g: food.fibersPer100g,
                          isCustom: food.isCustom,
                          isOnline: food.isOnline,
                        );

                        if (widget.initialMealTarget != null) {
                          final appState = context.read<AppState>();
                          appState.addMealItem(widget.initialMealTarget!, updatedFood, amount);
                          
                          Navigator.pop(context); // Chiude il quantitativo

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${updatedFood.name} (${amount.toInt()}g) aggiunto a ${widget.initialMealTarget}!'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } else {
                          _showSelectMealAndAddPopup(updatedFood, amount);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentPink,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: const Text('Aggiungi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSelectMealAndAddPopup(Food food, double amount) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text(
            'Seleziona Pasto',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['Colazione', 'Pranzo', 'Cena', 'Spuntini'].map((meal) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final appState = this.context.read<AppState>();
                      appState.addMealItem(meal, food, amount);

                      Navigator.pop(context); // Chiude il selettore
                      Navigator.pop(this.context); // Chiude il quantitativo

                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text('${food.name} (${amount.toInt()}g) aggiunto a $meal!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.04),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          meal == 'Colazione'
                              ? Icons.wb_sunny_rounded
                              : meal == 'Pranzo'
                                  ? Icons.lunch_dining_rounded
                                  : meal == 'Cena'
                                      ? Icons.dinner_dining_rounded
                                      : Icons.bakery_dining_rounded,
                          color: accentCyan,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(meal, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildCompactMacroVisualizer({
    required double kcal,
    required double proteins,
    required double carbs,
    required double fats,
    required double fibers,
  }) {
    final totalGrams = proteins + carbs + fats;
    final pctProt = totalGrams > 0 ? (proteins / totalGrams) : 0.0;
    final pctCarb = totalGrams > 0 ? (carbs / totalGrams) : 0.0;
    final pctFat = totalGrams > 0 ? (fats / totalGrams) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Calorie sopra
        Center(
          child: Column(
            children: [
              Text(
                kcal.toStringAsFixed(1),
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
              const Text(
                'KCAL',
                style: TextStyle(color: accentCyan, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Barra orizzontale in percentuale
        if (totalGrams > 0)
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  if (proteins > 0)
                    Expanded(
                      flex: (pctProt * 1000).toInt(),
                      child: Container(color: accentPink),
                    ),
                  if (carbs > 0)
                    Expanded(
                      flex: (pctCarb * 1000).toInt(),
                      child: Container(color: const Color(0xFFFFD700)),
                    ),
                  if (fats > 0)
                    Expanded(
                      flex: (pctFat * 1000).toInt(),
                      child: Container(color: const Color(0xFF00E676)),
                    ),
                ],
              ),
            ),
          )
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 12,
              color: Colors.white.withOpacity(0.08),
            ),
          ),
        const SizedBox(height: 12),

        // Legenda e valori sotto
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildCompactLegendItem('Pro', '${proteins.toStringAsFixed(1)}g', '${(pctProt * 100).toInt()}%', accentPink),
            _buildCompactLegendItem('Carb', '${carbs.toStringAsFixed(1)}g', '${(pctCarb * 100).toInt()}%', const Color(0xFFFFD700)),
            _buildCompactLegendItem('Grass', '${fats.toStringAsFixed(1)}g', '${(pctFat * 100).toInt()}%', const Color(0xFF00E676)),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(color: Colors.white10),
        const SizedBox(height: 6),

        // Fibre sotto
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.eco, color: Colors.cyan, size: 14),
              const SizedBox(width: 4),
              Text(
                'Fibre: ${fibers.toStringAsFixed(1)}g',
                style: const TextStyle(color: Colors.cyan, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactLegendItem(String label, String grams, String pct, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 2),
        Text('$grams ($pct)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
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
    final appState = context.watch<AppState>();
    if (widget.isActive && appState.currentUser != null && !_tabIndexInitialized) {
      _tabIndexInitialized = true;
      final targetIndex = appState.currentUser!.defaultAlimentiTab;
      if (_tabController.index != targetIndex) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _tabController.index = targetIndex;
          }
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
      });
    }
    final hasMealTarget = widget.initialMealTarget != null;

    return TooltipTheme(
      data: const TooltipThemeData(
        waitDuration: Duration(days: 365),
        showDuration: Duration.zero,
      ),
      child: Scaffold(
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
              Tab(icon: Icon(Icons.bookmark), text: 'Salvati'),
              Tab(icon: Icon(Icons.language), text: 'Web'),
              Tab(icon: Icon(Icons.add_circle), text: 'Nuovo'),
              Tab(icon: Icon(Icons.history), text: 'Cronologia'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (hasMealTarget)
              Container(
                color: accentPink.withValues(alpha: 0.1),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.restaurant_menu, color: accentPink, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Inserimento in corso per: ',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      widget.initialMealTarget!,
                      style: const TextStyle(color: accentCyan, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentPink.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.initialMealTarget!.toUpperCase(),
                        style: const TextStyle(color: accentPink, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMyFoodsTab(),
                  _buildSearchTab(),
                  _buildNewFoodTab(),
                  _buildHistoryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 2: RICERCA WEB (OPENFOODFACTS) ---
  Widget _buildSearchTab() {
    final query = _searchController.text.trim().toLowerCase();

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
                    hintText: 'Cerca alimento su internet...',
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
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _showAdvancedSearch = !_showAdvancedSearch),
                icon: Icon(_showAdvancedSearch ? Icons.expand_less : Icons.expand_more, color: accentCyan, size: 16),
                label: Text(
                  _showAdvancedSearch ? 'Nascondi Ricerca Avanzata' : 'Ricerca Avanzata',
                  style: const TextStyle(color: accentCyan, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
              ),
            ],
          ),
          if (_showAdvancedSearch) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.04)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filtra per Marca:', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _brandController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Esempio: Barilla, Coop, Buitoni...',
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.02),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator(color: accentCyan))
                : ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      if (_searchResults.isNotEmpty) ...[
                        _sectionHeader(Icons.language, 'Risultati Web / OpenFoodFacts', accentPink),
                        const SizedBox(height: 8),
                        ..._searchResults.map((food) => _buildFoodListTile(food, accentPink)),
                      ] else ...[
                        const SizedBox(height: 80),
                        const Center(
                          child: Column(
                            children: [
                              Icon(Icons.language, size: 48, color: Colors.white24),
                              SizedBox(height: 10),
                              Text(
                                'Digita il nome di un alimento o marca.\nPremi Enter o il tasto "Cerca 🔍" per cercare su internet.',
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

  // --- TAB 3: NUOVO ACQUISIZIONE E STIMA ---
  Widget _buildNewFoodTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // 1. Tabella Nutrizionale Card
          _buildNewFoodActionCard(
            title: 'Tabella Nutrizionale 📷',
            description: 'Scatta una foto alla tabella nutrizionale sul retro della confezione per estrarre i valori con l\'IA.',
            color: accentPink,
            icon: Icons.camera_alt_outlined,
            onTap: _scanMacroLabelWithAi,
          ),
          const SizedBox(height: 16),

          // 2. Barcode Card
          _buildNewFoodActionCard(
            title: 'Codice a Barre 📷',
            description: 'Inquadra il barcode del prodotto con la fotocamera per cercarlo istantaneamente nel database.',
            color: accentCyan,
            icon: Icons.qr_code_scanner_rounded,
            onTap: _startBarcodeScan,
          ),
          const SizedBox(height: 16),

          // 3. IA Card
          _buildNewFoodActionCard(
            title: 'Stima con IA 🪄',
            description: 'Descrivi a voce o per testo l\'alimento per calcolare la stima dei valori con Gemini.',
            color: Colors.purpleAccent,
            icon: Icons.psychology_outlined,
            onTap: _showSingleFoodAiPopup,
          ),
          const SizedBox(height: 16),

          // 4. Inserimento Manuale Card
          _buildNewFoodActionCard(
            title: 'Inserimento Manuale ✍️',
            description: 'Inserisci manualmente il nome, marca e tutti i macronutrienti per salvare l\'alimento.',
            color: const Color(0xFF00FFC2),
            icon: Icons.edit_note_rounded,
            onTap: _showManualFoodDialog,
          ),
        ],
      ),
    );
  }

  void _showManualFoodDialog() {
    final nomeController = TextEditingController();
    final marcaController = TextEditingController();
    final kcalController = TextEditingController();
    final protController = TextEditingController();
    final carbController = TextEditingController();
    final fatController = TextEditingController();
    final fibController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: bgCard,
          insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: accentCyan, size: 24),
              SizedBox(width: 8),
              Text('Inserimento Manuale', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nome Alimento', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: nomeController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: _buildManualInputDecoration('Nome alimento (es. Petto di pollo)'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Marca', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: marcaController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: _buildManualInputDecoration('Marca (es. AIA, Coop) - opzionale'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Kcal / 100g', style: TextStyle(color: accentCyan, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: kcalController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: _buildManualInputDecoration('Kcal per 100g'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Proteine / 100g', style: TextStyle(color: accentPink, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: protController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: _buildManualInputDecoration('Pro (g) / 100g'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Carboidrati / 100g', style: TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: carbController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: _buildManualInputDecoration('Carb (g) / 100g'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Grassi / 100g', style: TextStyle(color: Color(0xFF00E676), fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: fatController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: _buildManualInputDecoration('Grass (g) / 100g'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Fibre / 100g', style: TextStyle(color: Colors.cyan, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: fibController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: _buildManualInputDecoration('Fibre (g) per 100g - opzionale'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                final nome = nomeController.text.trim();
                if (nome.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Inserisci almeno il nome dell\'alimento'), backgroundColor: accentPink, behavior: SnackBarBehavior.floating),
                  );
                  return;
                }

                final kcal = double.tryParse(kcalController.text) ?? 0.0;
                final prot = double.tryParse(protController.text) ?? 0.0;
                final carb = double.tryParse(carbController.text) ?? 0.0;
                final fat = double.tryParse(fatController.text) ?? 0.0;
                final fib = double.tryParse(fibController.text) ?? 0.0;

                final appState = context.read<AppState>();
                final customFood = Food(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nome,
                  brand: marcaController.text.trim().isEmpty ? null : marcaController.text.trim(),
                  caloriesPer100g: kcal,
                  proteinsPer100g: prot,
                  carbsPer100g: carb,
                  fatsPer100g: fat,
                  fibersPer100g: fib,
                  isCustom: true,
                );

                appState.saveCustomFood(customFood);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('"$nome" salvato con successo!'), behavior: SnackBarBehavior.floating),
                );

                Navigator.pop(context);

                if (widget.initialMealTarget != null) {
                  _showAddQuantityDialog(customFood, showSaveFavorite: false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentCyan,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                widget.initialMealTarget != null ? 'Salva e Aggiungi' : 'Salva',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showEditFoodDialog(Food food) {
    final nomeController = TextEditingController(text: food.name);
    final marcaController = TextEditingController(text: food.brand ?? '');
    final kcalController = TextEditingController(text: food.caloriesPer100g.toStringAsFixed(1));
    final protController = TextEditingController(text: food.proteinsPer100g.toStringAsFixed(1));
    final carbController = TextEditingController(text: food.carbsPer100g.toStringAsFixed(1));
    final fatController = TextEditingController(text: food.fatsPer100g.toStringAsFixed(1));
    final fibController = TextEditingController(text: food.fibersPer100g.toStringAsFixed(1));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: bgCard,
          insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.edit_rounded, color: accentCyan, size: 24),
              SizedBox(width: 8),
              Text('Modifica Alimento', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nome Alimento', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: nomeController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: _buildManualInputDecoration('Nome alimento'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Marca', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: marcaController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: _buildManualInputDecoration('Marca - opzionale'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Kcal / 100g', style: TextStyle(color: accentCyan, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: kcalController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: _buildManualInputDecoration('Kcal'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Proteine / 100g', style: TextStyle(color: accentPink, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: protController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: _buildManualInputDecoration('Pro (g)'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Carboidrati / 100g', style: TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: carbController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: _buildManualInputDecoration('Carb (g)'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Grassi / 100g', style: TextStyle(color: Color(0xFF00E676), fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: fatController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: _buildManualInputDecoration('Grass (g)'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Fibre / 100g', style: TextStyle(color: Colors.cyan, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: fibController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: _buildManualInputDecoration('Fibre (g)'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                final nome = nomeController.text.trim();
                if (nome.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Inserisci almeno il nome dell\'alimento'), backgroundColor: accentPink, behavior: SnackBarBehavior.floating),
                  );
                  return;
                }

                final kcal = double.tryParse(kcalController.text) ?? 0.0;
                final prot = double.tryParse(protController.text) ?? 0.0;
                final carb = double.tryParse(carbController.text) ?? 0.0;
                final fat = double.tryParse(fatController.text) ?? 0.0;
                final fib = double.tryParse(fibController.text) ?? 0.0;

                final appState = context.read<AppState>();
                final customFood = Food(
                  id: food.id,
                  name: nome,
                  brand: marcaController.text.trim().isEmpty ? null : marcaController.text.trim(),
                  caloriesPer100g: kcal,
                  proteinsPer100g: prot,
                  carbsPer100g: carb,
                  fatsPer100g: fat,
                  fibersPer100g: fib,
                  isCustom: true,
                );

                appState.saveCustomFood(customFood);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('"$nome" modificato con successo!'), behavior: SnackBarBehavior.floating),
                );

                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentCyan,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text('Salva', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  InputDecoration _buildManualInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
      filled: true,
      fillColor: Colors.white.withOpacity(0.03),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  Widget _buildNewFoodActionCard({
    required String title,
    required String description,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.4),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white30, size: 20),
          ],
        ),
      ),
    );
  }

  // --- POPUP DIALOG: STIMA IA ALIMENTO ---
  void _showSingleFoodAiPopup() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final appState = context.watch<AppState>();
            final hasKey = appState.currentUser?.geminiApiKey != null;

            return Dialog(
              backgroundColor: bgCard,
              insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.psychology, color: accentCyan, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'Stima con IA 🪄',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                       if (!hasKey) ...[
                        Image.asset(
                          'assets/avviso.png',
                          height: 100,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.tr('Assistente AI Disattivato'),
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.tr('Inserisci la tua API Key Gemini nel profilo per abilitare l\'analisi AI degli alimenti.'),
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/profile');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentPink,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.settings, color: Colors.white, size: 16),
                          label: Text(context.tr('Vai al Profilo'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ] else ...[
                        const Text(
                          'Descrivi l\'alimento singolo da inserire:',
                          style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'L\'IA analizzerà il testo, identificherà l\'alimento e stimerà i suoi valori nutrizionali riferiti a 100g.',
                          style: TextStyle(color: Colors.white38, fontSize: 10),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _singleFoodAiController,
                          maxLines: 3,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Es. "una mela rossa media", "petto di pollo cotto", "due cucchiai di olio d\'oliva"...',
                            hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.03),
                            suffixIcon: SizedBox(
                              width: 40,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Text(
                                      'C',
                                      style: TextStyle(
                                        color: accentPink,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    onPressed: () {
                                      setDialogState(() {
                                        _singleFoodAiController.clear();
                                        _aiSingleFoodResult = null;
                                        _singleFoodAiError = null;
                                      });
                                    },
                                    tooltip: 'Cancella',
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      _isListening ? Icons.mic : Icons.mic_none,
                                      color: _isListening ? const Color(0xFFFF007F) : const Color(0xFF00FFC2),
                                    ),
                                    onPressed: () {
                                      if (_isListening) {
                                        _stopListeningWithState(setDialogState);
                                      } else {
                                        _startListeningWithState(setDialogState);
                                      }
                                    },
                                    tooltip: 'Dettatura vocale 🎙️',
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                  ),
                                ],
                              ),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: accentCyan, width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _isSingleFoodAiLoading
                              ? null
                              : () => _analyzeSingleFoodWithAiWithState(setDialogState),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentCyan,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: _isSingleFoodAiLoading
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F0F13)))
                              : const Icon(Icons.auto_awesome, color: Color(0xFF0F0F13), size: 16),
                          label: Text(
                            _isSingleFoodAiLoading ? 'Identificazione alimento...' : 'Estrai Alimento Singolo 🪄',
                            style: const TextStyle(color: Color(0xFF0F0F13), fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_isSingleFoodAiLoading) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.02),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.04)),
                            ),
                            child: Column(
                              children: [
                                Image.asset(
                                  'assets/thinking.png',
                                  height: 100,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: 12),
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: accentCyan),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  context.tr('Sto identificando l\'alimento con l\'IA...'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ] else if (_aiSingleFoodResult != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.02),
                              borderRadius: BorderRadius.circular(16),
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
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          if (_aiSingleFoodResult!.brand != null && _aiSingleFoodResult!.brand!.isNotEmpty)
                                            Text(
                                              _aiSingleFoodResult!.brand!,
                                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: accentCyan.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${_aiSingleFoodResult!.caloriesPer100g.toInt()} kcal/100g',
                                        style: const TextStyle(color: accentCyan, fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Text('Valori per 100g stimati:', style: TextStyle(color: Colors.white54, fontSize: 10)),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildMiniMacro('Prot', '${_aiSingleFoodResult!.proteinsPer100g.toStringAsFixed(1)}g', accentPink),
                                    _buildMiniMacro('Carb', '${_aiSingleFoodResult!.carbsPer100g.toStringAsFixed(1)}g', const Color(0xFFFFD700)),
                                    _buildMiniMacro('Gras', '${_aiSingleFoodResult!.fatsPer100g.toStringAsFixed(1)}g', const Color(0xFF00E676)),
                                    _buildMiniMacro('Fibr', '${_aiSingleFoodResult!.fibersPer100g.toStringAsFixed(1)}g', Colors.cyan),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _showAddQuantityDialog(_aiSingleFoodResult!);
                                  },
                                  icon: const Icon(Icons.add, color: Colors.white, size: 16),
                                  label: const Text('Usa questo alimento', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accentPink,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (_singleFoodAiError != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: accentPink.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: accentPink.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                Image.asset(
                                  'assets/avviso.png',
                                  height: 48,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    context.tr(_singleFoodAiError!),
                                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _startListeningWithState(StateSetter setDialogState) async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      try {
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.mediumImpact();
      } catch (e) {
        debugPrint("Feedback acustico non supportato: $e");
      }

      _dictationInitialText = _singleFoodAiController.text.trim();
      _dictationLastWords = "";

      setDialogState(() {
        _isListening = true;
      });

      await _speechToText.listen(
        onResult: (result) {
          final words = result.recognizedWords.trim();
          if (words.isEmpty) return;

          setDialogState(() {
            if (_dictationLastWords.isNotEmpty && !words.toLowerCase().startsWith(_dictationLastWords.toLowerCase())) {
              _dictationInitialText = _dictationInitialText.isEmpty
                  ? _dictationLastWords
                  : "$_dictationInitialText $_dictationLastWords";
            }
            _dictationLastWords = words;

            _singleFoodAiController.text = _dictationInitialText.isEmpty
                ? words
                : "$_dictationInitialText $words";

            if (result.finalResult) {
              _dictationInitialText = _singleFoodAiController.text.trim();
              _dictationLastWords = "";
            }
          });
        },
        localeId: 'it_IT',
        listenFor: const Duration(minutes: 10),
        pauseFor: const Duration(seconds: 60),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permesso microfono negato per la dettatura!')),
      );
    }
  }

  void _stopListeningWithState(StateSetter setDialogState) async {
    await _speechToText.stop();
    setDialogState(() {
      _isListening = false;
    });
  }

  Future<void> _analyzeSingleFoodWithAiWithState(StateSetter setDialogState) async {
    final text = _singleFoodAiController.text.trim();
    if (text.isEmpty) return;

    final appState = context.read<AppState>();
    final service = appState.geminiService;

    if (service == null) {
      setDialogState(() {
        _singleFoodAiError = 'Servizio AI non configurato. Inserisci la chiave API Gemini nel profilo.';
      });
      return;
    }

    setDialogState(() {
      _isSingleFoodAiLoading = true;
      _aiSingleFoodResult = null;
      _singleFoodAiError = null;
    });

    try {
      final food = await service.analyzeSingleFood(text);
      if (food != null) {
        setDialogState(() {
          _aiSingleFoodResult = food;
        });
      } else {
        setDialogState(() {
          _singleFoodAiError = 'Impossibile identificare l\'alimento. Riprova con una descrizione più dettagliata.';
        });
      }
    } catch (e) {
      setDialogState(() {
        _singleFoodAiError = 'Errore durante l\'elaborazione: $e';
      });
    } finally {
      setDialogState(() {
        _isSingleFoodAiLoading = false;
      });
    }
  }

  // --- TAB 4: CRONOLOGIA ---
  Widget _buildHistoryTab() {
    return FutureBuilder<List<Food>>(
      future: context.read<AppState>().getFoodHistory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: accentCyan));
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

        final query = _historySearchController.text.trim().toLowerCase();
        final filteredList = query.isEmpty
            ? list
            : list.where((food) => food.name.toLowerCase().contains(query)).toList();

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _historySearchController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                onChanged: (val) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Cerca nella cronologia...',
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 18),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.03),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  suffixIcon: _historySearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54, size: 16),
                          onPressed: () {
                            _historySearchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: filteredList.isEmpty
                    ? const Center(
                        child: Text(
                          'Nessun risultato trovato nella cronologia.',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) => _buildFoodListTile(filteredList[index], accentCyan),
                      ),
              ),
            ],
          ),
        );
      },
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
          const Text('Alimenti Salvati:', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
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
                                icon: const Icon(Icons.edit_rounded, color: accentCyan, size: 18),
                                onPressed: () => _showEditFoodDialog(food),
                              ),
                              IconButton(
                                icon: const Icon(Icons.info_outline, color: accentCyan, size: 20),
                                onPressed: () => _showFoodInfoSheet(food),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle, color: accentPink, size: 20),
                                onPressed: () => _showAddQuantityDialog(food, showSaveFavorite: false),
                              ),
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
                const SizedBox(height: 16),
                _buildCompactMacroVisualizer(
                  kcal: food.caloriesPer100g,
                  proteins: food.proteinsPer100g,
                  carbs: food.carbsPer100g,
                  fats: food.fatsPer100g,
                  fibers: food.fibersPer100g,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}
