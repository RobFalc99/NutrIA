import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../domain/models.dart';

class GeminiService {
  final String apiKey;

  GeminiService({required this.apiKey});

  /// Analizza una descrizione testuale e restituisce una lista di MealItem.
  /// Usiamo un prompt strutturato per far restituire al modello solo JSON.
  Future<List<MealItem>> analyzeTextToMeals(String text) async {
    final model = GenerativeModel(
      model: 'gemini-1.5-flash', // Usiamo flash che è veloce ed economico
      apiKey: apiKey,
    );

    final prompt = '''
Sei un nutrizionista esperto. Analizza il seguente testo che descrive un pasto.
Devi estrarre i singoli ingredienti/alimenti, la loro grammatura stimata, e i macronutrienti (inclusi carboidrati, proteine, grassi e fibre) per 100g.
Rispondi ESCLUSIVAMENTE con un JSON valido (senza markdown, senza blocchi di codice) con questo formato:
[
  {
    "name": "Nome Alimento",
    "amountGrams": 150,
    "caloriesPer100g": 120,
    "proteinsPer100g": 10.5,
    "carbsPer100g": 2.0,
    "fatsPer100g": 5.0,
    "fibersPer100g": 1.5
  }
]
Testo da analizzare: "$text"
''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      if (response.text != null) {
        return _parseJsonToMealItems(response.text!);
      }
    } catch (e) {
      print('Errore Gemini Text Analysis: $e');
    }
    return [];
  }

  /// Analizza un'immagine con testo opzionale
  Future<List<MealItem>> analyzeImageToMeals(List<int> imageBytes, {String? additionalText}) async {
    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
    );

    final prompt = '''
Sei un nutrizionista esperto. Analizza la foto di questo pasto${additionalText != null ? ' e considera queste info: "$additionalText"' : ''}.
Stima gli ingredienti visibili, il loro peso in grammi e i macronutrienti (inclusi calorie, carboidrati, proteine, grassi e fibre) per 100g dell'alimento.
Rispondi ESCLUSIVAMENTE con un JSON valido (senza markdown, senza blocchi di codice) con questo formato:
[
  {
    "name": "Nome Alimento",
    "amountGrams": 150,
    "caloriesPer100g": 120,
    "proteinsPer100g": 10.5,
    "carbsPer100g": 2.0,
    "fatsPer100g": 5.0,
    "fibersPer100g": 1.5
  }
]
''';

    try {
      final imagePart = DataPart('image/jpeg', Uint8List.fromList(imageBytes));
      final response = await model.generateContent([
        Content.multi([TextPart(prompt), imagePart])
      ]);
      
      if (response.text != null) {
        return _parseJsonToMealItems(response.text!);
      }
    } catch (e) {
      print('Errore Gemini Image Analysis: $e');
    }
    return [];
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
    try {
      String cleanJson = jsonString.trim();
      
      // Estrae in modo ultra-robusto il blocco JSON racchiuso tra parentesi quadre o graffe
      final startBracket = cleanJson.indexOf('[');
      final startBrace = cleanJson.indexOf('{');
      
      int start = -1;
      int end = -1;
      
      if (startBracket != -1 && (startBrace == -1 || startBracket < startBrace)) {
        start = startBracket;
        end = cleanJson.lastIndexOf(']');
      } else if (startBrace != -1) {
        start = startBrace;
        end = cleanJson.lastIndexOf('}');
      }
      
      if (start != -1 && end != -1 && end > start) {
        cleanJson = cleanJson.substring(start, end + 1);
      } else {
        // Fallback classico se non trova [ ] o { }
        if (cleanJson.startsWith('```json')) {
          cleanJson = cleanJson.substring(7);
        }
        if (cleanJson.startsWith('```')) {
          cleanJson = cleanJson.substring(3);
        }
        if (cleanJson.endsWith('```')) {
          cleanJson = cleanJson.substring(0, cleanJson.length - 3);
        }
      }
      
      final decoded = json.decode(cleanJson.trim());
      List<dynamic> list;
      
      if (decoded is List) {
        list = decoded;
      } else if (decoded is Map<String, dynamic>) {
        // Cerca una lista all'interno delle chiavi del Map
        final listKey = decoded.keys.firstWhere(
          (k) => decoded[k] is List,
          orElse: () => '',
        );
        if (listKey.isNotEmpty) {
          list = decoded[listKey] as List<dynamic>;
        } else {
          // Se non c'è una lista, forse il map stesso rappresenta un singolo alimento
          list = [decoded];
        }
      } else {
        print('Gemini ha restituito un tipo JSON non supportato: ${decoded.runtimeType}');
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
    } catch (e) {
      print('Errore nel parsing del JSON di Gemini: $e');
      return [];
    }
  }
}
