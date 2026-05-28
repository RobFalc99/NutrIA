import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../domain/models.dart';

class GeminiService {
  final String apiKey;
  final String modelName;

  GeminiService({required this.apiKey, this.modelName = 'gemini-2.0-flash-lite'});

  /// Analizza una descrizione testuale e restituisce una lista di MealItem.
  /// Usiamo un prompt strutturato tramite systemInstruction per far restituire al modello solo JSON.
  Future<List<MealItem>> analyzeTextToMeals(String text) async {
    final systemPrompt = '''
Sei un nutrizionista esperto ed estremamente preciso.
Il tuo compito è analizzare la descrizione del pasto fornito dall'utente ed estrarre i singoli ingredienti/alimenti, stimando accuratamente la loro grammatura in grammi e calcolando i macronutrienti (calorie, proteine, carboidrati, grassi, fibre) riferiti a 100g di ciascun alimento.

Rispondi ESCLUSIVAMENTE con un array JSON valido, senza blocchi di codice markdown (NON inserire ```json o ``` all'inizio o alla fine) e senza alcun testo aggiuntivo prima o dopo il JSON.

Il formato JSON richiesto deve essere esattamente questo:
[
  {
    "name": "Nome Alimento in Italiano",
    "amountGrams": 150.0,
    "caloriesPer100g": 120.0,
    "proteinsPer100g": 10.5,
    "carbsPer100g": 2.0,
    "fatsPer100g": 5.0,
    "fibersPer100g": 1.5
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
Il tuo compito è analizzare l'immagine del pasto fornito dall'utente (e considerare qualsiasi eventuale testo descrittivo aggiuntivo) ed estrarre i singoli ingredienti/alimenti, stimando accuratamente la loro grammatura in grammi e calcolando i macronutrienti (calorie, proteine, carboidrati, grassi, fibre) riferiti a 100g di ciascun alimento.

Rispondi ESCLUSIVAMENTE con un array JSON valido, senza blocchi di codice markdown (NON inserire ```json o ``` all'inizio o alla fine) e senza alcun testo aggiuntivo prima o dopo il JSON.

Il formato JSON richiesto deve essere esattamente questo:
[
  {
    "name": "Nome Alimento in Italiano",
    "amountGrams": 150.0,
    "caloriesPer100g": 120.0,
    "proteinsPer100g": 10.5,
    "carbsPer100g": 2.0,
    "fatsPer100g": 5.0,
    "fibersPer100g": 1.5
  }
]
''';

    final model = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      systemInstruction: Content.system(systemPrompt),
    );

    try {
      final imagePart = DataPart('image/jpeg', Uint8List.fromList(imageBytes));
      final userPrompt = additionalText ?? 'Analizza questo pasto dell\'immagine.';
      final response = await model.generateContent([
        Content.multi([TextPart(userPrompt), imagePart])
      ]);
      
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

  /// Analizza una descrizione testuale di un singolo alimento e restituisce un solo Food (riferito a 100g).
  Future<Food?> analyzeSingleFood(String text) async {
    final systemPrompt = '''
Sei un nutrizionista esperto ed estremamente preciso.
Il tuo compito è analizzare il singolo alimento o ingrediente fornito dall'utente, stimando accuratamente i macronutrienti (calorie, proteine, carboidrati, grassi, fibre) riferiti a 100g di quell'alimento.
Importante: Devi restituire solo ed esclusivamente un singolo alimento.

Rispondi ESCLUSIVAMENTE con un oggetto JSON valido, senza blocchi di codice markdown (NON inserire ```json o ``` all'inizio o alla fine) e senza alcun testo aggiuntivo prima o dopo il JSON.

Il formato JSON richiesto deve essere esattamente questo:
{
  "name": "Nome Alimento in Italiano",
  "brand": "Marca se menzionata, altrimenti null",
  "caloriesPer100g": 120.0,
  "proteinsPer100g": 10.5,
  "carbsPer100g": 2.0,
  "fatsPer100g": 5.0,
  "fibersPer100g": 1.5
}
''';

    final model = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      systemInstruction: Content.system(systemPrompt),
    );

    try {
      final response = await model.generateContent([Content.text(text)]);
      if (response.text != null) {
        final cleanJson = response.text!.trim();
        final block = _extractJsonBlock(cleanJson);
        final item = Map<String, dynamic>.from(json.decode(block));
        
        final String name = _findValue(item, ['name', 'nome', 'alimento', 'prodotto']) ?? 'Sconosciuto';
        final String? brand = _findValue(item, ['brand', 'marca']);
        final double calories = _parseDouble(_findValue(item, ['caloriesPer100g', 'calories_per_100g', 'calories', 'calorie', 'kcal']) ?? 0.0);
        final double proteins = _parseDouble(_findValue(item, ['proteinsPer100g', 'proteins_per_100g', 'proteins', 'proteine']) ?? 0.0);
        final double carbs = _parseDouble(_findValue(item, ['carbsPer100g', 'carbs_per_100g', 'carbs', 'carboidrati']) ?? 0.0);
        final double fats = _parseDouble(_findValue(item, ['fatsPer100g', 'fats_per_100g', 'fats', 'grassi']) ?? 0.0);
        final double fibers = _parseDouble(_findValue(item, ['fibersPer100g', 'fibers_per_100g', 'fibers', 'fibre']) ?? 0.0);

        return Food(
          id: 'ai_single_${DateTime.now().millisecondsSinceEpoch}_${name.hashCode}',
          name: name,
          brand: brand,
          caloriesPer100g: calories,
          proteinsPer100g: proteins,
          carbsPer100g: carbs,
          fatsPer100g: fats,
          fibersPer100g: fibers,
          isCustom: true,
        );
      }
    } catch (e) {
      print('Errore Gemini Single Food Analysis: $e');
    }
    return null;
  }

  /// Estrae i valori nutrizionali da un'immagine dell'etichetta nutrizionale (macros).
  Future<Map<String, dynamic>?> analyzeMacroImage(List<int> imageBytes) async {
    final systemPrompt = '''
Sei un assistente IA specializzato nella lettura di etichette nutrizionali.
Analizza l'immagine fornita (che rappresenta una tabella o etichetta nutrizionale) ed estrai accuratamente i macronutrienti riferiti a 100g o 100ml di prodotto.
Se nell'etichetta sono presenti sia i valori per 100g che per porzione, estrai ESCLUSIVAMENTE quelli riferiti a 100g (o 100ml).

Rispondi ESCLUSIVAMENTE con un oggetto JSON valido, senza blocchi di codice markdown (NON inserire ```json o ``` all'inizio o alla fine) e senza alcun testo aggiuntivo prima o dopo il JSON.

Il formato JSON richiesto deve essere esattamente questo:
{
  "name": "Nome alimento se visibile, altrimenti vuoto",
  "brand": "Marca se visibile, altrimenti vuoto",
  "caloriesPer100g": 120.0,
  "proteinsPer100g": 10.5,
  "carbsPer100g": 2.0,
  "fatsPer100g": 5.0,
  "fibersPer100g": 1.5
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
        Content.multi([TextPart('Estrai i macro per 100g da questa tabella nutrizionale.'), imagePart])
      ]);

      if (response.text != null) {
        final cleanJson = response.text!.trim();
        final block = _extractJsonBlock(cleanJson);
        final decoded = json.decode(block);
        return Map<String, dynamic>.from(decoded);
      }
    } catch (e) {
      print('Errore Gemini Macro Label Extraction: $e');
    }
    return null;
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      // Rimuove spazi e caratteri non numerici tranne punti e virgole
      final cleaned = value.replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '.');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  dynamic _findValue(Map<String, dynamic> map, List<String> possibleKeys) {
    for (final key in possibleKeys) {
      if (map.containsKey(key)) return map[key];
      // Cerca in modo insensibile al maiuscolo/minuscolo e ignorando gli underscore
      final target = key.toLowerCase().replaceAll('_', '');
      for (final actualKey in map.keys) {
        final actual = actualKey.toLowerCase().replaceAll('_', '');
        if (actual == target) {
          return map[actualKey];
        }
      }
    }
    return null;
  }

  List<MealItem> _parseJsonToMealItems(String jsonString) {
    String cleanJson = jsonString.trim();

    try {
      // 1. Prova l'estrazione classica (primo [ o { fino all'ultimo ] o })
      final block = _extractJsonBlock(cleanJson);
      final decoded = json.decode(block);
      return _convertDecodedToMealItems(decoded);
    } catch (_) {
      try {
        // 2. Se fallisce (es. per blocchi doppi o ripetuti), prova ad estrarre l'ULTIMO blocco valido
        final lastBlock = _extractLastJsonBlock(cleanJson);
        final decoded = json.decode(lastBlock);
        return _convertDecodedToMealItems(decoded);
      } catch (e) {
        print('Errore nel parsing del JSON di Gemini: $e');
        throw Exception('Errore nel parsing dei dati del pasto: $e. Risposta originale: $jsonString');
      }
    }
  }

  String _extractJsonBlock(String text) {
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

  String _extractLastJsonBlock(String text) {
    final startBracket = text.lastIndexOf('[');
    final startBrace = text.lastIndexOf('{');
    int start = -1;
    int end = -1;

    if (startBracket != -1 && (startBrace == -1 || startBracket > startBrace)) {
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
      print('Tipo JSON non supportato: ${decoded.runtimeType}');
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

      final String name = _findValue(item, ['name', 'nome', 'alimento', 'prodotto', 'ingredient', 'ingrediente']) ?? 'Sconosciuto';
      final double amount = _parseDouble(_findValue(item, ['amountGrams', 'amount_grams', 'grams', 'grammi', 'weight', 'peso', 'amount', 'quantity', 'quantità']) ?? 100.0);
      final double calories = _parseDouble(_findValue(item, ['caloriesPer100g', 'calories_per_100g', 'calories', 'calorie', 'kcal', 'energy', 'energia']) ?? 0.0);
      final double proteins = _parseDouble(_findValue(item, ['proteinsPer100g', 'proteins_per_100g', 'proteins', 'proteine', 'protein']) ?? 0.0);
      final double carbs = _parseDouble(_findValue(item, ['carbsPer100g', 'carbs_per_100g', 'carbs', 'carboidrati', 'carb', 'carbohydrates']) ?? 0.0);
      final double fats = _parseDouble(_findValue(item, ['fatsPer100g', 'fats_per_100g', 'fats', 'grassi', 'fat', 'lipidi']) ?? 0.0);
      final double fibers = _parseDouble(_findValue(item, ['fibersPer100g', 'fibers_per_100g', 'fibers', 'fibre', 'fiber']) ?? 0.0);

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

      return MealItem(
        food: food,
        amountGrams: amount,
      );
    }).toList();
  }
}
