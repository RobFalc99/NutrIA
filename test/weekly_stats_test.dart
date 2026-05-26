import 'package:flutter_test/flutter_test.dart';
import 'package:kcal_v1/domain/models.dart';

void main() {
  group('WeeklyStats 80/20 Rule Tests', () {
    test('calculate average calories and proteins ignoring untracked cheat days', () {
      final now = DateTime.now();
      
      // Prepariamo 7 giorni: 5 giorni tracciati normali, 2 giorni liberi (non tracciati)
      final days = [
        // Lunedì - Tracciato (2000 kcal, 150g proteine)
        DailyLog(
          date: now.subtract(const Duration(days: 6)),
          waterGlasses: 4,
          isTracked: true,
          meals: [
            Meal(
              id: 'm1',
              name: 'Colazione',
              items: [
                MealItem(
                  food: Food(id: 'f1', name: 'Uova', caloriesPer100g: 155, proteinsPer100g: 13, carbsPer100g: 1.1, fatsPer100g: 11),
                  amountGrams: 200, // 310 kcal, 26g PRO
                ),
                MealItem(
                  food: Food(id: 'f2', name: 'Pane', caloriesPer100g: 265, proteinsPer100g: 9, carbsPer100g: 49, fatsPer100g: 2),
                  amountGrams: 637.73, // Per arrivare a 1690 kcal, ~2000 totali
                ),
              ],
            )
          ],
        ),
        // Martedì - Tracciato (2200 kcal, 160g proteine)
        DailyLog(
          date: now.subtract(const Duration(days: 5)),
          isTracked: true,
          meals: [
            Meal(
              id: 'm2',
              name: 'Pranzo',
              items: [
                MealItem(
                  food: Food(id: 'f3', name: 'Pollo', caloriesPer100g: 165, proteinsPer100g: 31, carbsPer100g: 0, fatsPer100g: 3.6),
                  amountGrams: 516, // 160g proteine
                ),
              ],
            )
          ],
        ),
        // Mercoledì - Cheat Day NON TRACCIATO (5000 kcal, 80g proteine)
        DailyLog(
          date: now.subtract(const Duration(days: 4)),
          isTracked: false,
          meals: [
            Meal(
              id: 'm3',
              name: 'Abbuffata',
              items: [
                MealItem(
                  food: Food(id: 'f4', name: 'Pizza e Birra', caloriesPer100g: 250, proteinsPer100g: 4, carbsPer100g: 30, fatsPer100g: 12),
                  amountGrams: 2000, // 5000 kcal, 80g PRO
                ),
              ],
            )
          ],
        ),
        // Giovedì - Tracciato (1800 kcal, 140g proteine)
        DailyLog(
          date: now.subtract(const Duration(days: 3)),
          isTracked: true,
          meals: [
            Meal(
              id: 'm4',
              name: 'Pranzo',
              items: [
                MealItem(
                  food: Food(id: 'f5', name: 'Proteine in polvere', caloriesPer100g: 360, proteinsPer100g: 80, carbsPer100g: 5, fatsPer100g: 2),
                  amountGrams: 175, // 140g proteine, 630 kcal
                ),
              ],
            )
          ],
        ),
        // Venerdì - Tracciato (2000 kcal, 150g proteine)
        DailyLog(
          date: now.subtract(const Duration(days: 2)),
          isTracked: true,
          meals: [],
        ),
        // Sabato - Cheat Day NON TRACCIATO (6000 kcal, 100g proteine)
        DailyLog(
          date: now.subtract(const Duration(days: 1)),
          isTracked: false,
          meals: [],
        ),
        // Domenica - Tracciato (2000 kcal, 150g proteine)
        DailyLog(
          date: now,
          isTracked: true,
          meals: [],
        ),
      ];

      final stats = WeeklyStats(
        startDate: now.subtract(const Duration(days: 6)),
        endDate: now,
        days: days,
      );

      // Verifiche:
      // I giorni tracciati devono essere esattamente 5 su 7
      expect(stats.trackedDays.length, 5);
      
      // La percentuale di tracciamento deve essere 5/7 * 100 ~ 71.4%
      expect(stats.trackingPercentage, closeTo(71.42, 0.1));

      // I giorni non tracciati (Mercoledì con 5000 kcal e Sabato con 6000 kcal)
      // devono essere del tutto ignorati nel calcolo delle medie.
      // Somma calorie giorni tracciati:
      // Lunedì: ~2000 kcal
      // Martedì: ~851.4 kcal (5.16 * 165)
      // Giovedì: ~630 kcal (1.75 * 360)
      // Venerdì: 0 kcal
      // Domenica: 0 kcal
      // Totale = 2000 + 851.4 + 630 = 3481.4 kcal
      // Media = 3481.4 / 5 = 696.28 kcal
      expect(stats.averageCalories, closeTo(696.28, 0.1));

      // Somma proteine giorni tracciati:
      // Lunedì: 200 * 0.13 + 637.73 * 0.09 = 26 + 57.39 = 83.39g
      // Martedì: 516 * 0.31 = 159.96g
      // Giovedì: 175 * 0.8 = 140g
      // Venerdì: 0g
      // Domenica: 0g
      // Totale = 83.39 + 159.96 + 140 = 383.35g
      // Media = 383.35 / 5 = 76.67g
      expect(stats.averageProteins, closeTo(76.67, 0.1));
    });
  });
}
