import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../domain/models.dart';

class ParsedRecipe {
  final String title;
  final double? totalCookedWeightGrams;
  final double? servingsCount;
  final double? servingWeightGrams;
  final List<RecipeIngredient> ingredients;

  ParsedRecipe({
    required this.title,
    this.totalCookedWeightGrams,
    this.servingsCount,
    this.servingWeightGrams,
    required this.ingredients,
  });

  double get rawWeightGrams => ingredients.fold(0.0, (sum, i) => sum + i.amountGrams);
  double get totalCalories => ingredients.fold(0.0, (sum, i) => sum + i.calories);
  double get totalProteins => ingredients.fold(0.0, (sum, i) => sum + i.proteins);
  double get totalCarbs => ingredients.fold(0.0, (sum, i) => sum + i.carbs);
  double get totalFats => ingredients.fold(0.0, (sum, i) => sum + i.fats);
  double get totalFibers => ingredients.fold(0.0, (sum, i) => sum + i.fibers);

  // Calcoli per 100g basati sul peso finale cotto (se presente) o sul peso crudo totale
  double get effectiveTotalWeight {
    if (totalCookedWeightGrams != null && totalCookedWeightGrams! > 0) {
      return totalCookedWeightGrams!;
    }
    return rawWeightGrams > 0 ? rawWeightGrams : 100.0;
  }

  double get caloriesPer100g => (totalCalories * 100) / effectiveTotalWeight;
  double get proteinsPer100g => (totalProteins * 100) / effectiveTotalWeight;
  double get carbsPer100g => (totalCarbs * 100) / effectiveTotalWeight;
  double get fatsPer100g => (totalFats * 100) / effectiveTotalWeight;
  double get fibersPer100g => (totalFibers * 100) / effectiveTotalWeight;

  // Calcolo porzione effettiva
  double get effectiveServingWeight {
    if (servingWeightGrams != null && servingWeightGrams! > 0) {
      return servingWeightGrams!;
    }
    if (servingsCount != null && servingsCount! > 0 && effectiveTotalWeight > 0) {
      return effectiveTotalWeight / servingsCount!;
    }
    return 100.0;
  }

  double get effectiveServingsCount {
    if (servingsCount != null && servingsCount! > 0) {
      return servingsCount!;
    }
    if (servingWeightGrams != null && servingWeightGrams! > 0 && effectiveTotalWeight > 0) {
      return effectiveTotalWeight / servingWeightGrams!;
    }
    return 1.0;
  }
}

class GeminiService {
  final String apiKey;
  final String modelName;

  static const String defaultFastModel = 'gemini-3.5-flash-lite';

  GeminiService({required this.apiKey, this.modelName = defaultFastModel});

  /// Interroga online l'API ufficiale di Google Generative Language per recuperare dinamicamente
  /// i modelli abilitati e supportati per la generazione di contenuti testuali/multimodali.
  static Future<List<String>> fetchAvailableModels(String apiKey) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) {
      return defaultFallbackModels;
    }

    try {
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$cleanKey');
      final response = await http.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final modelsRaw = decoded['models'] as List<dynamic>? ?? [];
        final parsed = <String>[];

        for (final item in modelsRaw) {
          if (item is Map<String, dynamic>) {
            final rawName = (item['name'] as String? ?? '').replaceFirst('models/', '');
            final methods = (item['supportedGenerationMethods'] as List<dynamic>? ?? []).cast<String>();
            // Filtra solo i modelli in grado di generare contenuti
            if (methods.contains('generateContent') && rawName.isNotEmpty) {
              parsed.add(rawName);
            }
          }
        }

        if (parsed.isNotEmpty) {
          // Ordina dando priorità ai modelli flash/lite più veloci ed economici per l'uso quotidiano
          parsed.sort((a, b) {
            int scoreA = _modelPriority(a);
            int scoreB = _modelPriority(b);
            if (scoreA != scoreB) return scoreA.compareTo(scoreB);
            return b.compareTo(a); // Versioni più recenti prima
          });
          return parsed;
        }
      } else {
        debugPrint('Gemini fetchAvailableModels: HTTP ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Errore durante il fetch dinamico dei modelli Gemini: $e');
    }

    return defaultFallbackModels;
  }

  static int _modelPriority(String model) {
    final lower = model.toLowerCase();
    if (lower.contains('flash-lite')) return 0;
    if (lower.contains('flash')) return 1;
    if (lower.contains('pro')) return 2;
    return 3;
  }

  static const List<String> defaultFallbackModels = [
    'gemini-3.5-flash-lite',
    'gemini-2.5-flash',
    'gemini-3.5-flash',
    'gemini-3-flash',
    'gemini-2.5-flash-lite',
  ];

  /// Analizza una descrizione testuale e restituisce una lista di MealItem.
  Future<List<MealItem>> analyzeTextToMeals(String text) async {
    final systemPrompt = '''
Sei un nutrizionista esperto ed estremamente preciso.
Il tuo compito è analizzare la descrizione del pasto (o dei pasti dell'intera giornata) fornito dall'utente ed estrarre i singoli ingredienti/alimenti, stimando la loro grammatura ed i macronutrienti riferiti a 100g.
Inoltre, associa ogni alimento al pasto di appartenenza tramite il campo "targetMeal" (valori ammessi: "Colazione", "Pranzo", "Cena", "Spuntini").

REGOLE PER LA STIMA DELLA GRAMMATURA:
1. Se specificata chiaramente ("100g di pasta", "pasta 80g"), mantieni quel valore preciso.
2. Se non specificata, stima una porzione standard realistica (pasta ~80-100g cruda, olio EVO ~10g, uovo ~60g, ecc.).

Rispondi ESCLUSIVAMENTE con un array JSON valido, senza blocchi di codice markdown.
[
  {
    "name": "Nome Alimento in Italiano",
    "amountGrams": 150.0,
    "caloriesPer100g": 120.0,
    "proteinsPer100g": 10.5,
    "carbsPer100g": 2.0,
    "fatsPer100g": 5.0,
    "fibersPer100g": 1.5,
    "targetMeal": "Colazione"
  }
]
''';

    final model = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      systemInstruction: Content.system(systemPrompt),
    );

    try {
      final response = await model.generateContent([Content.text(text)]);
      if (response.text != null) {
        return _parseJsonToMealItems(response.text!);
      } else {
        throw Exception('L\'IA ha restituito una risposta vuota.');
      }
    } catch (e) {
      print('Errore Gemini Text Analysis: $e');
      rethrow;
    }
  }

  /// Analizza un'immagine con testo opzionale
  Future<List<MealItem>> analyzeImageToMeals(List<int> imageBytes, {String? additionalText}) async {
    final systemPrompt = '''
Sei un nutrizionista esperto ed estremamente preciso.
Analizza l'immagine del pasto ed estrai i singoli alimenti, stimando grammatura e macronutrienti per 100g.
Rispondi ESCLUSIVAMENTE con un array JSON valido.
''';

    final model = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      systemInstruction: Content.system(systemPrompt),
    );

    try {
      final imagePart = DataPart('image/jpeg', Uint8List.fromList(imageBytes));
      final contentParts = <Part>[imagePart];
      if (additionalText != null && additionalText.trim().isNotEmpty) {
        contentParts.add(TextPart(additionalText));
      }

      final response = await model.generateContent([Content.multi(contentParts)]);
      if (response.text != null) {
        return _parseJsonToMealItems(response.text!);
      } else {
        throw Exception('L\'IA ha restituito una risposta vuota.');
      }
    } catch (e) {
      print('Errore Gemini Image Analysis: $e');
      rethrow;
    }
  }

  /// Analizza un singolo alimento descritto dall'utente
  Future<Food?> analyzeSingleFood(String query) async {
    final systemPrompt = '''
Sei un nutrizionista esperto. Analizza la descrizione del singolo alimento o prodotto ed estrai nome e valori nutrizionali per 100g.
Rispondi ESCLUSIVAMENTE con un JSON:
{
  "name": "Nome Alimento in Italiano",
  "caloriesPer100g": 250.0,
  "proteinsPer100g": 10.0,
  "carbsPer100g": 30.0,
  "fatsPer100g": 5.0,
  "fibersPer100g": 2.0,
  "customServingGrams": 50.0,
  "customServingName": "Porzione"
}
''';

    final model = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      systemInstruction: Content.system(systemPrompt),
    );

    try {
      final response = await model.generateContent([Content.text(query)]);
      final text = response.text;
      if (text == null) return null;

      final jsonStr = _extractLastJsonBlock(text);
      final decoded = json.decode(jsonStr) as Map<String, dynamic>;

      return Food(
        id: 'ai_single_${DateTime.now().millisecondsSinceEpoch}',
        name: decoded['name']?.toString() ?? query,
        caloriesPer100g: _parseDouble(decoded['caloriesPer100g'] ?? 0.0),
        proteinsPer100g: _parseDouble(decoded['proteinsPer100g'] ?? 0.0),
        carbsPer100g: _parseDouble(decoded['carbsPer100g'] ?? 0.0),
        fatsPer100g: _parseDouble(decoded['fatsPer100g'] ?? 0.0),
        fibersPer100g: _parseDouble(decoded['fibersPer100g'] ?? 0.0),
        customServingGrams: (decoded['customServingGrams'] as num?)?.toDouble(),
        customServingName: decoded['customServingName']?.toString(),
        isCustom: true,
      );
    } catch (e) {
      print('Errore Gemini Single Food Analysis: $e');
      return null;
    }
  }

  /// Recipe Builder: Analizza un prompt ricetta con calcolo porzioni e ingredienti
  Future<ParsedRecipe> analyzeRecipePrompt(String text) async {
    final systemPrompt = '''
Sei un nutrizionista e chef professionista.
L'utente ti descrive una ricetta, gli ingredienti utilizzati, e opzionalmente:
- Il peso totale del prodotto finito/cotto (es. 1000g, 1kg)
- Il numero di porzioni o pezzi (es. 20 pancake, 8 fette)
- Il peso o grammatura media della singola porzione (es. 50g)

Devi estrarre con la massima precisione:
1. "title": Nome descrittivo della ricetta in italiano (es. "Pancake all'Avena Proteici")
2. "totalCookedWeightGrams": peso finale cotto o totale in grammi (numero o null se non specificato)
3. "servingsCount": numero di porzioni o pezzi totali (numero o null se non specificato)
4. "servingWeightGrams": peso medio di una porzione in grammi (numero o null se non specificato)
5. "ingredients": array di ingredienti, ciascuno con:
   - "name": Nome dell'ingrediente in italiano
   - "amountGrams": Grammatura dell'ingrediente usato nella ricetta
   - "caloriesPer100g", "proteinsPer100g", "carbsPer100g", "fatsPer100g", "fibersPer100g": valori nutrizionali per 100g riferiti all'ingrediente.

Rispondi ESCLUSIVAMENTE con un JSON valido nel seguente formato:
{
  "title": "Pancake Proteici",
  "totalCookedWeightGrams": 1000.0,
  "servingsCount": 20.0,
  "servingWeightGrams": 50.0,
  "ingredients": [
    {
      "name": "Farina d'avena",
      "amountGrams": 300.0,
      "caloriesPer100g": 370.0,
      "proteinsPer100g": 13.0,
      "carbsPer100g": 66.0,
      "fatsPer100g": 6.5,
      "fibersPer100g": 9.0
    }
  ]
}
''';

    final model = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      systemInstruction: Content.system(systemPrompt),
    );

    try {
      final response = await model.generateContent([Content.text(text)]);
      final resText = response.text;
      if (resText == null || resText.trim().isEmpty) {
        throw Exception('Risposta vuota da Gemini per la ricetta.');
      }

      final jsonStr = _extractLastJsonBlock(resText);
      final decoded = json.decode(jsonStr) as Map<String, dynamic>;

      final title = decoded['title']?.toString() ?? 'Nuova Ricetta';
      final totalCookedWeight = (decoded['totalCookedWeightGrams'] as num?)?.toDouble();
      final servingsCount = (decoded['servingsCount'] as num?)?.toDouble();
      final servingWeight = (decoded['servingWeightGrams'] as num?)?.toDouble();

      final ingredientsList = <RecipeIngredient>[];
      final rawIngredients = decoded['ingredients'] as List<dynamic>? ?? [];

      for (final raw in rawIngredients) {
        if (raw is Map) {
          final ingMap = Map<String, dynamic>.from(raw);
          final ingName = ingMap['name']?.toString() ?? 'Ingrediente';
          final ingAmount = _parseDouble(ingMap['amountGrams'] ?? 100.0);
          final cal = _parseDouble(ingMap['caloriesPer100g'] ?? 0.0);
          final prot = _parseDouble(ingMap['proteinsPer100g'] ?? 0.0);
          final carbs = _parseDouble(ingMap['carbsPer100g'] ?? 0.0);
          final fats = _parseDouble(ingMap['fatsPer100g'] ?? 0.0);
          final fibers = _parseDouble(ingMap['fibersPer100g'] ?? 0.0);

          ingredientsList.add(RecipeIngredient(
            food: Food(
              id: 'ing_${DateTime.now().microsecondsSinceEpoch}_${ingName.hashCode}',
              name: ingName,
              caloriesPer100g: cal,
              proteinsPer100g: prot,
              carbsPer100g: carbs,
              fatsPer100g: fats,
              fibersPer100g: fibers,
              isCustom: true,
            ),
            amountGrams: ingAmount,
          ));
        }
      }

      return ParsedRecipe(
        title: title,
        totalCookedWeightGrams: totalCookedWeight,
        servingsCount: servingsCount,
        servingWeightGrams: servingWeight,
        ingredients: ingredientsList,
      );
    } catch (e) {
      print('Errore Gemini Recipe Analysis: $e');
      rethrow;
    }
  }

  /// Legge una tabella nutrizionale da un'immagine
  Future<Food?> analyzeMacroImage(List<int> imageBytes) async {
    final systemPrompt = '''
Sei un esperto di analisi etichette nutrizionali.
Estrai i valori nutrizionali per 100g dalla tabella nutrizionale presente nell'immagine.
Rispondi ESCLUSIVAMENTE con un JSON:
{
  "name": "Nome Prodotto",
  "caloriesPer100g": 150.0,
  "proteinsPer100g": 10.0,
  "carbsPer100g": 20.0,
  "fatsPer100g": 3.0,
  "fibersPer100g": 1.5,
  "customServingGrams": 40.0,
  "customServingName": "Porzione"
}
''';

    final model = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      systemInstruction: Content.system(systemPrompt),
    );

    try {
      final imagePart = DataPart('image/jpeg', Uint8List.fromList(imageBytes));
      final response = await model.generateContent([
        Content.multi([TextPart('Estrai la tabella nutrizionale per 100g da questa etichetta.'), imagePart])
      ]);

      final text = response.text;
      if (text == null) return null;

      final jsonStr = _extractLastJsonBlock(text);
      final decoded = json.decode(jsonStr) as Map<String, dynamic>;

      return Food(
        id: 'ocr_${DateTime.now().millisecondsSinceEpoch}',
        name: decoded['name']?.toString() ?? 'Prodotto Etichetta',
        caloriesPer100g: _parseDouble(decoded['caloriesPer100g'] ?? 0.0),
        proteinsPer100g: _parseDouble(decoded['proteinsPer100g'] ?? 0.0),
        carbsPer100g: _parseDouble(decoded['carbsPer100g'] ?? 0.0),
        fatsPer100g: _parseDouble(decoded['fatsPer100g'] ?? 0.0),
        fibersPer100g: _parseDouble(decoded['fibersPer100g'] ?? 0.0),
        customServingGrams: (decoded['customServingGrams'] as num?)?.toDouble(),
        customServingName: decoded['customServingName']?.toString(),
        isCustom: true,
      );
    } catch (e) {
      print('Errore Gemini Macro Label Extraction: $e');
      return null;
    }
  }

  /// Estrae il codice a barre numerico da un'immagine
  Future<String?> extractBarcodeFromImage(List<int> imageBytes) async {
    final systemPrompt = '''
Sei un estrattore di codice a barre numerico. Restituisci ESCLUSIVAMENTE le cifre numeriche (es. 8001120003008) o ERROR se non visibile.
''';

    final model = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      systemInstruction: Content.system(systemPrompt),
    );

    try {
      final imagePart = DataPart('image/jpeg', Uint8List.fromList(imageBytes));
      final response = await model.generateContent([
        Content.multi([TextPart('Estrai il barcode.'), imagePart])
      ]);

      final text = response.text?.trim() ?? '';
      if (text.isEmpty || text.contains('ERROR')) return null;
      final digits = text.replaceAll(RegExp(r'\D'), '');
      return digits.isNotEmpty ? digits : null;
    } catch (e) {
      print('Errore Gemini Barcode Extraction: $e');
      return null;
    }
  }

  List<MealItem> _parseJsonToMealItems(String jsonText) {
    try {
      final jsonBlock = _extractLastJsonBlock(jsonText);
      final decoded = json.decode(jsonBlock);
      return _convertDecodedToMealItems(decoded);
    } catch (e) {
      print('Fallito parsing JSON diretto: $e');
      return [];
    }
  }

  String _extractLastJsonBlock(String text) {
    final startBracket = text.indexOf('[');
    final startBrace = text.indexOf('{');
    int start = -1;
    int end = -1;

    if (startBracket != -1 && (startBrace == -1 || startBracket < startBrace)) {
      start = startBracket;
      end = text.lastIndexOf(']');
    } else if (startBrace != -1) {
      start = startBrace;
      end = text.lastIndexOf('}');
    }

    if (start != -1 && end != -1 && end > start) {
      return text.substring(start, end + 1);
    }
    return text;
  }

  List<MealItem> _convertDecodedToMealItems(dynamic decoded) {
    List<dynamic> list;

    if (decoded is List) {
      list = decoded;
    } else if (decoded is Map<String, dynamic>) {
      final listKey = decoded.keys.firstWhere(
        (k) => decoded[k] is List,
        orElse: () => '',
      );
      if (listKey.isNotEmpty) {
        list = decoded[listKey] as List<dynamic>;
      } else {
        list = [decoded];
      }
    } else {
      return [];
    }

    return list.map((itemRaw) {
      if (itemRaw is! Map) {
        return MealItem(
          food: Food(
            id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
            name: itemRaw.toString(),
            isCustom: true,
            caloriesPer100g: 0.0,
            proteinsPer100g: 0.0,
            carbsPer100g: 0.0,
            fatsPer100g: 0.0,
          ),
          amountGrams: 100.0,
        );
      }

      final item = Map<String, dynamic>.from(itemRaw);

      final String name = _findValue(item, ['name', 'nome', 'alimento', 'prodotto']) ?? 'Sconosciuto';
      final double amount = _parseDouble(_findValue(item, ['amountGrams', 'grams', 'grammi', 'peso', 'quantity']) ?? 100.0);
      final double calories = _parseDouble(_findValue(item, ['caloriesPer100g', 'calories', 'calorie', 'kcal']) ?? 0.0);
      final double proteins = _parseDouble(_findValue(item, ['proteinsPer100g', 'proteins', 'proteine']) ?? 0.0);
      final double carbs = _parseDouble(_findValue(item, ['carbsPer100g', 'carbs', 'carboidrati']) ?? 0.0);
      final double fats = _parseDouble(_findValue(item, ['fatsPer100g', 'fats', 'grassi']) ?? 0.0);
      final double fibers = _parseDouble(_findValue(item, ['fibersPer100g', 'fibers', 'fibre']) ?? 0.0);

      final food = Food(
        id: 'ai_${DateTime.now().millisecondsSinceEpoch}_${name.hashCode}',
        name: name,
        caloriesPer100g: calories,
        proteinsPer100g: proteins,
        carbsPer100g: carbs,
        fatsPer100g: fats,
        fibersPer100g: fibers,
        isCustom: true,
      );

      final String? targetMeal = _findValue(item, ['targetMeal', 'meal', 'pasto']);

      return MealItem(
        food: food,
        amountGrams: amount,
        targetMeal: targetMeal,
      );
    }).toList();
  }

  dynamic _findValue(Map<String, dynamic> map, List<String> candidateKeys) {
    for (final key in candidateKeys) {
      if (map.containsKey(key)) return map[key];
    }
    return null;
  }

  double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }
}
