import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../data/remote/open_food_facts_service.dart';
import '../../domain/models.dart';
import '../../providers/app_state.dart';
import '../../providers/theme_provider.dart';
import '../../providers/translations.dart';
import 'add_meal_screen.dart'; // Per BarcodeScannerScreen
import 'recipe_builder_screen.dart';

/// Hub 'Nuovo Alimento / Ricetta' a schermo intero senza scroll verticale.
/// Presenta 5 opzioni visibili istantaneamente con layout ottimizzato e compatto.
class NuovoAlimentoScreen extends StatefulWidget {
  final String? initialMealTarget;
  const NuovoAlimentoScreen({super.key, this.initialMealTarget});

  @override
  State<NuovoAlimentoScreen> createState() => _NuovoAlimentoScreenState();
}

class _NuovoAlimentoScreenState extends State<NuovoAlimentoScreen> {
  static const accentCyan = Color(0xFF00FFC2);
  static const accentPink = Color(0xFFFF007F);
  static const bgDark = Color(0xFF0F0F13);
  static const bgCard = Color(0xFF16161D);

  final _openFoodFactsService = OpenFoodFactsService();
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  String _dictationInitialText = '';
  String _dictationLastWords = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onError: (e) => debugPrint('STT Error: $e'),
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isListening) {
              setState(() => _isListening = false);
            }
          }
        },
      );
    } catch (_) {}
  }

  void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            children: [
              const CircularProgressIndicator(color: accentCyan),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 1. Scansione Tabella Nutrizionale ---
  void _scanMacroLabelWithAi() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permesso fotocamera negato')),
        );
      }
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (pickedFile == null) return;
    final imageFile = File(pickedFile.path);

    if (!mounted) return;
    _showLoadingDialog(context, 'Analisi della tabella nutrizionale con IA...');

    try {
      final appState = context.read<AppState>();
      final gemini = appState.geminiService;

      if (gemini == null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inserisci la chiave API Gemini nel tuo profilo per usare l\'IA')),
        );
        return;
      }

      final bytes = await imageFile.readAsBytes();
      final result = await gemini.analyzeMacroImage(bytes);

      if (!mounted) return;
      Navigator.pop(context); // Chiude loading

      if (result != null) {
        _showAddQuantityDialog(result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile estrarre i valori dalla foto. Riprova con luce migliore.')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante l\'analisi: $e')),
        );
      }
    }
  }

  // --- 2. Barcode Scan ---
  void _startBarcodeScan() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const BarcodeScannerScreen(),
      ),
    );

    if (barcode != null && mounted) {
      _lookupBarcode(barcode);
    }
  }

  void _lookupBarcode(String barcode) async {
    _showLoadingDialog(context, 'Ricerca barcode nel database...');
    try {
      final product = await _openFoodFactsService.getProductByBarcode(barcode);
      if (!mounted) return;
      Navigator.pop(context); // chiude loading

      if (product != null) {
        _showAddQuantityDialog(product);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Prodotto non trovato per il codice: $barcode'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore ricerca: $e')),
      );
    }
  }

  // --- 3. Stima con IA Popup ---
  void _showSingleFoodAiPopup() {
    final textController = TextEditingController();
    bool isLoading = false;
    String? errorMsg;
    Food? estimatedFood;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology_outlined, color: Colors.purpleAccent, size: 24),
                      const SizedBox(width: 8),
                      const Text(
                        'Stima Alimento con IA 🪄',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: textController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Es. "Petto di pollo alla piastra" o "Mela fuji"...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.04),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      suffixIcon: IconButton(
                        icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? accentPink : accentCyan),
                        onPressed: () async {
                          if (_isListening) {
                            await _speechToText.stop();
                            setSheetState(() => _isListening = false);
                          } else {
                            if (!_speechEnabled) _initSpeech();
                            _dictationInitialText = textController.text;
                            setSheetState(() => _isListening = true);
                            _speechToText.listen(
                              localeId: 'it_IT',
                              onResult: (result) {
                                setSheetState(() {
                                  _dictationLastWords = result.recognizedWords;
                                  final prefix = _dictationInitialText.trim().isEmpty ? '' : '${_dictationInitialText.trim()} ';
                                  textController.text = '$prefix$_dictationLastWords';
                                });
                              },
                            );
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (errorMsg != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(errorMsg!, style: const TextStyle(color: accentPink, fontSize: 12)),
                    ),
                  ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            final desc = textController.text.trim();
                            if (desc.isEmpty) return;
                            final gemini = context.read<AppState>().geminiService;
                            if (gemini == null) {
                              setSheetState(() => errorMsg = 'Configura la chiave API Gemini nel profilo');
                              return;
                            }
                            setSheetState(() {
                              isLoading = true;
                              errorMsg = null;
                            });
                            try {
                              final f = await gemini.analyzeSingleFood(desc);
                              if (f != null && ctx.mounted) {
                                Navigator.pop(ctx);
                                _showAddQuantityDialog(f);
                              } else {
                                setSheetState(() {
                                  errorMsg = 'Impossibile stimare l\'alimento. Riprova con una descrizione più chiara.';
                                  isLoading = false;
                                });
                              }
                            } catch (e) {
                              setSheetState(() {
                                errorMsg = 'Errore: $e';
                                isLoading = false;
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Calcola con IA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- 4. Creazione Ricetta con IA ---
  void _openRecipeBuilder() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RecipeBuilderScreen(),
      ),
    );
  }

  // --- 5. Inserimento Manuale ---
  void _showManualFoodDialog() {
    final nomeController = TextEditingController();
    final marcaController = TextEditingController();
    final kcalController = TextEditingController();
    final protController = TextEditingController();
    final carbController = TextEditingController();
    final fatController = TextEditingController();
    final fibController = TextEditingController();
    final servingController = TextEditingController(text: '100');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: bgCard,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                TextField(
                  controller: nomeController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _buildInputDecoration('Nome alimento (es. Petto di pollo)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: marcaController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _buildInputDecoration('Marca (es. AIA, Barilla) - opzionale'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: kcalController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: _buildInputDecoration('Kcal/100g'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: protController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: _buildInputDecoration('Proteine (g)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: carbController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: _buildInputDecoration('Carboidrati (g)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: fatController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: _buildInputDecoration('Grassi (g)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: fibController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: _buildInputDecoration('Fibre (g)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: servingController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: _buildInputDecoration('Porzione (g)'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                final nome = nomeController.text.trim();
                final kcal = double.tryParse(kcalController.text) ?? 0.0;
                final prot = double.tryParse(protController.text) ?? 0.0;
                final carb = double.tryParse(carbController.text) ?? 0.0;
                final fat = double.tryParse(fatController.text) ?? 0.0;
                final fib = double.tryParse(fibController.text) ?? 0.0;
                final serv = double.tryParse(servingController.text);

                if (nome.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Inserisci almeno il nome dell\'alimento')),
                  );
                  return;
                }

                final food = Food(
                  id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                  name: nome,
                  brand: marcaController.text.trim().isEmpty ? null : marcaController.text.trim(),
                  caloriesPer100g: kcal,
                  proteinsPer100g: prot,
                  carbsPer100g: carb,
                  fatsPer100g: fat,
                  fibersPer100g: fib,
                  customServingGrams: serv,
                  customServingName: 'Porzione',
                  isCustom: true,
                );

                context.read<AppState>().addCustomFood(food);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Alimento "$nome" salvato con successo!'),
                    backgroundColor: accentCyan,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentCyan,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Salva Alimento', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  // Dialog per confermare quantità ed aggiungere l'alimento ai pasti o ai salvati
  void _showAddQuantityDialog(Food food) {
    double amount = food.customServingGrams ?? 100.0;
    final textController = TextEditingController(text: amount.toInt().toString());
    String selectedMeal = widget.initialMealTarget ?? 'Colazione';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final cal = (food.caloriesPer100g * amount) / 100;
          final prot = (food.proteinsPer100g * amount) / 100;
          final carb = (food.carbsPer100g * amount) / 100;
          final fat = (food.fatsPer100g * amount) / 100;
          final fib = (food.fibersPer100g * amount) / 100;

          return AlertDialog(
            backgroundColor: bgCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (food.brand != null)
                  Text(food.brand!, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: textController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    decoration: InputDecoration(
                      labelText: 'Grammi (g)',
                      labelStyle: const TextStyle(color: Colors.white60),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.04),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                    onChanged: (val) {
                      setDialogState(() => amount = double.tryParse(val) ?? 0.0);
                    },
                  ),
                  const SizedBox(height: 12),
                  // Macro summary row
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${cal.toInt()} kcal • P:${prot.toStringAsFixed(1)}g C:${carb.toStringAsFixed(1)}g F:${fat.toStringAsFixed(1)}g Fib:${fib.toStringAsFixed(1)}g',
                      style: const TextStyle(color: accentCyan, fontSize: 11, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  context.read<AppState>().addCustomFood(food);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('"${food.name}" salvato nei tuoi alimenti!'), backgroundColor: accentCyan),
                  );
                },
                child: const Text('Salva nei Miei Cibi', style: TextStyle(color: accentCyan, fontSize: 12)),
              ),
              ElevatedButton(
                onPressed: () {
                  context.read<AppState>().addMealItem(selectedMeal, food, amount);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Aggiunto a $selectedMeal!'), backgroundColor: accentCyan),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentPink,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Aggiungi al Diario', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgPrimary,
      appBar: AppBar(
        title: Text(
          context.tr('Nuovo Alimento'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Tabella Nutrizionale Card
              Expanded(
                child: _buildActionCard(
                  title: '${context.tr('Tabella nutrizionale')} 📷',
                  subtitle: context.tr('Scansiona etichetta con OCR / IA'),
                  color: accentPink,
                  icon: Icons.camera_alt_outlined,
                  onTap: _scanMacroLabelWithAi,
                ),
              ),
              const SizedBox(height: 10),

              // 2. Barcode Card
              Expanded(
                child: _buildActionCard(
                  title: '${context.tr('Codice a barre')} 📷',
                  subtitle: context.tr('Scansiona barcode via OpenFoodFacts'),
                  color: accentCyan,
                  icon: Icons.qr_code_scanner_rounded,
                  onTap: _startBarcodeScan,
                ),
              ),
              const SizedBox(height: 10),

              // 3. Stima con IA Card
              Expanded(
                child: _buildActionCard(
                  title: '${context.tr('Stima con IA')} 🪄',
                  subtitle: context.tr('Stima valori e grammi da foto o testo'),
                  color: Colors.purpleAccent,
                  icon: Icons.psychology_outlined,
                  onTap: _showSingleFoodAiPopup,
                ),
              ),
              const SizedBox(height: 10),

              // 4. Creazione Ricetta con IA Card (Richiesta specifica tra IA e manuale)
              Expanded(
                child: _buildActionCard(
                  title: '${context.tr('Creazione di ricetta con IA')} 🍲',
                  subtitle: context.tr('Scomponi ingredienti e calcola porzioni'),
                  color: Colors.orangeAccent,
                  icon: Icons.soup_kitchen_rounded,
                  onTap: _openRecipeBuilder,
                ),
              ),
              const SizedBox(height: 10),

              // 5. Inserimento Manuale Card
              Expanded(
                child: _buildActionCard(
                  title: '${context.tr('Inserimento manuale')} ✍️',
                  subtitle: context.tr('Inserisci valori e porzione a mano'),
                  color: const Color(0xFF00E676),
                  icon: Icons.edit_note_rounded,
                  onTap: _showManualFoodDialog,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: context.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
