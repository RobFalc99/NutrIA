import 'package:flutter_test/flutter_test.dart';
import 'package:kcal_v1/domain/models.dart';
import 'package:kcal_v1/data/remote/gemini_service.dart';

void main() {
  group('Recipe Builder Math & Portion Triangle Tests', () {
    test('Calculates portion weight when total weight and servings count are provided', () {
      const double totalWeight = 1000.0;
      const double servingsCount = 20.0;
      final double calculatedPortion = totalWeight / servingsCount;

      expect(calculatedPortion, equals(50.0));
    });

    test('Calculates servings count when total weight and portion weight are provided', () {
      const double totalWeight = 1200.0;
      const double portionWeight = 150.0;
      final double calculatedServings = totalWeight / portionWeight;

      expect(calculatedServings, equals(8.0));
    });

    test('Calculates total weight when servings count and portion weight are provided', () {
      const double servingsCount = 12.0;
      const double portionWeight = 80.0;
      final double calculatedTotal = servingsCount * portionWeight;

      expect(calculatedTotal, equals(960.0));
    });
  });

  group('ParsedRecipe Aggregation & Per-100g / Per-Portion Calculations', () {
    test('Aggregates pancake recipe ingredients accurately', () {
      // Ricetta Pancake:
      // - 300g Farina avena (370 kcal/100g, 13g PRO, 66g CHO, 6.5g FAT) -> 1110 kcal, 39g PRO, 198g CHO, 19.5g FAT
      // - 200g Uova intere (155 kcal/100g, 13g PRO, 1.1g CHO, 11g FAT) -> 310 kcal, 26g PRO, 2.2g CHO, 22g FAT
      // - 400g Latte (47 kcal/100g, 3.3g PRO, 4.8g CHO, 1.5g FAT) -> 188 kcal, 13.2g PRO, 19.2g CHO, 6.0g FAT
      // Totale crudo = 900g, peso cotto specificato = 800g, 16 pancake (50g ciascuno)

      final avena = Food(id: '1', name: 'Avena', caloriesPer100g: 370, proteinsPer100g: 13, carbsPer100g: 66, fatsPer100g: 6.5);
      final uova = Food(id: '2', name: 'Uova', caloriesPer100g: 155, proteinsPer100g: 13, carbsPer100g: 1.1, fatsPer100g: 11);
      final latte = Food(id: '3', name: 'Latte', caloriesPer100g: 47, proteinsPer100g: 3.3, carbsPer100g: 4.8, fatsPer100g: 1.5);

      final recipe = ParsedRecipe(
        title: 'Pancake Avena',
        totalCookedWeightGrams: 800.0,
        servingsCount: 16.0,
        servingWeightGrams: 50.0,
        ingredients: [
          RecipeIngredient(food: avena, amountGrams: 300),
          RecipeIngredient(food: uova, amountGrams: 200),
          RecipeIngredient(food: latte, amountGrams: 400),
        ],
      );

      // Peso crudo totale: 300 + 200 + 400 = 900g
      expect(recipe.rawWeightGrams, equals(900.0));

      // Calorie totali: 1110 + 310 + 188 = 1608 kcal
      expect(recipe.totalCalories, closeTo(1608.0, 0.1));

      // Proteine totali: 39 + 26 + 13.2 = 78.2g
      expect(recipe.totalProteins, closeTo(78.2, 0.1));

      // Peso effettivo usato per il calcolo per 100g (deve essere il peso cotto di 800g!)
      expect(recipe.effectiveTotalWeight, equals(800.0));

      // Calorie per 100g prodotto finito: (1608 * 100) / 800 = 201 kcal/100g
      expect(recipe.caloriesPer100g, closeTo(201.0, 0.1));

      // Calorie per singolo pancake (50g): (201 * 50) / 100 = 100.5 kcal per pancake
      final singlePancakeKcal = (recipe.caloriesPer100g * recipe.effectiveServingWeight) / 100;
      expect(singlePancakeKcal, closeTo(100.5, 0.1));
    });

    test('RecipeIngredient JSON Serialization and Deserialization preserves custom servings', () {
      final food = Food(
        id: 'f_custom_1',
        name: 'Biscotti Integrali',
        caloriesPer100g: 450,
        proteinsPer100g: 8,
        carbsPer100g: 65,
        fatsPer100g: 16,
        customServingGrams: 40.0,
        customServingName: 'Porzione (4 biscotti)',
      );

      final ingredient = RecipeIngredient(food: food, amountGrams: 120.0);
      final jsonMap = ingredient.toJson();
      final decoded = RecipeIngredient.fromJson(jsonMap);

      expect(decoded.amountGrams, equals(120.0));
      expect(decoded.food.name, equals('Biscotti Integrali'));
      expect(decoded.food.customServingGrams, equals(40.0));
      expect(decoded.food.customServingName, equals('Porzione (4 biscotti)'));
    });
  });
}
