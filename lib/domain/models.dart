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
  });
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
