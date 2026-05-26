import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
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

  // Stato Tab Analisi IA
  final _aiTextController = TextEditingController();
  List<MealItem> _aiEstimatedItems = [];
  bool _isAiLoading = false;
  String? _aiError;
  bool _isImageMode = false;
  
  // Fotocamera Reale
  XFile? _capturedImage;

  // Stato Tab Cibo Custom
  final _customFormKey = GlobalKey<FormState>();
  final _customNameController = TextEditingController();
  final _customBrandController = TextEditingController();
  final _customCalController = TextEditingController();
  final _customProtController = TextEditingController();
  final _customCarbController = TextEditingController();
  final _customFatController = TextEditingController();
  final _customFibController = TextEditingController();
  bool _saveOnline = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
    _aiTextController.dispose();
    
    _customNameController.dispose();
    _customBrandController.dispose();
    _customCalController.dispose();
    _customProtController.dispose();
    _customCarbController.dispose();
    _customFatController.dispose();
    _customFibController.dispose();
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

  Future<void> _analyzeWithGeminiText() async {
    final text = _aiTextController.text.trim();
    if (text.isEmpty) return;

    final appState = context.read<AppState>();
    final service = appState.geminiService;
    
    if (service == null) {
      setState(() {
        _aiError = 'API Key Gemini non configurata nel profilo.';
      });
      return;
    }

    setState(() {
      _isAiLoading = true;
      _aiEstimatedItems = [];
      _aiError = null;
    });

    try {
      final items = await service.analyzeTextToMeals(text);
      setState(() {
        _aiEstimatedItems = items;
        if (items.isEmpty) {
          _aiError = 'L\'IA non ha estratto ingredienti validi. Riprova descrivendo meglio il piatto.';
        }
      });
    } catch (e) {
      setState(() {
        _aiError = 'Errore durante l\'analisi AI. Controlla la tua chiave API ed internet.';
      });
    } finally {
      setState(() {
        _isAiLoading = false;
      });
    }
  }

  // Cattura l'immagine reale chiedendo l'autorizzazione fotocamera
  Future<void> _captureRealImage() async {
    // Richiesta permessi fotocamera nativi
    final status = await Permission.camera.request();
    
    if (status.isGranted) {
      final picker = ImagePicker();
      try {
        final image = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );
        if (image != null) {
          setState(() {
            _capturedImage = image;
            _aiError = null;
          });
        }
      } catch (e) {
        setState(() {
          _aiError = 'Errore durante l\'apertura della fotocamera: $e';
        });
      }
    } else if (status.isPermanentlyDenied) {
      setState(() {
        _aiError = 'Permesso fotocamera negato permanentemente. Abilitalo nelle impostazioni per scattare foto dei pasti.';
      });
      openAppSettings();
    } else {
      setState(() {
        _aiError = 'Autorizzazione fotocamera negata dall\'utente.';
      });
    }
  }

  // Carica da Galleria
  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    try {
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() {
          _capturedImage = image;
          _aiError = null;
        });
      }
    } catch (e) {
      setState(() {
        _aiError = 'Errore nel caricamento dall\'album: $e';
      });
    }
  }

  Future<void> _analyzeWithGeminiVision() async {
    final appState = context.read<AppState>();
    final service = appState.geminiService;
    
    if (service == null) {
      setState(() {
        _aiError = 'API Key Gemini non configurata nel profilo.';
      });
      return;
    }

    if (_capturedImage == null) {
      setState(() {
        _aiError = 'Scatta prima una foto del pasto da analizzare!';
      });
      return;
    }

    setState(() {
      _isAiLoading = true;
      _aiEstimatedItems = [];
      _aiError = null;
    });

    try {
      final bytes = await _capturedImage!.readAsBytes();
      
      final String contextNote = _aiTextController.text.isNotEmpty 
          ? _aiTextController.text 
          : 'Analizza questo piatto stimando grammi ed alimenti.';

      final items = await service.analyzeImageToMeals(bytes.toList(), additionalText: contextNote);
      
      setState(() {
        _aiEstimatedItems = items;
        if (items.isEmpty) {
          _aiError = 'L\'IA visiva non è riuscita a stimare il piatto. Aggiungi dettagli testuali.';
        }
      });
    } catch (e) {
      setState(() {
        _aiError = 'Errore durante l\'analisi dell\'immagine con Gemini Vision.';
      });
    } finally {
      setState(() {
        _isAiLoading = false;
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

      final double grams = double.tryParse(_amountController.text) ?? 100.0;

      if (_saveOnline) {
        appState.saveCustomFood(newFood);
      }
      
      appState.addMealItem(_selectedMealName, newFood, grams);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${newFood.name} aggiunto a $_selectedMealName!'),
          backgroundColor: const Color(0xFF00FFC2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
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

  void _addAiItemsDirectly() {
    final appState = context.read<AppState>();
    for (var item in _aiEstimatedItems) {
      appState.addMealItem(_selectedMealName, item.food, item.amountGrams);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tutti gli ingredienti stimati aggiunti a $_selectedMealName!'),
        backgroundColor: const Color(0xFF00FFC2),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context);
  }

  // --- WIDGETS DI SUPPORTO ---

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
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.search), text: 'Cerca'),
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'Barcode'),
            Tab(icon: Icon(Icons.psychology), text: 'Analisi IA'),
            Tab(icon: Icon(Icons.note_add), text: 'Nuovo'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Selettore Pasto e Quantità di Default
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: Row(
              children: [
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
                          if (val != null) {
                            setState(() {
                              _selectedMealName = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 110,
                  child: TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Quantità',
                      labelStyle: const TextStyle(color: Colors.white60),
                      suffixText: 'g',
                      suffixStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.04),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Contenuto delle Schede
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSearchTab(accentCyan, accentPink),
                _buildBarcodeTab(accentCyan, accentPink),
                _buildAiTab(accentCyan, accentPink),
                _buildCustomTab(accentCyan, accentPink),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // TAB 1: CERCA MANUALE
  Widget _buildSearchTab(Color cyan, Color pink) {
    final appState = context.watch<AppState>();
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barra di ricerca
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  onSubmitted: (_) => _performSearch(),
                  decoration: InputDecoration(
                    hintText: 'Cerca per nome alimento...',
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
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                ),
                child: const Icon(Icons.arrow_forward, color: Color(0xFF0F0F13)),
              )
            ],
          ),
          const SizedBox(height: 16),

          // Risultati ricerca ed elenco locale online
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FFC2)))
                : (_searchResults.isEmpty && _searchController.text.isNotEmpty)
                    ? const Center(child: Text('Nessun alimento trovato.', style: TextStyle(color: Colors.white54)))
                    : ListView(
                        physics: const BouncingScrollPhysics(),
                        children: [
                          // Sezione cibi personalizzati online creati dall'utente
                          if (appState.customFoods.isNotEmpty && _searchController.text.isEmpty) ...[
                            Row(
                              children: [
                                Icon(Icons.cloud_done, color: cyan, size: 16),
                                const SizedBox(width: 6),
                                const Text(
                                  'Cibi Personali (Salvati in Cloud)',
                                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...appState.customFoods.map((food) => _buildFoodListTile(food, cyan)),
                            const SizedBox(height: 20),
                          ],
                          
                          // Risultati OpenFoodFacts
                          if (_searchResults.isNotEmpty) ...[
                            const Text(
                              'Risultati OpenFoodFacts',
                              style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            ..._searchResults.map((food) => _buildFoodListTile(food, pink)),
                          ] else if (appState.customFoods.isEmpty) ...[
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.only(top: 100.0),
                                child: Column(
                                  children: [
                                    Icon(Icons.search_off, size: 48, color: Colors.white24),
                                    SizedBox(height: 10),
                                    Text(
                                      'Cerca alimenti per marca o nome\n o crea un alimento personalizzato.',
                                      style: TextStyle(color: Colors.white30, fontSize: 13),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodListTile(Food food, Color accentColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: ListTile(
        title: Text(food.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(
          '${food.brand ?? "Generico"} • ${food.caloriesPer100g.toInt()} kcal/100g • P: ${food.proteinsPer100g.toInt()}g',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        trailing: const Icon(Icons.add_circle, color: Color(0xFF00FFC2)),
        onTap: () => _addFoodDirectly(food),
      ),
    );
  }

  // TAB 2: SCANSIONE CODICE A BARRE (EMULATORE)
  Widget _buildBarcodeTab(Color cyan, Color pink) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Scanner Visual Emulator
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_isScanning ? Icons.sync : Icons.qr_code_scanner, size: 48, color: cyan),
                    const SizedBox(height: 10),
                    Text(
                      _isScanning ? 'Scansione in corso...' : 'Fotocamera Pronta per Scansione',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
                // Glowing scan line
                if (_isScanning)
                  Positioned(
                    top: 80,
                    left: 20,
                    right: 20,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: cyan,
                        boxShadow: [
                          BoxShadow(color: cyan.withOpacity(0.8), blurRadius: 10, spreadRadius: 2),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Scansione Rapida di Codici di Prova
          const Text('Codici di test rapidi per sviluppo:', style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMockBarcodeChip('8001120003008', 'Pasta Barilla'),
              _buildMockBarcodeChip('3017620422003', 'Nutella Ferrero'),
              _buildMockBarcodeChip('8000500003784', 'Acqua Levissima'),
            ],
          ),
          const SizedBox(height: 20),

          // Input Manuale Codice
          TextField(
            controller: _barcodeController,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Inserisci codice a barre a mano...',
              hintStyle: const TextStyle(color: Colors.white30),
              prefixIcon: const Icon(Icons.qr_code, color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withOpacity(0.04),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: () => _scanBarcode(_barcodeController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: pink,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            icon: const Icon(Icons.camera_alt, color: Colors.white),
            label: const Text('Scansiona / Cerca Codice', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),

          const SizedBox(height: 24),

          // Risultato Scansione
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
                      Text('Prodotto Identificato!', style: TextStyle(color: cyan, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('${_barcodeResult!.caloriesPer100g.toInt()} kcal/100g', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_barcodeResult!.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(_barcodeResult!.brand ?? 'Marca Sconosciuta', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _addFoodDirectly(_barcodeResult!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cyan,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Conferma ed Aggiungi', style: TextStyle(color: Color(0xFF0F0F13), fontWeight: FontWeight.bold)),
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
              child: Text(
                _barcodeError!,
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMockBarcodeChip(String code, String label) {
    return ActionChip(
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
      backgroundColor: Colors.white.withOpacity(0.08),
      onPressed: () {
        _barcodeController.text = code;
        _scanBarcode(code);
      },
    );
  }

  // TAB 3: ANALISI INTELLIGENZA ARTIFICIALE (GEMINI)
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
            const Text(
              'Assistente Nutrizionale AI Disattivato',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Per consentire a Google Gemini di analizzare descrizioni testuali e foto dei tuoi piatti stimando i macro in tempo reale, inserisci la tua API Key Gemini nelle impostazioni del tuo profilo.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/profile');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: pink,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
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
          // Switch Testo / Immagine
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Descrizione Pasto', style: TextStyle(color: Colors.white)),
                  selected: !_isImageMode,
                  selectedColor: cyan.withOpacity(0.15),
                  backgroundColor: Colors.white.withOpacity(0.02),
                  onSelected: (val) {
                    setState(() {
                      _isImageMode = false;
                      _aiEstimatedItems = [];
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Foto Pasto (Vision)', style: TextStyle(color: Colors.white)),
                  selected: _isImageMode,
                  selectedColor: cyan.withOpacity(0.15),
                  backgroundColor: Colors.white.withOpacity(0.02),
                  onSelected: (val) {
                    setState(() {
                      _isImageMode = true;
                      _aiEstimatedItems = [];
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_isImageMode) ...[
            // Anteprima Immagine Catturata / Scelta o Pulsanti Fotocamera
            if (_capturedImage != null) ...[
              Container(
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cyan.withOpacity(0.3)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(File(_capturedImage!.path), fit: BoxFit.cover),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () {
                              setState(() {
                                _capturedImage = null;
                                _aiEstimatedItems = [];
                              });
                            },
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isAiLoading ? null : _analyzeWithGeminiVision,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cyan,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                icon: _isAiLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F0F13)))
                    : const Icon(Icons.analytics, color: Color(0xFF0F0F13)),
                label: const Text('Invia ed Analizza con Gemini Vision 🪄', style: TextStyle(color: Color(0xFF0F0F13), fontWeight: FontWeight.bold)),
              ),
            ] else ...[
              // Pulsanti per scattare foto reale o scegliere da galleria
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _captureRealImage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: pink,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      icon: const Icon(Icons.camera_alt, color: Colors.white),
                      label: const Text('Scatta Foto 📸', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickImageFromGallery,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.08),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      icon: const Icon(Icons.photo_library, color: Colors.white),
                      label: const Text('Galleria 🖼️', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
          ],

          // Campo descrizione testo
          TextField(
            controller: _aiTextController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: _isImageMode 
                  ? 'Aggiungi dettagli facoltativi sul pasto fotografato (es. condimenti, olio, bibite)...'
                  : 'Descrivi liberamente il tuo pasto...\n(es. "Ho mangiato un panino integrale con 80g di prosciutto crudo ed un filo di maionese")',
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
              filled: true,
              fillColor: Colors.white.withOpacity(0.04),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),

          if (!_isImageMode)
            ElevatedButton.icon(
              onPressed: _isAiLoading ? null : _analyzeWithGeminiText,
              style: ElevatedButton.styleFrom(
                backgroundColor: cyan,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              icon: _isAiLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F0F13)))
                  : const Icon(Icons.auto_awesome, color: Color(0xFF0F0F13)),
              label: const Text(
                'Stima Nutrizionale AI',
                style: TextStyle(color: Color(0xFF0F0F13), fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),

          const SizedBox(height: 24),

          // Risultati dell'Analisi AI
          if (_aiEstimatedItems.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cyan.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Color(0xFF00FFC2), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Ingredienti Stimati dall\'IA:',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _aiEstimatedItems.length,
                    itemBuilder: (context, index) {
                      final item = _aiEstimatedItems[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.food.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${item.amountGrams.toInt()}g • ${item.food.caloriesPer100g.toInt()} kcal/100g',
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                        trailing: Text(
                          '${((item.food.caloriesPer100g * item.amountGrams) / 100).toInt()} kcal',
                          style: const TextStyle(color: Color(0xFF00FFC2), fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _addAiItemsDirectly,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cyan,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Conferma ed Aggiungi al Pasto', style: TextStyle(color: Color(0xFF0F0F13), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ] else if (_aiError != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: pink.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: pink.withOpacity(0.2)),
              ),
              child: Text(
                _aiError!,
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // TAB 4: CREA ALIMENTO PERSONALIZZATO
  Widget _buildCustomTab(Color cyan, Color pink) {
    final appState = context.watch<AppState>();
    
    return Form(
      key: _customFormKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Crea Alimento Personalizzato',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'Verrà salvato nel database locale/cloud ed utilizzabile per i prossimi diari.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 20),

            _buildFormInput('Nome Alimento (es. Pane Di Segale)', _customNameController, TextInputType.name, true),
            const SizedBox(height: 12),
            _buildFormInput('Marca (es. Casereccio)', _customBrandController, TextInputType.name, false),
            const SizedBox(height: 12),
            _buildFormInput('Calorie per 100g (kcal)', _customCalController, TextInputType.number, true),
            const SizedBox(height: 12),
            _buildFormInput('Proteine per 100g (g)', _customProtController, TextInputType.number, true),
            
            if (appState.currentUser?.trackingMode != 'light') ...[
              const SizedBox(height: 12),
              _buildFormInput('Carboidrati per 100g (g)', _customCarbController, TextInputType.number, true),
              const SizedBox(height: 12),
              _buildFormInput('Grassi per 100g (g)', _customFatController, TextInputType.number, true),
            ],

            if (appState.currentUser?.trackingMode == 'custom') ...[
              const SizedBox(height: 12),
              _buildFormInput('Fibre per 100g (g)', _customFibController, TextInputType.number, true),
            ],

            const SizedBox(height: 16),
            
            // Switch cloud sync
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(15),
              ),
              child: SwitchListTile(
                value: _saveOnline,
                onChanged: (val) {
                  setState(() {
                    _saveOnline = val;
                  });
                },
                title: const Text('Salva in Cloud Personale', style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text('Sincronizza online con il server KCALcolatore.', style: TextStyle(color: Colors.white30, fontSize: 11)),
                activeColor: cyan,
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _saveCustomFoodAndAdd,
              style: ElevatedButton.styleFrom(
                backgroundColor: cyan,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text(
                'Crea ed Aggiungi al Pasto',
                style: TextStyle(color: Color(0xFF0F0F13), fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildFormInput(String label, TextEditingController controller, TextInputType keyboardType, bool required) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      validator: (val) {
        if (required && (val == null || val.isEmpty)) {
          return 'Campo obbligatorio';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00FFC2))),
      ),
    );
  }
}
