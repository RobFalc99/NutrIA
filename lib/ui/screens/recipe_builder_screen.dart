import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/models.dart';
import '../../providers/app_state.dart';
import '../../providers/translations.dart';
import '../../data/remote/open_food_facts_service.dart';

class RecipeBuilderScreen extends StatefulWidget {
  final Food? initialRecipe; // Se fornito, modalità modifica ricetta esistente

  const RecipeBuilderScreen({super.key, this.initialRecipe});

  @override
  State<RecipeBuilderScreen> createState() => _RecipeBuilderScreenState();
}

class _RecipeBuilderScreenState extends State<RecipeBuilderScreen> {
  static const accentCyan = Color(0xFF00FFC2);
  static const accentPink = Color(0xFFFF007F);
  static const accentYellow = Color(0xFFFFD700);
  static const bgDark = Color(0xFF0F0F13);
  static const bgCard = Color(0xFF16161D);

  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _titleController = TextEditingController(text: 'Nuova Ricetta');
  final TextEditingController _servingNameController = TextEditingController(text: 'Porzione');

  // Campi del triangolo delle porzioni
  final TextEditingController _totalWeightController = TextEditingController();
  final TextEditingController _servingsController = TextEditingController();
  final TextEditingController _portionWeightController = TextEditingController();

  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;

  bool _isAutoCalculatingTriangle = false;
  bool _isLoadingAi = false;
  String? _aiError;

  final List<RecipeIngredient> _ingredients = [];

  @override
  void initState() {
    super.initState();
    _initSpeech();
    if (widget.initialRecipe != null) {
      _loadExistingRecipe(widget.initialRecipe!);
    }
  }

  void _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onError: (val) => debugPrint('Errore Speech: $val'),
        onStatus: (val) => debugPrint('Stato Speech: $val'),
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Speech init failed: $e');
    }
  }

  void _startListening() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      try {
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.mediumImpact();
      } catch (_) {}

      setState(() {
        _isListening = true;
      });

      final initialPrompt = _promptController.text;

      await _speechToText.listen(
        onResult: (result) {
          final words = result.recognizedWords.trim();
          if (words.isEmpty) return;

          setState(() {
            _promptController.text = initialPrompt.isEmpty ? words : '$initialPrompt $words';
            _promptController.selection = TextSelection.fromPosition(
              TextPosition(offset: _promptController.text.length),
            );
          });
        },
        localeId: 'it_IT',
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 30),
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permesso microfono non concesso')),
        );
      }
    }
  }

  void _stopListening() async {
    await _speechToText.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }
  }

  @override
  void dispose() {
    _speechToText.stop();
    _promptController.dispose();
    _titleController.dispose();
    _servingNameController.dispose();
    _totalWeightController.dispose();
    _servingsController.dispose();
    _portionWeightController.dispose();
    super.dispose();
  }

  void _loadExistingRecipe(Food recipe) {
    _titleController.text = recipe.name;
    _servingNameController.text = recipe.customServingName ?? 'Porzione';

    if (recipe.recipeTotalWeightGrams != null && recipe.recipeTotalWeightGrams! > 0) {
      _totalWeightController.text = recipe.recipeTotalWeightGrams!.toInt().toString();
    }
    if (recipe.recipeServingsCount != null && recipe.recipeServingsCount! > 0) {
      _servingsController.text = recipe.recipeServingsCount!.toStringAsFixed(recipe.recipeServingsCount! % 1 == 0 ? 0 : 1);
    }
    if (recipe.customServingGrams != null && recipe.customServingGrams! > 0) {
      _portionWeightController.text = recipe.customServingGrams!.toInt().toString();
    }

    if (recipe.recipeIngredientsJson != null && recipe.recipeIngredientsJson!.isNotEmpty) {
      try {
        final List<dynamic> list = json.decode(recipe.recipeIngredientsJson!);
        _ingredients.clear();
        for (final item in list) {
          _ingredients.add(RecipeIngredient.fromJson(item as Map<String, dynamic>));
        }
      } catch (e) {
        print('Errore parsing ingredienti esistenti: $e');
      }
    }
  }

  // --- CALCOLATORE BIDIREZIONALE TRIANGOLO DELLE PORZIONI ---
  void _onTotalWeightChanged(String val) {
    if (_isAutoCalculatingTriangle) return;
    _isAutoCalculatingTriangle = true;

    final totWeight = double.tryParse(val);
    final servings = double.tryParse(_servingsController.text);
    final portWeight = double.tryParse(_portionWeightController.text);

    if (totWeight != null && totWeight > 0) {
      if (servings != null && servings > 0) {
        // Calcola peso singola porzione
        final calcPortion = totWeight / servings;
        _portionWeightController.text = calcPortion.toStringAsFixed(calcPortion % 1 == 0 ? 0 : 1);
      } else if (portWeight != null && portWeight > 0) {
        // Calcola numero porzioni
        final calcServings = totWeight / portWeight;
        _servingsController.text = calcServings.toStringAsFixed(calcServings % 1 == 0 ? 0 : 1);
      }
    }
    _isAutoCalculatingTriangle = false;
    setState(() {});
  }

  void _onServingsChanged(String val) {
    if (_isAutoCalculatingTriangle) return;
    _isAutoCalculatingTriangle = true;

    final servings = double.tryParse(val);
    final totWeight = double.tryParse(_totalWeightController.text);
    final portWeight = double.tryParse(_portionWeightController.text);

    if (servings != null && servings > 0) {
      if (totWeight != null && totWeight > 0) {
        final calcPortion = totWeight / servings;
        _portionWeightController.text = calcPortion.toStringAsFixed(calcPortion % 1 == 0 ? 0 : 1);
      } else if (portWeight != null && portWeight > 0) {
        final calcTot = servings * portWeight;
        _totalWeightController.text = calcTot.toStringAsFixed(calcTot % 1 == 0 ? 0 : 1);
      }
    }
    _isAutoCalculatingTriangle = false;
    setState(() {});
  }

  void _onPortionWeightChanged(String val) {
    if (_isAutoCalculatingTriangle) return;
    _isAutoCalculatingTriangle = true;

    final portWeight = double.tryParse(val);
    final totWeight = double.tryParse(_totalWeightController.text);
    final servings = double.tryParse(_servingsController.text);

    if (portWeight != null && portWeight > 0) {
      if (totWeight != null && totWeight > 0) {
        final calcServings = totWeight / portWeight;
        _servingsController.text = calcServings.toStringAsFixed(calcServings % 1 == 0 ? 0 : 1);
      } else if (servings != null && servings > 0) {
        final calcTot = servings * portWeight;
        _totalWeightController.text = calcTot.toStringAsFixed(calcTot % 1 == 0 ? 0 : 1);
      }
    }
    _isAutoCalculatingTriangle = false;
    setState(() {});
  }

  // --- ANALISI RECIPE CON IA ---
  Future<void> _analyzeRecipeWithAi() async {
    final text = _promptController.text.trim();
    if (text.isEmpty) return;

    final appState = context.read<AppState>();
    final gemini = appState.geminiService;

    if (gemini == null) {
      setState(() {
        _aiError = 'Chiave API Gemini non impostata. Inseriscila nelle impostazioni del Profilo.';
      });
      return;
    }

    setState(() {
      _isLoadingAi = true;
      _aiError = null;
    });

    try {
      final parsed = await gemini.analyzeRecipePrompt(text);
      setState(() {
        _titleController.text = parsed.title;
        _ingredients.clear();
        _ingredients.addAll(parsed.ingredients);

        if (parsed.totalCookedWeightGrams != null) {
          _totalWeightController.text = parsed.totalCookedWeightGrams!.toInt().toString();
        } else {
          _totalWeightController.clear();
        }

        if (parsed.servingsCount != null) {
          _servingsController.text = parsed.servingsCount!.toStringAsFixed(parsed.servingsCount! % 1 == 0 ? 0 : 1);
        } else {
          _servingsController.clear();
        }

        if (parsed.servingWeightGrams != null) {
          _portionWeightController.text = parsed.servingWeightGrams!.toInt().toString();
        } else {
          // Risolvi automaticamente il triangolo solo se presenti totale e porzioni
          final tot = double.tryParse(_totalWeightController.text);
          final srv = double.tryParse(_servingsController.text);
          if (tot != null && srv != null && srv > 0) {
            final p = tot / srv;
            _portionWeightController.text = p.toStringAsFixed(p % 1 == 0 ? 0 : 1);
          } else {
            _portionWeightController.clear();
          }
        }

        if (parsed.customServingName != null && parsed.customServingName!.isNotEmpty) {
          _servingNameController.text = parsed.customServingName!;
        }
      });
    } catch (e) {
      setState(() {
        _aiError = 'Errore analisi IA: $e';
      });
    } finally {
      setState(() {
        _isLoadingAi = false;
      });
    }
  }

  // --- CALCOLI MACRO DERIVATI ---
  double get _rawIngredientsWeight => _ingredients.fold(0.0, (sum, i) => sum + i.amountGrams);
  double get _totalCalories => _ingredients.fold(0.0, (sum, i) => sum + i.calories);
  double get _totalProteins => _ingredients.fold(0.0, (sum, i) => sum + i.proteins);
  double get _totalCarbs => _ingredients.fold(0.0, (sum, i) => sum + i.carbs);
  double get _totalFats => _ingredients.fold(0.0, (sum, i) => sum + i.fats);
  double get _totalFibers => _ingredients.fold(0.0, (sum, i) => sum + i.fibers);

  double get _effectiveTotalWeight {
    final w = double.tryParse(_totalWeightController.text);
    if (w != null && w > 0) return w;
    return _rawIngredientsWeight > 0 ? _rawIngredientsWeight : 100.0;
  }

  double get _caloriesPer100g => _effectiveTotalWeight > 0 ? (_totalCalories * 100) / _effectiveTotalWeight : 0.0;
  double get _proteinsPer100g => _effectiveTotalWeight > 0 ? (_totalProteins * 100) / _effectiveTotalWeight : 0.0;
  double get _carbsPer100g => _effectiveTotalWeight > 0 ? (_totalCarbs * 100) / _effectiveTotalWeight : 0.0;
  double get _fatsPer100g => _effectiveTotalWeight > 0 ? (_totalFats * 100) / _effectiveTotalWeight : 0.0;
  double get _fibersPer100g => _effectiveTotalWeight > 0 ? (_totalFibers * 100) / _effectiveTotalWeight : 0.0;

  double get _effectivePortionWeight {
    final p = double.tryParse(_portionWeightController.text);
    if (p != null && p > 0) return p;
    final s = double.tryParse(_servingsController.text);
    if (s != null && s > 0 && _effectiveTotalWeight > 0) return _effectiveTotalWeight / s;
    return 100.0;
  }

  double get _portionCalories => (_caloriesPer100g * _effectivePortionWeight) / 100;
  double get _portionProteins => (_proteinsPer100g * _effectivePortionWeight) / 100;
  double get _portionCarbs => (_carbsPer100g * _effectivePortionWeight) / 100;
  double get _portionFats => (_fatsPer100g * _effectivePortionWeight) / 100;

  // --- AZIONI INGREDIENTI ---
  void _editIngredientAmount(int index, double newAmount) {
    if (index >= 0 && index < _ingredients.length) {
      setState(() {
        final old = _ingredients[index];
        _ingredients[index] = RecipeIngredient(food: old.food, amountGrams: newAmount);
      });
    }
  }

  void _removeIngredient(int index) {
    if (index >= 0 && index < _ingredients.length) {
      setState(() {
        _ingredients.removeAt(index);
      });
    }
  }

  Future<void> _openSearchAndAddOrReplace({int? replaceIndex}) async {
    final selectedFood = await showModalBottomSheet<Food>(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgDark,
      builder: (ctx) => const _SearchIngredientModal(),
    );

    if (selectedFood != null && mounted) {
      setState(() {
        final defaultGrams = selectedFood.customServingGrams ?? 100.0;
        if (replaceIndex != null && replaceIndex < _ingredients.length) {
          final oldAmount = _ingredients[replaceIndex].amountGrams;
          _ingredients[replaceIndex] = RecipeIngredient(food: selectedFood, amountGrams: oldAmount > 0 ? oldAmount : defaultGrams);
        } else {
          _ingredients.add(RecipeIngredient(food: selectedFood, amountGrams: defaultGrams));
        }
      });
    }
  }

  // --- SALVATAGGIO RICETTA ---
  Future<void> _saveRecipe() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci un nome per la ricetta!')),
      );
      return;
    }

    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aggiungi almeno un ingrediente alla ricetta!')),
      );
      return;
    }

    final appState = context.read<AppState>();
    final jsonIngredients = json.encode(_ingredients.map((i) => i.toJson()).toList());
    final servings = double.tryParse(_servingsController.text);

    final recipeFood = Food(
      id: widget.initialRecipe?.id ?? 'recipe_${DateTime.now().millisecondsSinceEpoch}',
      name: title,
      brand: 'Ricetta Personale',
      caloriesPer100g: _caloriesPer100g,
      proteinsPer100g: _proteinsPer100g,
      carbsPer100g: _carbsPer100g,
      fatsPer100g: _fatsPer100g,
      fibersPer100g: _fibersPer100g,
      isCustom: true,
      isOnline: true,
      customServingGrams: _effectivePortionWeight,
      customServingName: _servingNameController.text.trim().isNotEmpty ? _servingNameController.text.trim() : 'Porzione',
      isRecipe: true,
      recipeIngredientsJson: jsonIngredients,
      recipeTotalWeightGrams: _effectiveTotalWeight,
      recipeServingsCount: servings,
    );

    await appState.saveCustomFood(recipeFood);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ricetta "$title" salvata con successo! 🍲'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        title: Text(
          widget.initialRecipe != null ? 'Modifica Ricetta 🍲' : 'Recipe Builder IA 🍲',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          TextButton.icon(
            onPressed: _saveRecipe,
            icon: const Icon(Icons.check, color: accentCyan, size: 20),
            label: const Text('Salva', style: TextStyle(color: accentCyan, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // BOX RIASSUNTO MACRO (In evidenza)
            _buildLiveMacroHeader(),
            const SizedBox(height: 16),

            // SEZIONE 1: PROMPT IA (visibile solo se non stiamo modificando o espandibile)
            if (widget.initialRecipe == null) ...[
              _buildAiPromptSection(),
              const SizedBox(height: 16),
            ],

            // SEZIONE 2: NOME E METADATI RICETTA
            _buildRecipeDetailsCard(),
            const SizedBox(height: 16),

            // SEZIONE 3: TRIANGOLO DELLE PORZIONI
            _buildPortionTriangleCard(),
            const SizedBox(height: 16),

            // SEZIONE 4: TABELLA INGREDIENTI EDITABILE
            _buildIngredientsSection(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveMacroHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentCyan.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: accentCyan.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Per 100g di Prodotto', style: TextStyle(color: Colors.white60, fontSize: 11)),
                  Text(
                    '${_caloriesPer100g.toStringAsFixed(0)} kcal',
                    style: const TextStyle(color: accentCyan, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(width: 1, height: 32, color: Colors.white12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Per 1 ${_servingNameController.text} (${_effectivePortionWeight.toInt()}g)',
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  Text(
                    '${_portionCalories.toStringAsFixed(0)} kcal',
                    style: const TextStyle(color: accentPink, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMacroMiniCol('Prot', '${_portionProteins.toStringAsFixed(1)}g', accentPink),
              _buildMacroMiniCol('Carb', '${_portionCarbs.toStringAsFixed(1)}g', accentYellow),
              _buildMacroMiniCol('Grassi', '${_portionFats.toStringAsFixed(1)}g', const Color(0xFF00E676)),
              _buildMacroMiniCol('Tot Peso', '${_effectiveTotalWeight.toInt()}g', Colors.white70),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAiPromptSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.auto_awesome, color: accentCyan, size: 18),
              SizedBox(width: 8),
              Text(
                'Genera o Estrai Ricetta con IA',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Descrivi ingredienti, dosi e peso cotto o numero porzioni. Gemini calcolerà e dividerà tutto.',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _promptController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Es: Ho fatto 20 pancake: 300g avena, 4 uova, 400ml latte. In totale cotti pesano 1000g.',
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
              suffixIcon: IconButton(
                icon: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: _isListening ? accentPink : accentCyan,
                ),
                onPressed: () {
                  if (_isListening) {
                    _stopListening();
                  } else {
                    _startListening();
                  }
                },
                tooltip: context.tr('Dettatura vocale 🎙️'),
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.04),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          if (_aiError != null) ...[
            const SizedBox(height: 8),
            Text(_aiError!, style: const TextStyle(color: accentPink, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _isLoadingAi ? null : _analyzeRecipeWithAi,
            style: ElevatedButton.styleFrom(
              backgroundColor: accentCyan,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: _isLoadingAi
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Icon(Icons.flash_on, size: 18),
            label: Text(
              _isLoadingAi ? 'Analisi IA in corso...' : 'Elabora e Compila Ricetta 🪄',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bgCard, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nome & Tipo Porzione', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          TextField(
            controller: _titleController,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: 'Nome della Ricetta',
              labelStyle: const TextStyle(color: Colors.white60),
              filled: true,
              fillColor: Colors.white.withOpacity(0.03),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _servingNameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Nome singola unità (es. Porzione, Pancake, Fetta, Biscotto)',
              labelStyle: const TextStyle(color: Colors.white60),
              filled: true,
              fillColor: Colors.white.withOpacity(0.03),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildTriangleBox({
    required String title,
    required String subtitle,
    required String suffix,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white38, fontSize: 9),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                suffixText: suffix,
                suffixStyle: const TextStyle(color: accentYellow, fontWeight: FontWeight.bold, fontSize: 12),
                filled: true,
                fillColor: Colors.black38,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortionTriangleCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calculate, color: accentYellow, size: 18),
              const SizedBox(width: 8),
              Text(
                '${context.tr('Triangolo delle Porzioni')} 📐',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Inserisci 2 valori qualsiasi, il terzo verrà calcolato matematicamente in tempo reale.',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildTriangleBox(
                title: context.tr('Peso Totale Cotto'),
                subtitle: '(Cotto / finito)',
                suffix: 'g',
                controller: _totalWeightController,
                onChanged: _onTotalWeightChanged,
              ),
              const SizedBox(width: 8),
              _buildTriangleBox(
                title: context.tr('N. Porzioni'),
                subtitle: '(Pezzi totali)',
                suffix: 'pz',
                controller: _servingsController,
                onChanged: _onServingsChanged,
              ),
              const SizedBox(width: 8),
              _buildTriangleBox(
                title: context.tr('Peso Porzione'),
                subtitle: '(Grammatura)',
                suffix: 'g',
                controller: _portionWeightController,
                onChanged: _onPortionWeightChanged,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_rawIngredientsWeight > 0)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  _totalWeightController.text = _rawIngredientsWeight.toInt().toString();
                  _onTotalWeightChanged(_totalWeightController.text);
                },
                icon: const Icon(Icons.sync, size: 14, color: accentCyan),
                label: Text(
                  'Usa peso crudo ingredienti (${_rawIngredientsWeight.toInt()}g)',
                  style: const TextStyle(color: accentCyan, fontSize: 11),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIngredientsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ingredienti (${_ingredients.length})',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            OutlinedButton.icon(
              onPressed: () => _openSearchAndAddOrReplace(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Aggiungi Ingrediente'),
              style: OutlinedButton.styleFrom(
                foregroundColor: accentCyan,
                side: const BorderSide(color: accentCyan),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_ingredients.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: bgCard, borderRadius: BorderRadius.circular(16)),
            child: const Center(
              child: Text(
                'Nessun ingrediente inserito.\nUsa il prompt IA sopra o aggiungi ingredienti a mano.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
          )
        else
          ..._ingredients.asMap().entries.map((entry) {
            final idx = entry.key;
            final ing = entry.value;
            return _buildIngredientCard(idx, ing);
          }),
      ],
    );
  }

  Widget _buildIngredientCard(int index, RecipeIngredient ing) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ing.food.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  '${ing.calories.toStringAsFixed(0)} kcal • P:${ing.proteins.toStringAsFixed(1)}g C:${ing.carbs.toStringAsFixed(1)}g F:${ing.fats.toStringAsFixed(1)}g',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          // Input editabile dosi ingrediente
          SizedBox(
            width: 75,
            child: TextFormField(
              initialValue: ing.amountGrams.toInt().toString(),
              keyboardType: TextInputType.number,
              style: const TextStyle(color: accentCyan, fontWeight: FontWeight.bold, fontSize: 14),
              decoration: InputDecoration(
                suffixText: 'g',
                suffixStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
              onChanged: (val) {
                final grams = double.tryParse(val) ?? 0.0;
                _editIngredientAmount(index, grams);
              },
            ),
          ),
          const SizedBox(width: 4),
          // Sostituisci Alimento
          IconButton(
            icon: const Icon(Icons.swap_horiz, color: Colors.white38, size: 20),
            tooltip: 'Sostituisci Ingrediente',
            onPressed: () => _openSearchAndAddOrReplace(replaceIndex: index),
          ),
          // Rimuovi Ingrediente
          IconButton(
            icon: const Icon(Icons.delete_outline, color: accentPink, size: 20),
            tooltip: 'Rimuovi Ingrediente',
            onPressed: () => _removeIngredient(index),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroMiniCol(String label, String val, Color col) {
    return Column(
      children: [
        Text(val, style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 12)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }
}

/// Modal di ricerca per aggiungere o sostituire un ingrediente nella ricetta
class _SearchIngredientModal extends StatefulWidget {
  const _SearchIngredientModal();

  @override
  State<_SearchIngredientModal> createState() => _SearchIngredientModalState();
}

class _SearchIngredientModalState extends State<_SearchIngredientModal> {
  static const accentCyan = Color(0xFF00FFC2);
  static const bgCard = Color(0xFF16161D);

  final TextEditingController _searchCtrl = TextEditingController();
  final OpenFoodFactsService _offService = OpenFoodFactsService();
  List<Food> _webResults = [];
  bool _isSearching = false;

  void _onSearch(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _webResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final res = await _offService.searchProducts(q.trim());
      if (mounted) setState(() => _webResults = res);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final query = _searchCtrl.text.trim().toLowerCase();
    final customFoods = appState.standaloneCustomFoods
        .where((f) => f.name.toLowerCase().contains(query))
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Text('Seleziona Ingrediente', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(context)),
            ],
          ),
          TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Cerca nei tuoi cibi o su Open Food Facts...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: accentCyan),
              filled: true,
              fillColor: bgCard,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
            onSubmitted: _onSearch,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                if (customFoods.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('I Miei Alimenti', style: TextStyle(color: accentCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  ...customFoods.map((f) => ListTile(
                        title: Text(f.name, style: const TextStyle(color: Colors.white)),
                        subtitle: Text('${f.caloriesPer100g.toStringAsFixed(0)} kcal/100g', style: const TextStyle(color: Colors.white54)),
                        onTap: () => Navigator.pop(context, f),
                      )),
                ],
                if (_webResults.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('Open Food Facts', style: TextStyle(color: accentCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  ..._webResults.map((f) => ListTile(
                        title: Text(f.name, style: const TextStyle(color: Colors.white)),
                        subtitle: Text('${f.caloriesPer100g.toStringAsFixed(0)} kcal/100g', style: const TextStyle(color: Colors.white54)),
                        onTap: () => Navigator.pop(context, f),
                      )),
                ],
                if (_isSearching)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator(color: accentCyan)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
