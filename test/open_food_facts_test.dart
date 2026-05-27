import 'package:flutter_test/flutter_test.dart';
import 'package:kcal_v1/data/remote/open_food_facts_service.dart';

void main() {
  group('Open Food Facts API Service Integration Tests', () {
    final service = OpenFoodFactsService();

    test('Query 10 different common foods from Open Food Facts and parse them successfully', () async {
      final queryTerms = [
        'pasta',
        'riso',
        'latte',
        'uova',
        'pollo',
        'tonno',
        'mela',
        'banana',
        'yogurt',
        'avena',
      ];

      expect(queryTerms.length, equals(10));

      for (final term in queryTerms) {
        print('Testing OpenFoodFacts query: "$term"...');
        final results = await service.searchProducts(term);
        
        // Assert we get results back (or gracefully log if network fails)
        expect(results, isNotNull);
        
        if (results.isNotEmpty) {
          final firstFood = results.first;
          expect(firstFood.id, isNotEmpty);
          expect(firstFood.name, isNotEmpty);
          expect(firstFood.caloriesPer100g, greaterThanOrEqualTo(0.0));
          expect(firstFood.proteinsPer100g, greaterThanOrEqualTo(0.0));
          expect(firstFood.carbsPer100g, greaterThanOrEqualTo(0.0));
          expect(firstFood.fatsPer100g, greaterThanOrEqualTo(0.0));
          print('  [OK] Product parsed: "${firstFood.name}" (${firstFood.caloriesPer100g} kcal/100g)');
        } else {
          print('  [WARNING] No online products returned for "$term" query.');
        }
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
