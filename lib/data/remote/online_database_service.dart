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

  /// Recupera tutti gli alimenti personali salvati in cloud
  Future<List<Food>> getCustomFoods() async {
    // Simula ritardo di rete (HTTP call)
    await Future.delayed(const Duration(milliseconds: 600));
    return List.from(_mockOnlineFoods);
  }

  /// Salva un nuovo alimento personale in cloud
  Future<bool> saveCustomFood(Food food) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final onlineFood = Food(
      id: food.id.startsWith('online_') ? food.id : 'online_${DateTime.now().millisecondsSinceEpoch}',
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
    _mockOnlineFoods.add(onlineFood);
    return true;
  }

  /// Recupera i pasti personali salvati in cloud (es. ricette composte)
  Future<List<Meal>> getCustomMeals() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return List.from(_mockOnlineMeals);
  }

  /// Salva un pasto composto (ricetta) in cloud
  Future<bool> saveCustomMeal(Meal meal) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final onlineMeal = Meal(
      id: 'meal_online_${DateTime.now().millisecondsSinceEpoch}',
      name: meal.name,
      items: meal.items,
      isCustomOnline: true,
    );
    _mockOnlineMeals.add(onlineMeal);
    return true;
  }
}
