class Food {
  final String id;
  final String name;
  final String? brand;
  final double caloriesPer100g;
  final double proteinsPer100g;
  final double carbsPer100g;
  final double fatsPer100g;
  final double fibersPer100g; // Aggiunto per tracciamento custom
  final bool isCustom; // True se è un alimento personale creato dall'utente
  final bool isOnline; // True se salvato sul DB online, False se locale/OpenFoodFacts
  final double? estimatedAmountGrams; // Aggiunto per stima quantità dall'IA
  final double? customServingGrams; // Porzione personalizzata abituale (es. 40g, 50g)
  final String? customServingName; // Nome opzionale della porzione (es. "Porzione", "Pancake", "Fetta")
  final bool isRecipe; // True se creato tramite Recipe Builder
  final String? recipeIngredientsJson; // Dettagli completi ingredienti in JSON per ri-modifica
  final double? recipeTotalWeightGrams; // Peso totale cotto / finale
  final double? recipeServingsCount; // Numero porzioni

  Food({
    required this.id,
    required this.name,
    this.brand,
    required this.caloriesPer100g,
    required this.proteinsPer100g,
    required this.carbsPer100g,
    required this.fatsPer100g,
    this.fibersPer100g = 0.0,
    this.isCustom = false,
    this.isOnline = false,
    this.estimatedAmountGrams,
    this.customServingGrams,
    this.customServingName,
    this.isRecipe = false,
    this.recipeIngredientsJson,
    this.recipeTotalWeightGrams,
    this.recipeServingsCount,
  });

  Food copyWith({
    String? id,
    String? name,
    String? brand,
    double? caloriesPer100g,
    double? proteinsPer100g,
    double? carbsPer100g,
    double? fatsPer100g,
    double? fibersPer100g,
    bool? isCustom,
    bool? isOnline,
    double? estimatedAmountGrams,
    double? customServingGrams,
    String? customServingName,
    bool? isRecipe,
    String? recipeIngredientsJson,
    double? recipeTotalWeightGrams,
    double? recipeServingsCount,
  }) {
    return Food(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      caloriesPer100g: caloriesPer100g ?? this.caloriesPer100g,
      proteinsPer100g: proteinsPer100g ?? this.proteinsPer100g,
      carbsPer100g: carbsPer100g ?? this.carbsPer100g,
      fatsPer100g: fatsPer100g ?? this.fatsPer100g,
      fibersPer100g: fibersPer100g ?? this.fibersPer100g,
      isCustom: isCustom ?? this.isCustom,
      isOnline: isOnline ?? this.isOnline,
      estimatedAmountGrams: estimatedAmountGrams ?? this.estimatedAmountGrams,
      customServingGrams: customServingGrams ?? this.customServingGrams,
      customServingName: customServingName ?? this.customServingName,
      isRecipe: isRecipe ?? this.isRecipe,
      recipeIngredientsJson: recipeIngredientsJson ?? this.recipeIngredientsJson,
      recipeTotalWeightGrams: recipeTotalWeightGrams ?? this.recipeTotalWeightGrams,
      recipeServingsCount: recipeServingsCount ?? this.recipeServingsCount,
    );
  }
}

class RecipeIngredient {
  final Food food;
  final double amountGrams;

  RecipeIngredient({required this.food, required this.amountGrams});

  double get calories => (food.caloriesPer100g * amountGrams) / 100;
  double get proteins => (food.proteinsPer100g * amountGrams) / 100;
  double get carbs => (food.carbsPer100g * amountGrams) / 100;
  double get fats => (food.fatsPer100g * amountGrams) / 100;
  double get fibers => (food.fibersPer100g * amountGrams) / 100;

  Map<String, dynamic> toJson() => {
    'amountGrams': amountGrams,
    'food': {
      'id': food.id,
      'name': food.name,
      'brand': food.brand,
      'caloriesPer100g': food.caloriesPer100g,
      'proteinsPer100g': food.proteinsPer100g,
      'carbsPer100g': food.carbsPer100g,
      'fatsPer100g': food.fatsPer100g,
      'fibersPer100g': food.fibersPer100g,
      'customServingGrams': food.customServingGrams,
      'customServingName': food.customServingName,
    }
  };

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    final foodMap = json['food'] as Map<String, dynamic>;
    return RecipeIngredient(
      amountGrams: (json['amountGrams'] as num).toDouble(),
      food: Food(
        id: foodMap['id'] as String? ?? 'ing_${DateTime.now().microsecondsSinceEpoch}',
        name: foodMap['name'] as String? ?? '',
        brand: foodMap['brand'] as String?,
        caloriesPer100g: (foodMap['caloriesPer100g'] as num?)?.toDouble() ?? 0.0,
        proteinsPer100g: (foodMap['proteinsPer100g'] as num?)?.toDouble() ?? 0.0,
        carbsPer100g: (foodMap['carbsPer100g'] as num?)?.toDouble() ?? 0.0,
        fatsPer100g: (foodMap['fatsPer100g'] as num?)?.toDouble() ?? 0.0,
        fibersPer100g: (foodMap['fibersPer100g'] as num?)?.toDouble() ?? 0.0,
        customServingGrams: (foodMap['customServingGrams'] as num?)?.toDouble(),
        customServingName: foodMap['customServingName'] as String?,
      ),
    );
  }
}

class MealItem {
  final Food food;
  final double amountGrams;
  final String? targetMeal; // Aggiunto per stima "Tutta la giornata"

  MealItem({
    required this.food,
    required this.amountGrams,
    this.targetMeal,
  });

  // Calcoli derivati in base alla grammatura
  double get calories => (food.caloriesPer100g * amountGrams) / 100;
  double get proteins => (food.proteinsPer100g * amountGrams) / 100;
  double get carbs => (food.carbsPer100g * amountGrams) / 100;
  double get fats => (food.fatsPer100g * amountGrams) / 100;
  double get fibers => (food.fibersPer100g * amountGrams) / 100;
}

class Meal {
  final String id;
  final String name; // es. "Colazione", "Spuntino", "Pasto Libero"
  final List<MealItem> items;
  final bool isCustomOnline; // Se l'utente salva questa combinazione come "Pasto Personale" online

  Meal({
    required this.id,
    required this.name,
    required this.items,
    this.isCustomOnline = false,
  });

  double get totalCalories => items.fold(0, (sum, item) => sum + item.calories);
  double get totalProteins => items.fold(0, (sum, item) => sum + item.proteins);
  double get totalCarbs => items.fold(0, (sum, item) => sum + item.carbs);
  double get totalFats => items.fold(0, (sum, item) => sum + item.fats);
  double get totalFibers => items.fold(0, (sum, item) => sum + item.fibers);
}

class DailyLog {
  final DateTime date;
  final List<Meal> meals;
  final int waterGlasses;
  final int waterMl;
  final bool isTracked; // Fondamentale per l'80/20: segna se la giornata fa parte dell'80% tracciato o del 20% libero

  DailyLog({
    required this.date,
    required this.meals,
    this.waterGlasses = 0,
    this.waterMl = 0,
    this.isTracked = true,
  });

  double get dailyCalories => meals.fold(0, (sum, meal) => sum + meal.totalCalories);
  double get dailyProteins => meals.fold(0, (sum, meal) => sum + meal.totalProteins);
  double get dailyCarbs => meals.fold(0, (sum, meal) => sum + meal.totalCarbs);
  double get dailyFats => meals.fold(0, (sum, meal) => sum + meal.totalFats);
  double get dailyFibers => meals.fold(0, (sum, meal) => sum + meal.totalFibers);
}

class WeeklyStats {
  final DateTime startDate; // Lunedì
  final DateTime endDate;   // Domenica
  final List<DailyLog> days;

  WeeklyStats({
    required this.startDate,
    required this.endDate,
    required this.days,
  });

  // Calcolo della media basata SOLO sui giorni tracciati (l'80% del 80/20)
  List<DailyLog> get trackedDays => days.where((d) => d.isTracked).toList();

  double get averageCalories {
    if (trackedDays.isEmpty) return 0;
    double total = trackedDays.fold(0.0, (sum, day) => sum + day.dailyCalories);
    return total / trackedDays.length;
  }

  // Altre medie utili...
  double get averageProteins {
    if (trackedDays.isEmpty) return 0;
    return trackedDays.fold(0.0, (sum, day) => sum + day.dailyProteins) / trackedDays.length;
  }

  double get averageCarbs {
    if (trackedDays.isEmpty) return 0;
    return trackedDays.fold(0.0, (sum, day) => sum + day.dailyCarbs) / trackedDays.length;
  }

  double get averageFats {
    if (trackedDays.isEmpty) return 0;
    return trackedDays.fold(0.0, (sum, day) => sum + day.dailyFats) / trackedDays.length;
  }

  double get averageFibers {
    if (trackedDays.isEmpty) return 0;
    return trackedDays.fold(0.0, (sum, day) => sum + day.dailyFibers) / trackedDays.length;
  }

  // Verifica se la regola 80/20 è rispettata nella settimana corrente
  // Su 7 giorni, l'80% sono circa 5.6 giorni (quindi 5 o 6 giorni tracciati, 1 o 2 liberi)
  double get trackingPercentage => (trackedDays.length / 7) * 100;
}
