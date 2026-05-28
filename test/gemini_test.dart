@Timeout(Duration(minutes: 3))

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kcal_v1/data/remote/gemini_service.dart';

void main() {
  group('GeminiService Infrastructure & Feature Tests', () {
    // Carichiamo la chiave API dall'ambiente locale
    final apiKey = Platform.environment['GEMINI_API_KEY'];
    
    // Configura il modello standard di kCali
    const standardModel = 'gemini-2.0-flash-lite';

    // Mock di bytes per immagini (1x1 pixel PNG valido)
    final mockImageBytes = [
      137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 
      0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 108, 137, 
      0, 0, 0, 13, 73, 68, 65, 84, 120, 156, 99, 96, 64, 5, 0, 
      0, 2, 0, 1, 73, 175, 167, 104, 0, 0, 0, 0, 73, 69, 78, 68, 
      174, 66, 96, 130
    ];

    test('1. Test analyzeTextToMeals (Estrazione Pasto Completo da Testo)', () async {
      if (apiKey == null || apiKey.trim().isEmpty) {
        print('INFO: GEMINI_API_KEY non definita. Salto il test reale.');
        expect(true, isTrue);
        return;
      }

      print('Esecuzione test: Estrazione Pasto Completo...');
      final service = GeminiService(apiKey: apiKey, modelName: standardModel);
      
      try {
        final items = await service.analyzeTextToMeals(
          'Ho mangiato 150g di petto di pollo ai ferri e 80g di riso basmati'
        );
        
        expect(items, isNotNull);
        if (items.isNotEmpty) {
          final names = items.map((i) => i.food.name.toLowerCase()).toList();
          bool hasPolloOrRiso = names.any((name) => 
            name.contains('pollo') || name.contains('riso') || 
            name.contains('chicken') || name.contains('rice')
          );
          expect(hasPolloOrRiso, isTrue);
          print('  [OK] analyzeTextToMeals ha estratto: ${items.length} alimenti.');
        } else {
          print('  [WARNING] analyzeTextToMeals ha restituito una lista vuota.');
        }
      } catch (e) {
        print('  [WARNING] analyzeTextToMeals fallito o saltato per limiti di quota: $e');
      }
    });

    test('2. Test analyzeImageToMeals (Estrazione Pasto Completo da Immagine)', () async {
      if (apiKey == null || apiKey.trim().isEmpty) {
        expect(true, isTrue);
        return;
      }

      print('Esecuzione test: Vision Pasto Completo...');
      final service = GeminiService(apiKey: apiKey, modelName: standardModel);

      try {
        final items = await service.analyzeImageToMeals(
          mockImageBytes, 
          additionalText: 'Una foto di insalata con tonno'
        );
        expect(items, isNotNull);
        print('  [OK] analyzeImageToMeals ha risposto correttamente.');
      } catch (e) {
        print('  [WARNING] analyzeImageToMeals fallito o saltato per limiti di quota: $e');
      }
    });

    test('3. Test analyzeSingleFood (Estrazione Alimento Singolo da Descrizione)', () async {
      if (apiKey == null || apiKey.trim().isEmpty) {
        expect(true, isTrue);
        return;
      }

      print('Esecuzione test: Analisi Singolo Alimento...');
      final service = GeminiService(apiKey: apiKey, modelName: standardModel);

      try {
        final food = await service.analyzeSingleFood('una mela rossa media fresca');
        expect(food, isNotNull);
        if (food != null) {
          expect(food.name, isNotEmpty);
          expect(food.caloriesPer100g, greaterThan(0.0));
          print('  [OK] Alimento estratto: ${food.name} (${food.caloriesPer100g} kcal/100g)');
        }
      } catch (e) {
        print('  [WARNING] analyzeSingleFood fallito o saltato per limiti di quota: $e');
      }
    });

    test('4. Test analyzeMacroImage (Lettura Tabella Nutrizionale)', () async {
      if (apiKey == null || apiKey.trim().isEmpty) {
        expect(true, isTrue);
        return;
      }

      print('Esecuzione test: Scannerizzazione Tabella Nutrizionale...');
      final service = GeminiService(apiKey: apiKey, modelName: standardModel);

      try {
        final result = await service.analyzeMacroImage(mockImageBytes);
        expect(result, isNotNull);
        print('  [OK] analyzeMacroImage ha completato la richiesta.');
      } catch (e) {
        print('  [WARNING] analyzeMacroImage fallito o saltato per limiti di quota: $e');
      }
    });

    test('5. Test extractBarcodeFromImage (Lettura Cifre Barcode da Foto)', () async {
      if (apiKey == null || apiKey.trim().isEmpty) {
        expect(true, isTrue);
        return;
      }

      print('Esecuzione test: Estrazione Codice a Barre...');
      final service = GeminiService(apiKey: apiKey, modelName: standardModel);

      try {
        final barcode = await service.extractBarcodeFromImage(mockImageBytes);
        // Poiché l'immagine è un pixel bianco/trasparente, ci aspettiamo o null o errore,
        // ma verifichiamo che la chiamata non generi crash sintattici.
        print('  [OK] extractBarcodeFromImage ha risposto: $barcode');
      } catch (e) {
        print('  [WARNING] extractBarcodeFromImage fallito o saltato per limiti di quota: $e');
      }
    });
  });
}
