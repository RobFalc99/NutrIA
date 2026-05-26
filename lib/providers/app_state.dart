import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../data/local/entities/daily_log_entity.dart';
import '../data/local/entities/user_profile_entity.dart';
import '../data/remote/online_database_service.dart';
import '../data/remote/gemini_service.dart';
import '../domain/models.dart';

class AppState extends ChangeNotifier {
  final Isar isar;
  final onlineService = OnlineDatabaseService();

  UserProfileEntity? currentUser;
  DailyLogEntity? currentDayLog;
  List<DailyLogEntity> _weeklyLogs = [];

  List<Food> _customFoods = [];
  List<Meal> _customMeals = [];
  bool isLoadingOnline = false;

  AppState(this.isar) {
    _init();
  }

  List<Food> get customFoods => _customFoods;
  List<Meal> get customMeals => _customMeals;

  Future<void> _init() async {
    // Carica Profilo
    currentUser = await isar.userProfileEntitys.where().findFirst();
    if (currentUser == null) {
      final newUser = UserProfileEntity();
      await isar.writeTxn(() async {
        await isar.userProfileEntitys.put(newUser);
      });
      currentUser = newUser;
    }

    // Carica la giornata di oggi
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    currentDayLog = await isar.dailyLogEntitys.where().dateEqualTo(today).findFirst();
    
    if (currentDayLog == null) {
      final newLog = DailyLogEntity()
        ..date = today
        ..isTracked = currentUser?.use8020Mode ?? true;
        
      await isar.writeTxn(() async {
        await isar.dailyLogEntitys.put(newLog);
      });
      currentDayLog = newLog;
    }

    // Carica i log degli ultimi 7 giorni
    final weekStart = today.subtract(const Duration(days: 6));
    _weeklyLogs = await isar.dailyLogEntitys
        .filter()
        .dateGreaterThan(weekStart.subtract(const Duration(seconds: 1)))
        .and()
        .dateLessThan(today.add(const Duration(seconds: 1)))
        .findAll();

    // Inserisci quello di oggi in _weeklyLogs se non c'è già
    if (!_weeklyLogs.any((e) => _isSameDay(e.date, today))) {
      _weeklyLogs.add(currentDayLog!);
    }

    // *** NOTIFICA SUBITO dopo aver caricato dati locali ***
    // Così Dashboard e ProfileScreen si aggiornano immediatamente
    // senza dover aspettare il completamento della chiamata di rete.
    notifyListeners();

    // Carica cibi online (operazione di rete, in background)
    await loadOnlineData();
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  // Carica i dati dal servizio online mockato
  Future<void> loadOnlineData() async {
    isLoadingOnline = true;
    notifyListeners();
    try {
      _customFoods = await onlineService.getCustomFoods();
      _customMeals = await onlineService.getCustomMeals();
    } catch (e) {
      print('Errore caricamento dati online: $e');
    } finally {
      isLoadingOnline = false;
      notifyListeners();
    }
  }

  // Salva un cibo personalizzato online ed aggiorna la lista locale in-memory
  Future<void> saveCustomFood(Food food) async {
    isLoadingOnline = true;
    notifyListeners();
    try {
      await onlineService.saveCustomFood(food);
      _customFoods = await onlineService.getCustomFoods();
    } catch (e) {
      print('Errore salvataggio cibo online: $e');
    } finally {
      isLoadingOnline = false;
      notifyListeners();
    }
  }

  // Salva una ricetta online
  Future<void> saveCustomMeal(Meal meal) async {
    isLoadingOnline = true;
    notifyListeners();
    try {
      await onlineService.saveCustomMeal(meal);
      _customMeals = await onlineService.getCustomMeals();
    } catch (e) {
      print('Errore salvataggio ricetta online: $e');
    } finally {
      isLoadingOnline = false;
      notifyListeners();
    }
  }

  // Istanzia dinamicamente GeminiService se l'utente ha inserito una chiave API valida
  GeminiService? get geminiService {
    final key = currentUser?.geminiApiKey;
    if (key == null || key.trim().isEmpty) return null;
    return GeminiService(apiKey: key);
  }

  // Aggiungi un bicchiere d'acqua
  Future<void> addWaterGlass() async {
    if (currentDayLog != null) {
      await isar.writeTxn(() async {
        currentDayLog!.waterGlasses += 1;
        await isar.dailyLogEntitys.put(currentDayLog!);
      });
      // Aggiorna in _weeklyLogs
      final index = _weeklyLogs.indexWhere((e) => _isSameDay(e.date, currentDayLog!.date));
      if (index != -1) {
        _weeklyLogs[index] = currentDayLog!;
      }
      notifyListeners();
    }
  }

  // Rimuovi un bicchiere d'acqua
  Future<void> removeWaterGlass() async {
    if (currentDayLog != null && currentDayLog!.waterGlasses > 0) {
      await isar.writeTxn(() async {
        currentDayLog!.waterGlasses -= 1;
        await isar.dailyLogEntitys.put(currentDayLog!);
      });
      // Aggiorna in _weeklyLogs
      final index = _weeklyLogs.indexWhere((e) => _isSameDay(e.date, currentDayLog!.date));
      if (index != -1) {
        _weeklyLogs[index] = currentDayLog!;
      }
      notifyListeners();
    }
  }

  // Cambia il flag di tracciamento per oggi (80/20 cheat day toggle)
  Future<void> toggleTrackedCurrentDay() async {
    if (currentDayLog != null) {
      await isar.writeTxn(() async {
        currentDayLog!.isTracked = !currentDayLog!.isTracked;
        await isar.dailyLogEntitys.put(currentDayLog!);
      });
      // Aggiorna in _weeklyLogs
      final index = _weeklyLogs.indexWhere((e) => _isSameDay(e.date, currentDayLog!.date));
      if (index != -1) {
        _weeklyLogs[index] = currentDayLog!;
      } else {
        _weeklyLogs.add(currentDayLog!);
      }
      notifyListeners();
    }
  }

  // Aggiorna il profilo utente in Isar
  Future<void> updateProfile(UserProfileEntity profile) async {
    await isar.writeTxn(() async {
      await isar.userProfileEntitys.put(profile);
    });
    currentUser = profile;
    notifyListeners();
  }

  // Aggiunge un alimento ad un determinato pasto nel diario giornaliero
  Future<void> addMealItem(String mealName, Food food, double amountGrams) async {
    if (currentDayLog == null) return;

    await isar.writeTxn(() async {
      var mealList = List<MealEntity>.from(currentDayLog!.meals);
      var mealIndex = mealList.indexWhere((m) => m.name == mealName);
      
      final newItem = MealItemEntity()
        ..foodId = food.id
        ..foodName = food.name
        ..caloriesPer100g = food.caloriesPer100g
        ..proteinsPer100g = food.proteinsPer100g
        ..carbsPer100g = food.carbsPer100g
        ..fatsPer100g = food.fatsPer100g
        ..fibersPer100g = food.fibersPer100g
        ..amountGrams = amountGrams
        ..isOnline = food.isOnline;

      if (mealIndex == -1) {
        final newMeal = MealEntity()
          ..id = 'meal_${DateTime.now().millisecondsSinceEpoch}'
          ..name = mealName
          ..items = [newItem];
        mealList.add(newMeal);
      } else {
        final updatedItems = List<MealItemEntity>.from(mealList[mealIndex].items)..add(newItem);
        mealList[mealIndex] = MealEntity()
          ..id = mealList[mealIndex].id
          ..name = mealList[mealIndex].name
          ..isCustomOnline = mealList[mealIndex].isCustomOnline
          ..items = updatedItems;
      }

      currentDayLog!.meals = mealList;
      await isar.dailyLogEntitys.put(currentDayLog!);
    });

    // Aggiorna in _weeklyLogs
    final index = _weeklyLogs.indexWhere((e) => _isSameDay(e.date, currentDayLog!.date));
    if (index != -1) {
      _weeklyLogs[index] = currentDayLog!;
    } else {
      _weeklyLogs.add(currentDayLog!);
    }

    notifyListeners();
  }

  // Rimuove un alimento da un pasto del diario giornaliero
  Future<void> removeMealItem(String mealName, int itemIndex) async {
    if (currentDayLog == null) return;

    await isar.writeTxn(() async {
      var mealList = List<MealEntity>.from(currentDayLog!.meals);
      var mealIndex = mealList.indexWhere((m) => m.name == mealName);
      if (mealIndex != -1) {
        final updatedItems = List<MealItemEntity>.from(mealList[mealIndex].items);
        if (itemIndex >= 0 && itemIndex < updatedItems.length) {
          updatedItems.removeAt(itemIndex);
          
          if (updatedItems.isEmpty) {
            mealList.removeAt(mealIndex);
          } else {
            mealList[mealIndex] = MealEntity()
              ..id = mealList[mealIndex].id
              ..name = mealList[mealIndex].name
              ..isCustomOnline = mealList[mealIndex].isCustomOnline
              ..items = updatedItems;
          }
          
          currentDayLog!.meals = mealList;
          await isar.dailyLogEntitys.put(currentDayLog!);
        }
      }
    });

    // Aggiorna in _weeklyLogs
    final index = _weeklyLogs.indexWhere((e) => _isSameDay(e.date, currentDayLog!.date));
    if (index != -1) {
      _weeklyLogs[index] = currentDayLog!;
    } else {
      _weeklyLogs.add(currentDayLog!);
    }

    notifyListeners();
  }

  // Mappa la struttura Isar a quella di dominio per fare calcoli statistici coerenti
  DailyLog _mapEntityToDomain(DailyLogEntity entity) {
    return DailyLog(
      date: entity.date,
      waterGlasses: entity.waterGlasses,
      isTracked: entity.isTracked,
      meals: entity.meals.map((me) {
        return Meal(
          id: me.id ?? '',
          name: me.name ?? '',
          isCustomOnline: me.isCustomOnline,
          items: me.items.map((ie) {
            return MealItem(
              food: Food(
                id: ie.foodId ?? '',
                name: ie.foodName ?? 'Sconosciuto',
                caloriesPer100g: ie.caloriesPer100g,
                proteinsPer100g: ie.proteinsPer100g,
                carbsPer100g: ie.carbsPer100g,
                fatsPer100g: ie.fatsPer100g,
                fibersPer100g: ie.fibersPer100g,
              ),
              amountGrams: ie.amountGrams,
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  // Costruisce ed espone la WeeklyStats combinando il diario storico con Isar
  WeeklyStats get weeklyStats {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = <DailyLog>[];
    for (int i = 6; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final entity = _weeklyLogs.firstWhere(
        (element) => _isSameDay(element.date, d),
        orElse: () => DailyLogEntity()..date = d..isTracked = currentUser?.use8020Mode ?? true,
      );
      days.add(_mapEntityToDomain(entity));
    }
    return WeeklyStats(
      startDate: today.subtract(const Duration(days: 6)),
      endDate: today,
      days: days,
    );
  }

  // Getter macro per il giorno corrente
  double get currentCalories {
    if (currentDayLog == null) return 0;
    return currentDayLog!.meals.fold(0.0, (sum, meal) {
      return sum + meal.items.fold(0.0, (s, item) => s + ((item.caloriesPer100g * item.amountGrams) / 100));
    });
  }

  double get currentProteins {
    if (currentDayLog == null) return 0;
    return currentDayLog!.meals.fold(0.0, (sum, meal) {
      return sum + meal.items.fold(0.0, (s, item) => s + ((item.proteinsPer100g * item.amountGrams) / 100));
    });
  }

  double get currentCarbs {
    if (currentDayLog == null) return 0;
    return currentDayLog!.meals.fold(0.0, (sum, meal) {
      return sum + meal.items.fold(0.0, (s, item) => s + ((item.carbsPer100g * item.amountGrams) / 100));
    });
  }

  double get currentFats {
    if (currentDayLog == null) return 0;
    return currentDayLog!.meals.fold(0.0, (sum, meal) {
      return sum + meal.items.fold(0.0, (s, item) => s + ((item.fatsPer100g * item.amountGrams) / 100));
    });
  }

  double get currentFibers {
    if (currentDayLog == null) return 0;
    return currentDayLog!.meals.fold(0.0, (sum, meal) {
      return sum + meal.items.fold(0.0, (s, item) => s + ((item.fibersPer100g * item.amountGrams) / 100));
    });
  }
}

