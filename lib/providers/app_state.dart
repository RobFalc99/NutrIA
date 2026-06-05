import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  bool _isProfileDirty = false;
  bool get isProfileDirty => _isProfileDirty;
  set isProfileDirty(bool val) {
    if (_isProfileDirty != val) {
      _isProfileDirty = val;
      notifyListeners();
    }
  }

  VoidCallback? saveProfileCallback;

  DateTime _selectedDate = _normalizeDate(DateTime.now());
  DateTime get selectedDate => _selectedDate;

  // Normalizza sempre a mezzanotte locale (evita problemi UTC/timezone)
  static DateTime _normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day);

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

    await loadDayLog(_selectedDate);

    // *** NOTIFICA SUBITO dopo aver caricato dati locali ***
    notifyListeners();

    // Carica cibi online (operazione di rete, in background)
    await loadOnlineData();
  }

  Future<void> setSelectedDate(DateTime date) async {
    _selectedDate = _normalizeDate(date);
    await loadDayLog(_selectedDate);
  }

  Future<void> nextDay() async {
    await setSelectedDate(_selectedDate.add(const Duration(days: 1)));
  }

  Future<void> previousDay() async {
    await setSelectedDate(_selectedDate.subtract(const Duration(days: 1)));
  }

  Future<void> loadDayLog(DateTime date) async {
    final normalizedDate = _normalizeDate(date);
    
    // Usa un range di 24 ore per trovare il log del giorno,
    // evitando problemi di timezone/UTC con il confronto esatto
    final dayStart = normalizedDate;
    final dayEnd = normalizedDate.add(const Duration(hours: 23, minutes: 59, seconds: 59));
    
    final existing = await isar.dailyLogEntitys
        .filter()
        .dateGreaterThan(dayStart.subtract(const Duration(seconds: 1)))
        .and()
        .dateLessThan(dayEnd.add(const Duration(seconds: 1)))
        .findAll();
    
    // Cerca il record che ha la stessa data (giorno)
    DailyLogEntity? found;
    for (final e in existing) {
      if (_isSameDay(e.date, normalizedDate)) {
        found = e;
        break;
      }
    }
    
    if (found != null) {
      currentDayLog = found;
    } else {
      // Crea un nuovo log solo se non esiste
      final newLog = DailyLogEntity()
        ..date = normalizedDate
        ..waterMl = 0
        ..waterGlasses = 0
        ..isTracked = currentUser?.use8020Mode ?? true;
        
      await isar.writeTxn(() async {
        await isar.dailyLogEntitys.put(newLog);
      });
      currentDayLog = newLog;
    }

    // Carica i log dei 7 giorni per le statistiche settimanali
    final weekStart = normalizedDate.subtract(const Duration(days: 6));
    _weeklyLogs = await isar.dailyLogEntitys
        .filter()
        .dateGreaterThan(weekStart.subtract(const Duration(seconds: 1)))
        .and()
        .dateLessThan(dayEnd.add(const Duration(seconds: 1)))
        .findAll();

    if (!_weeklyLogs.any((e) => _isSameDay(e.date, normalizedDate))) {
      _weeklyLogs.add(currentDayLog!);
    }

    notifyListeners();
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

  // Elimina un cibo personalizzato ed aggiorna la lista locale in-memory
  Future<void> deleteCustomFood(String foodId) async {
    isLoadingOnline = true;
    notifyListeners();
    try {
      await onlineService.deleteCustomFood(foodId);
      _customFoods = await onlineService.getCustomFoods();
    } catch (e) {
      print('Errore eliminazione cibo online: $e');
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
    final model = currentUser?.geminiModel;
    return GeminiService(
      apiKey: key,
      modelName: (model == null || model.trim().isEmpty) ? 'gemini-2.0-flash-lite' : model.trim(),
    );
  }

  // Aggiungi un bicchiere d'acqua (250 ml di default)
  Future<void> addWaterGlass() async {
    await addWaterMl(250);
  }

  // Rimuovi un bicchiere d'acqua (250 ml di default)
  Future<void> removeWaterGlass() async {
    await removeWaterMl(250);
  }

  // Aggiungi acqua in ml
  Future<void> addWaterMl(int ml) async {
    if (currentDayLog != null) {
      await isar.writeTxn(() async {
        // Se waterMl era a 0 ma waterGlasses era popolato, facciamo fallback
        if (currentDayLog!.waterMl == 0 && currentDayLog!.waterGlasses > 0) {
          currentDayLog!.waterMl = currentDayLog!.waterGlasses * 250;
        }
        currentDayLog!.waterMl += ml;
        currentDayLog!.waterGlasses = (currentDayLog!.waterMl / 250).ceil();
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

  // Rimuovi acqua in ml
  Future<void> removeWaterMl(int ml) async {
    if (currentDayLog != null) {
      // Se waterMl era a 0 ma waterGlasses era popolato, facciamo fallback
      if (currentDayLog!.waterMl == 0 && currentDayLog!.waterGlasses > 0) {
        currentDayLog!.waterMl = currentDayLog!.waterGlasses * 250;
      }
      if (currentDayLog!.waterMl > 0) {
        await isar.writeTxn(() async {
          currentDayLog!.waterMl = (currentDayLog!.waterMl - ml).clamp(0, 99999);
          currentDayLog!.waterGlasses = (currentDayLog!.waterMl / 250).ceil();
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

  // Modifica la quantità di un alimento già inserito in un pasto
  Future<void> updateMealItemAmount(String mealName, int itemIndex, double newGrams) async {
    if (currentDayLog == null) return;

    await isar.writeTxn(() async {
      var mealList = List<MealEntity>.from(currentDayLog!.meals);
      var mealIndex = mealList.indexWhere((m) => m.name == mealName);
      if (mealIndex != -1) {
        final updatedItems = List<MealItemEntity>.from(mealList[mealIndex].items);
        if (itemIndex >= 0 && itemIndex < updatedItems.length) {
          final existing = updatedItems[itemIndex];
          final updated = MealItemEntity()
            ..foodId = existing.foodId
            ..foodName = existing.foodName
            ..caloriesPer100g = existing.caloriesPer100g
            ..proteinsPer100g = existing.proteinsPer100g
            ..carbsPer100g = existing.carbsPer100g
            ..fatsPer100g = existing.fatsPer100g
            ..fibersPer100g = existing.fibersPer100g
            ..amountGrams = newGrams
            ..isOnline = existing.isOnline;
          updatedItems[itemIndex] = updated;

          mealList[mealIndex] = MealEntity()
            ..id = mealList[mealIndex].id
            ..name = mealList[mealIndex].name
            ..isCustomOnline = mealList[mealIndex].isCustomOnline
            ..items = updatedItems;

          currentDayLog!.meals = mealList;
          await isar.dailyLogEntitys.put(currentDayLog!);
        }
      }
    });

    final index = _weeklyLogs.indexWhere((e) => _isSameDay(e.date, currentDayLog!.date));
    if (index != -1) {
      _weeklyLogs[index] = currentDayLog!;
    } else {
      _weeklyLogs.add(currentDayLog!);
    }
    notifyListeners();
  }


  DailyLog _mapEntityToDomain(DailyLogEntity entity) {
    return DailyLog(
      date: entity.date,
      waterGlasses: entity.waterGlasses,
      waterMl: (entity.waterMl == 0 && entity.waterGlasses > 0) ? entity.waterGlasses * 250 : entity.waterMl,
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

  // Ottieni la cronologia degli alimenti usati
  Future<List<Food>> getFoodHistory() async {
    try {
      final logs = await isar.dailyLogEntitys.where().findAll();
      final Map<String, Food> uniqueFoods = {};
      for (final log in logs) {
        for (final meal in log.meals) {
          for (final item in meal.items) {
            if (item.foodId != null && item.foodName != null) {
              uniqueFoods[item.foodId!] = Food(
                id: item.foodId!,
                name: item.foodName!,
                caloriesPer100g: item.caloriesPer100g,
                proteinsPer100g: item.proteinsPer100g,
                carbsPer100g: item.carbsPer100g,
                fatsPer100g: item.fatsPer100g,
                fibersPer100g: item.fibersPer100g,
                isOnline: item.isOnline,
              );
            }
          }
        }
      }
      final list = uniqueFoods.values.toList().reversed.toList();
      return list.take(currentUser?.historyLimit ?? 100).toList();
    } catch (e) {
      print('Errore caricamento cronologia cibi: $e');
      return [];
    }
  }

  // Costruisce ed espone la WeeklyStats combinando il diario storico con Isar
  // Usa gli ultimi 7 giorni ESCLUDENDO oggi (ieri → 7 giorni fa)
  WeeklyStats get weeklyStats {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final days = <DailyLog>[];

    // Giorni da 7 giorni fa a ieri (escluso oggi)
    for (int i = 7; i >= 1; i--) {
      final d = today.subtract(Duration(days: i));
      final entity = _weeklyLogs.firstWhere(
        (element) => _isSameDay(element.date, d),
        orElse: () => DailyLogEntity()..date = d..isTracked = currentUser?.use8020Mode ?? true,
      );
      days.add(_mapEntityToDomain(entity));
    }

    return WeeklyStats(
      startDate: today.subtract(const Duration(days: 7)),
      endDate: yesterday,
      days: days,
    );
  }

  // True se ci sono almeno 7 giorni con log reali (pasti inseriti) nel DB
  bool get hasEnoughDataForAverage {
    // Conta i giorni (escluso oggi) che hanno almeno 1 pasto
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int count = 0;
    for (final log in _weeklyLogs) {
      if (!_isSameDay(log.date, today) && log.meals.isNotEmpty) {
        count++;
      }
    }
    return count >= 7;
  }

  // Calcola la streak: giorni consecutivi con almeno 1 pasto tracciato (a partire da oggi)
  Future<int> getTrackingStreak() async {
    final allLogs = await isar.dailyLogEntitys.where().findAll();
    final trackedDays = allLogs
        .where((log) => log.meals.isNotEmpty)
        .map((log) => _normalizeDate(log.date))
        .toSet();

    final today = _normalizeDate(DateTime.now());
    int streak = 0;
    DateTime check = today;
    while (trackedDays.contains(check)) {
      streak++;
      check = check.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // Restituisce il set di tutte le date con almeno 1 pasto tracciato (per calendario storico)
  Future<Set<DateTime>> getTrackedDays() async {
    final allLogs = await isar.dailyLogEntitys.where().findAll();
    return allLogs
        .where((log) => log.meals.isNotEmpty)
        .map((log) => _normalizeDate(log.date))
        .toSet();
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

  @override
  void notifyListeners() {
    super.notifyListeners();
    _updateNativeWidget();
  }

  void _updateNativeWidget() {
    try {
      final calories = currentCalories;
      final goal = currentUser?.goalCalories ?? 2000.0;
      final water = (currentDayLog != null)
          ? ((currentDayLog!.waterMl == 0 && currentDayLog!.waterGlasses > 0)
              ? currentDayLog!.waterGlasses * 250
              : currentDayLog!.waterMl)
          : 0;

      final proteins = currentProteins;
      final goalProteins = currentUser?.goalProteins ?? 150.0;
      final carbs = currentCarbs;
      final goalCarbs = currentUser?.goalCarbs ?? 200.0;
      final fats = currentFats;
      final goalFats = currentUser?.goalFats ?? 60.0;

      const MethodChannel('com.example.kcal/widget').invokeMethod('updateWidget', {
        'calories': calories.round(),
        'goal': goal.round(),
        'water': water,
        'proteins': proteins.round(),
        'goalProteins': goalProteins.round(),
        'carbs': carbs.round(),
        'goalCarbs': goalCarbs.round(),
        'fats': fats.round(),
        'goalFats': goalFats.round(),
      }).catchError((e) {
        // Ignora l'errore se la piattaforma non è ancora pronta o non è supportata
      });
    } catch (e) {
      // Ignora errori di setup iniziale
    }
  }
}

