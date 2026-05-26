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

  List<MealItem> _parseJsonToMealItems(String jsonString) {
    try {
      String cleanJson = jsonString.trim();
      
      // Estrae in modo ultra-robusto il blocco JSON racchiuso tra parentesi quadre
      final start = cleanJson.indexOf('[');
      final end = cleanJson.lastIndexOf(']');
      if (start != -1 && end != -1 && end > start) {
        cleanJson = cleanJson.substring(start, end + 1);
      } else {
        // Fallback classico se non trova [ ]
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
      
      final List<dynamic> list = json.decode(cleanJson.trim());
      
      return list.map((item) {
        final food = Food(
          id: 'ai_${DateTime.now().millisecondsSinceEpoch}_${item['name'].hashCode}',
          name: item['name'] ?? 'Sconosciuto',
          caloriesPer100g: (item['caloriesPer100g'] ?? 0).toDouble(),
          proteinsPer100g: (item['proteinsPer100g'] ?? 0).toDouble(),
          carbsPer100g: (item['carbsPer100g'] ?? 0).toDouble(),
          fatsPer100g: (item['fatsPer100g'] ?? 0).toDouble(),
          fibersPer100g: (item['fibersPer100g'] ?? 0).toDouble(),
          isCustom: true,
        );
        return MealItem(
          food: food,
          amountGrams: (item['amountGrams'] ?? 100).toDouble(),
        );
      }).toList();
    } catch (e) {
      print('Errore nel parsing del JSON di Gemini: $e');
      return [];
    }
  }
}
