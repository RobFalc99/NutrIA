import 'package:isar/isar.dart';

part 'daily_log_entity.g.dart';

@collection
class DailyLogEntity {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late DateTime date; // Salvato all'inizio del giorno (es. 2024-05-26 00:00:00)

  int waterGlasses = 0;
  bool isTracked = true; // Modalità 80/20

  List<MealEntity> meals = [];
}

@embedded
class MealEntity {
  String? id;
  String? name; // es. "Colazione"
  
  List<MealItemEntity> items = [];
  bool isCustomOnline = false;
}

@embedded
class MealItemEntity {
  String? foodId; // Può essere Barcode, UUID cloud, ecc.
  String? foodName;
  
  // Salviamo i macro per 100g nel momento in cui il pasto viene consumato
  // Così se l'alimento cambia online in futuro, lo storico non sballa.
  double caloriesPer100g = 0;
  double proteinsPer100g = 0;
  double carbsPer100g = 0;
  double fatsPer100g = 0;
  double fibersPer100g = 0; // Aggiunto per tracciamento custom

  double amountGrams = 0;
  
  bool isOnline = false;
}
