import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../../domain/models.dart';

class OnlineDatabaseService {
  // Database in-memory simulato per i cibi personali
  static final List<Food> _mockOnlineFoods = [
    Food(
      id: 'online_1',
      name: 'Pane fatto in casa di Mamma',
      brand: 'Casereccio',
      caloriesPer100g: 265,
      proteinsPer100g: 9.0,
      carbsPer100g: 49.0,
      fatsPer100g: 1.5,
      fibersPer100g: 3.5,
      isCustom: true,
      isOnline: true,
    ),
    Food(
      id: 'online_2',
      name: 'Riso e Pollo della Domenica',
      brand: 'Ricetta Casa',
      caloriesPer100g: 155,
      proteinsPer100g: 18.0,
      carbsPer100g: 15.0,
      fatsPer100g: 2.5,
      fibersPer100g: 0.8,
      isCustom: true,
      isOnline: true,
    ),
  ];

  // Database in-memory simulato per i pasti (ricette preconfigurate)
  static final List<Meal> _mockOnlineMeals = [];

  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final foodsFile = File('${dir.path}/custom_foods.json');
      if (await foodsFile.exists()) {
        final content = await foodsFile.readAsString();
        final List<dynamic> decoded = json.decode(content);
        final loadedFoods = decoded.map((item) {
          return Food(
            id: item['id'] as String,
            name: item['name'] as String,
            brand: item['brand'] as String?,
            caloriesPer100g: (item['caloriesPer100g'] as num).toDouble(),
            proteinsPer100g: (item['proteinsPer100g'] as num).toDouble(),
            carbsPer100g: (item['carbsPer100g'] as num).toDouble(),
            fatsPer100g: (item['fatsPer100g'] as num).toDouble(),
            fibersPer100g: (item['fibersPer100g'] as num).toDouble(),
            isCustom: true,
            isOnline: true,
          );
        }).toList();
        _mockOnlineFoods.clear();
        _mockOnlineFoods.addAll(loadedFoods);
      } else {
        await _saveFoodsToDisk();
      }
      
      final mealsFile = File('${dir.path}/custom_meals.json');
      if (await mealsFile.exists()) {
        final content = await mealsFile.readAsString();
        final List<dynamic> decoded = json.decode(content);
        final loadedMeals = decoded.map((item) {
          final itemsList = (item['items'] as List).map((i) {
            final foodMap = i['food'];
            return MealItem(
              food: Food(
                id: foodMap['id'] as String,
                name: foodMap['name'] as String,
                brand: foodMap['brand'] as String?,
                caloriesPer100g: (foodMap['caloriesPer100g'] as num).toDouble(),
                proteinsPer100g: (foodMap['proteinsPer100g'] as num).toDouble(),
                carbsPer100g: (foodMap['carbsPer100g'] as num).toDouble(),
                fatsPer100g: (foodMap['fatsPer100g'] as num).toDouble(),
                fibersPer100g: (foodMap['fibersPer100g'] as num).toDouble(),
                isCustom: foodMap['isCustom'] as bool? ?? true,
                isOnline: foodMap['isOnline'] as bool? ?? true,
              ),
              amountGrams: (i['amountGrams'] as num).toDouble(),
            );
          }).toList();
          return Meal(
            id: item['id'] as String,
            name: item['name'] as String,
            items: itemsList,
            isCustomOnline: true,
          );
        }).toList();
        
        for (final meal in loadedMeals) {
          if (!_mockOnlineMeals.any((m) => m.id == meal.id)) {
            _mockOnlineMeals.add(meal);
          }
        }
      }
      _loaded = true;
    } catch (e) {
      print('Errore caricamento dati persistenti: $e');
    }
  }

  Future<void> _saveFoodsToDisk() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final foodsFile = File('${dir.path}/custom_foods.json');
      final list = _mockOnlineFoods.map((f) => {
        'id': f.id,
        'name': f.name,
        'brand': f.brand,
        'caloriesPer100g': f.caloriesPer100g,
        'proteinsPer100g': f.proteinsPer100g,
        'carbsPer100g': f.carbsPer100g,
        'fatsPer100g': f.fatsPer100g,
        'fibersPer100g': f.fibersPer100g,
      }).toList();
      await foodsFile.writeAsString(json.encode(list));
    } catch (e) {
      print('Errore salvataggio cibi su disco: $e');
    }
  }

  Future<void> _saveMealsToDisk() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final mealsFile = File('${dir.path}/custom_meals.json');
      final list = _mockOnlineMeals.map((m) => {
        'id': m.id,
        'name': m.name,
        'items': m.items.map((i) => {
          'amountGrams': i.amountGrams,
          'food': {
            'id': i.food.id,
            'name': i.food.name,
            'brand': i.food.brand,
            'caloriesPer100g': i.food.caloriesPer100g,
            'proteinsPer100g': i.food.proteinsPer100g,
            'carbsPer100g': i.food.carbsPer100g,
            'fatsPer100g': i.food.fatsPer100g,
            'fibersPer100g': i.food.fibersPer100g,
            'isCustom': i.food.isCustom,
            'isOnline': i.food.isOnline,
          }
        }).toList()
      }).toList();
      await mealsFile.writeAsString(json.encode(list));
    } catch (e) {
      print('Errore salvataggio ricette su disco: $e');
    }
  }

  /// Recupera tutti gli alimenti personali salvati in cloud / locale
  Future<List<Food>> getCustomFoods() async {
    await _ensureLoaded();
    // Simula ritardo di rete (HTTP call)
    await Future.delayed(const Duration(milliseconds: 600));
    return List.from(_mockOnlineFoods);
  }

  /// Salva o modifica un alimento personale in cloud / locale
  Future<bool> saveCustomFood(Food food) async {
    await _ensureLoaded();
    await Future.delayed(const Duration(milliseconds: 800));
    final isExisting = food.id.startsWith('online_');
    final finalId = isExisting ? food.id : 'online_${DateTime.now().millisecondsSinceEpoch}';
    
    final onlineFood = Food(
      id: finalId,
      name: food.name,
      brand: food.brand,
      caloriesPer100g: food.caloriesPer100g,
      proteinsPer100g: food.proteinsPer100g,
      carbsPer100g: food.carbsPer100g,
      fatsPer100g: food.fatsPer100g,
      fibersPer100g: food.fibersPer100g,
      isCustom: true,
      isOnline: true,
    );

    if (isExisting) {
      _mockOnlineFoods.removeWhere((f) => f.id == finalId);
    }
    _mockOnlineFoods.add(onlineFood);
    await _saveFoodsToDisk();
    return true;
  }

  /// Elimina un alimento personale
  Future<bool> deleteCustomFood(String foodId) async {
    await _ensureLoaded();
    await Future.delayed(const Duration(milliseconds: 500));
    _mockOnlineFoods.removeWhere((f) => f.id == foodId);
    await _saveFoodsToDisk();
    return true;
  }

  /// Recupera i pasti personali salvati in cloud (es. ricette composte)
  Future<List<Meal>> getCustomMeals() async {
    await _ensureLoaded();
    await Future.delayed(const Duration(milliseconds: 600));
    return List.from(_mockOnlineMeals);
  }

  /// Salva un pasto composto (ricetta) in cloud / locale
  Future<bool> saveCustomMeal(Meal meal) async {
    await _ensureLoaded();
    await Future.delayed(const Duration(milliseconds: 800));
    final onlineMeal = Meal(
      id: 'meal_online_${DateTime.now().millisecondsSinceEpoch}',
      name: meal.name,
      items: meal.items,
      isCustomOnline: true,
    );
    _mockOnlineMeals.add(onlineMeal);
    await _saveMealsToDisk();
    return true;
  }
}
