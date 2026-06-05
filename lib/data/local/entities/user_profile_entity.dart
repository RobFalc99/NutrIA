import 'package:isar/isar.dart';

part 'user_profile_entity.g.dart';

@collection
class UserProfileEntity {
  Id id = Isar.autoIncrement; // Solo 1 profilo

  String name = '';
  int age = 0;
  double heightCm = 0;
  double bodyFatPercentage = 0;

  // Obiettivi
  double goalCalories = 2000;
  double goalProteins = 150;
  double goalCarbs = 200;
  double goalFats = 60;
  double goalFibers = 30; // Aggiunto per modalità Custom

  // Impostazioni
  String trackingMode = 'standard'; // 'light', 'standard', 'custom'
  bool use8020Mode = true; // Modalità 80/20 abilitata
  String? geminiApiKey; // La chiave API fornita dall'utente
  String? geminiModel; // Modello Gemini selezionato dall'utente
  int historyLimit = 100; // Limite elementi in cronologia
}

