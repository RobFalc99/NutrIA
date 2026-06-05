import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';

extension LocalizationExtension on BuildContext {
  String tr(String key) {
    final lang = watch<AppState>().currentUser?.languageCode ?? 'en';
    return AppTranslations.translate(key, lang);
  }

  String trWithParams(String key, Map<String, String> params) {
    final lang = watch<AppState>().currentUser?.languageCode ?? 'en';
    String text = AppTranslations.translate(key, lang);
    params.forEach((k, v) {
      text = text.replaceAll('{$k}', v);
    });
    return text;
  }
}

class AppTranslations {
  static final Map<String, Map<String, String>> _localizedValues = {
    // Nav bar & Screens
    'Home': {'en': 'Home', 'it': 'Home'},
    'Alimenti': {'en': 'Foods', 'it': 'Alimenti'},
    'Pasto IA': {'en': 'AI Meal', 'it': 'Pasto IA'},
    'Profilo': {'en': 'Profile', 'it': 'Profilo'},
    'Guida': {'en': 'Guide', 'it': 'Guida'},
    'Manuale': {'en': 'Manual', 'it': 'Manuale'},
    'IA Pasto': {'en': 'AI Meal', 'it': 'IA Pasto'},

    // Date/Time
    'Oggi': {'en': 'Today', 'it': 'Oggi'},
    'Ieri': {'en': 'Yesterday', 'it': 'Ieri'},
    'Domani': {'en': 'Tomorrow', 'it': 'Domani'},
    'Lunedì': {'en': 'Monday', 'it': 'Lunedì'},
    'Martedì': {'en': 'Tuesday', 'it': 'Martedì'},
    'Mercoledì': {'en': 'Wednesday', 'it': 'Mercoledì'},
    'Giovedì': {'en': 'Thursday', 'it': 'Giovedì'},
    'Venerdì': {'en': 'Friday', 'it': 'Venerdì'},
    'Sabato': {'en': 'Saturday', 'it': 'Sabato'},
    'Domenica': {'en': 'Sunday', 'it': 'Domenica'},
    'Gennaio': {'en': 'January', 'it': 'Gennaio'},
    'Febbraio': {'en': 'February', 'it': 'Febbraio'},
    'Marzo': {'en': 'March', 'it': 'Marzo'},
    'Aprile': {'en': 'April', 'it': 'Aprile'},
    'Maggio': {'en': 'May', 'it': 'Maggio'},
    'Giugno': {'en': 'June', 'it': 'Giugno'},
    'Luglio': {'en': 'July', 'it': 'Luglio'},
    'Agosto': {'en': 'August', 'it': 'Agosto'},
    'Settembre': {'en': 'September', 'it': 'Settembre'},
    'Ottobre': {'en': 'October', 'it': 'Ottobre'},
    'Novembre': {'en': 'November', 'it': 'Novembre'},
    'Dicembre': {'en': 'December', 'it': 'Dicembre'},

    // Meals
    'Colazione': {'en': 'Breakfast', 'it': 'Colazione'},
    'Pranzo': {'en': 'Lunch', 'it': 'Pranzo'},
    'Cena': {'en': 'Dinner', 'it': 'Cena'},
    'Spuntini': {'en': 'Snacks', 'it': 'Spuntini'},
    'Tutta la giornata': {'en': 'Whole day', 'it': 'Tutta la giornata'},

    // Macros
    'Calorie': {'en': 'Calories', 'it': 'Calorie'},
    'Proteine': {'en': 'Proteins', 'it': 'Proteine'},
    'Carboidrati': {'en': 'Carbohydrates', 'it': 'Carboidrati'},
    'Carbs': {'en': 'Carbs', 'it': 'Carbs'},
    'Grassi': {'en': 'Fats', 'it': 'Grassi'},
    'Fibre': {'en': 'Fibers', 'it': 'Fibre'},
    'Acqua': {'en': 'Water', 'it': 'Acqua'},
    'Idratazione': {'en': 'Hydration', 'it': 'Idratazione'},

    // Profile & Settings Screen
    'Profilo & Impostazioni': {'en': 'Profile & Settings', 'it': 'Profilo & Impostazioni'},
    'SALVA': {'en': 'SAVE', 'it': 'SALVA'},
    'Profilo salvato!': {'en': 'Profile saved!', 'it': 'Profilo salvato!'},
    'giorno di streak!': {'en': 'day streak!', 'it': 'giorno di streak!'},
    'giorni di streak!': {'en': 'day streak!', 'it': 'giorni di streak!'},
    'Inizia il tuo streak oggi!': {'en': 'Start your streak today!', 'it': 'Inizia il tuo streak oggi!'},
    'Stai tracciando i tuoi pasti ogni giorno 💪': {'en': 'You are tracking your meals every day 💪', 'it': 'Stai tracciando i tuoi pasti ogni giorno 💪'},
    'Registra almeno un pasto per iniziare': {'en': 'Log at least one meal to start', 'it': 'Registra almeno un pasto per iniziare'},
    'Analisi Settimanale 80/20': {'en': 'Weekly 80/20 Analysis', 'it': 'Analisi Settimanale 80/20'},
    'Giorni Tracciati': {'en': 'Days Tracked', 'it': 'Giorni Tracciati'},
    'Media ultimi 7 giorni (escluso oggi). Le medie escludono i Cheat Days.': {
      'en': 'Average last 7 days (excluding today). Averages exclude Cheat Days.',
      'it': 'Media ultimi 7 giorni (escluso oggi). Le medie escludono i Cheat Days.'
    },
    'Dati insufficienti — registra almeno 7 giorni per vedere le medie.': {
      'en': 'Insufficient data — log at least 7 days to see averages.',
      'it': 'Dati insufficienti — registra almeno 7 giorni per vedere le medie.'
    },
    'Calorie Medie': {'en': 'Average Calories', 'it': 'Calorie Medie'},
    'Proteine Medie': {'en': 'Average Proteins', 'it': 'Proteine Medie'},
    'Modalita\' di Tracciamento': {'en': 'Tracking Mode', 'it': 'Modalita\' di Tracciamento'},
    'Dati Utente': {'en': 'User Data', 'it': 'Dati Utente'},
    'Nome': {'en': 'Name', 'it': 'Nome'},
    'Calorie obiettivo (kcal)': {'en': 'Target Calories (kcal)', 'it': 'Calorie obiettivo (kcal)'},
    'Proteine (g)': {'en': 'Proteins (g)', 'it': 'Proteine (g)'},
    'Carboidrati (g)': {'en': 'Carbohydrates (g)', 'it': 'Carboidrati (g)'},
    'Grassi (g)': {'en': 'Fats (g)', 'it': 'Grassi (g)'},
    'Fibre (g)': {'en': 'Fibers (g)', 'it': 'Fibre (g)'},
    'Regola 80/20': {'en': '80/20 Rule', 'it': 'Regola 80/20'},
    'Abilita modalita\' 80/20': {'en': 'Enable 80/20 mode', 'it': 'Abilita modalita\' 80/20'},
    'I giorni non tracciati vengono escluse dalle medie settimanali.': {
      'en': 'Untracked days are excluded from weekly averages.',
      'it': 'I giorni non tracciati vengono escluse dalle medie settimanali.'
    },
    'Chiave API Gemini (AI)': {'en': 'Gemini API Key (AI)', 'it': 'Chiave API Gemini (AI)'},
    'Salvata solo sul dispositivo. Usata per le funzioni AI.': {
      'en': 'Saved only on the device. Used for AI features.',
      'it': 'Salvata solo sul dispositivo. Usata per le funzioni AI.'
    },
    'Modello IA Selezionato': {'en': 'Selected AI Model', 'it': 'Modello IA Selezionato'},
    'Seleziona Modello IA': {'en': 'Select AI Model', 'it': 'Seleziona Modello IA'},
    'Limite Cronologia Alimenti': {'en': 'Food History Limit', 'it': 'Limite Cronologia Alimenti'},
    'Limite Cronologia': {'en': 'History Limit', 'it': 'Limite Cronologia'},
    'elementi': {'en': 'items', 'it': 'elementi'},
    'elementi (Predefinito)': {'en': 'items (Default)', 'it': 'elementi (Predefinito)'},
    'Schermata di Avvio': {'en': 'Startup Screen', 'it': 'Schermata di Avvio'},
    'Schermata iniziale': {'en': 'Initial screen', 'it': 'Schermata iniziale'},
    'Scheda Alimenti Predefinita': {'en': 'Default Food Tab', 'it': 'Scheda Alimenti Predefinita'},
    'Scheda iniziale alimenti': {'en': 'Initial food tab', 'it': 'Scheda iniziale alimenti'},
    'Salvati': {'en': 'Saved', 'it': 'Salvati'},
    'Web (Ricerca)': {'en': 'Web (Search)', 'it': 'Web (Ricerca)'},
    'Nuovo (Inserimento)': {'en': 'New (Input)', 'it': 'Nuovo (Inserimento)'},
    'Cronologia': {'en': 'History', 'it': 'Cronologia'},
    'Salva Configurazione': {'en': 'Save Settings', 'it': 'Salva Configurazione'},
    'Inserisci un numero valido': {'en': 'Please enter a valid number', 'it': 'Inserisci un numero valido'},
    'Scelte Avvio': {'en': 'Startup Choices', 'it': 'Scelte Avvio'},
    'Configura lingua': {'en': 'Language', 'it': 'Configura lingua'},
    'Inglese': {'en': 'English', 'it': 'Inglese'},
    'Italiano': {'en': 'Italian', 'it': 'Italiano'},

    // Feedback
    'Feedback & Supporto': {'en': 'Feedback & Support', 'it': 'Feedback & Supporto'},
    'Hai suggerimenti o hai riscontrato un problema? Contattami a:': {
      'en': 'Do you have suggestions or encountered a bug? Contact me at:',
      'it': 'Hai suggerimenti o hai riscontrato un problema? Contattami a:'
    },

    // Dialogs / Popups / General UI
    'Modifica quantità': {'en': 'Edit quantity', 'it': 'Modifica quantità'},
    'Quantità (g)': {'en': 'Amount (g)', 'it': 'Quantità (g)'},
    'Valori calcolati:': {'en': 'Calculated values:', 'it': 'Valori calcolati:'},
    'Elimina alimento': {'en': 'Delete food', 'it': 'Elimina alimento'},
    'Sei sicuro di voler eliminare questo alimento?': {'en': 'Are you sure you want to delete this food?', 'it': 'Sei sicuro di voler eliminare questo alimento?'},
    'Elimina': {'en': 'Delete', 'it': 'Elimina'},
    'Rimanenti': {'en': 'Remaining', 'it': 'Rimanenti'},
    'Assunte': {'en': 'Consumed', 'it': 'Assunte'},
    'Obiettivo': {'en': 'Goal', 'it': 'Obiettivo'},
    'Registro Idratazione': {'en': 'Hydration Log', 'it': 'Registro Idratazione'},
    'Bicchieri stimati': {'en': 'Estimated glasses', 'it': 'Bicchieri stimati'},
    'Aggiungi 250ml': {'en': 'Add 250ml', 'it': 'Aggiungi 250ml'},
    'Rimuovi 250ml': {'en': 'Remove 250ml', 'it': 'Rimuovi 250ml'},
    'Aggiungi Acqua': {'en': 'Add Water', 'it': 'Aggiungi Acqua'},
    'Inserisci quantità d\'acqua in ml': {'en': 'Enter water amount in ml', 'it': 'Inserisci quantità d\'acqua in ml'},
    'Aggiungi': {'en': 'Add', 'it': 'Aggiungi'},
    'Aggiungi alimento a': {'en': 'Add food to', 'it': 'Aggiungi alimento a'},
    'Stima con IA': {'en': 'Estimate with AI', 'it': 'Stima con IA'},
    'Cerca nei miei alimenti': {'en': 'Search my foods', 'it': 'Cerca nei miei alimenti'},
    'Scansiona codice a barre': {'en': 'Scan barcode', 'it': 'Scansiona codice a barre'},
    'Carica codice da galleria': {'en': 'Load barcode from gallery', 'it': 'Carica codice da galleria'},
    'Scansiona tabella nutrizionale': {'en': 'Scan nutrition table', 'it': 'Scansiona tabella nutrizionale'},
    'Carica tabella da galleria': {'en': 'Load table from gallery', 'it': 'Carica tabella da galleria'},
    'Inserisci manualmente': {'en': 'Insert manually', 'it': 'Inserisci manualmente'},
    'Modifica': {'en': 'Edit', 'it': 'Modifica'},
    'Salva modifiche': {'en': 'Save changes', 'it': 'Salva modifiche'},
    'Alimento modificato!': {'en': 'Food updated!', 'it': 'Alimento modificato!'},
    'Nessun alimento trovato': {'en': 'No food items found', 'it': 'Nessun alimento trovato'},
    'Cerca sul Web (OFF)': {'en': 'Search Web (OFF)', 'it': 'Cerca sul Web (OFF)'},
    'Ricerca Alimento': {'en': 'Search Food', 'it': 'Ricerca Alimento'},
    'Cerca': {'en': 'Search', 'it': 'Cerca'},
    'Risultati di ricerca': {'en': 'Search results', 'it': 'Risultati di ricerca'},
    'Salva nei miei alimenti': {'en': 'Save to my foods', 'it': 'Salva nei miei alimenti'},
    'Alimento salvato con successo!': {'en': 'Food saved successfully!', 'it': 'Alimento salvato con successo!'},
    'Valori Nutrizionali': {'en': 'Nutrition Values', 'it': 'Valori Nutrizionali'},
    'Marca': {'en': 'Brand', 'it': 'Marca'},
    'Nome Alimento': {'en': 'Food Name', 'it': 'Nome Alimento'},
    'Salva Alimento': {'en': 'Save Food', 'it': 'Salva Alimento'},
    'Inserisci il nome': {'en': 'Enter the name', 'it': 'Inserisci il nome'},
    'Inserisci un valore valido per': {'en': 'Enter a valid value for', 'it': 'Inserisci un valore valido per'},
    'La cronologia è vuota': {'en': 'History is empty', 'it': 'La cronologia è vuota'},
    'I Miei Alimenti': {'en': 'My Foods', 'it': 'I Miei Alimenti'},
    'Pasto IA Gemini': {'en': 'Gemini AI Meal', 'it': 'Pasto IA Gemini'},
    'Inserisci pasto in': {'en': 'Log meal in', 'it': 'Inserisci pasto in'},
    'Descrivi cosa hai mangiato...': {'en': 'Describe what you ate...', 'it': 'Descrivi cosa hai mangiato...'},
    'Dettatura vocale attiva... Parla ora': {'en': 'Voice dictation active... Speak now', 'it': 'Dettatura vocale attiva... Parla ora'},
    'Errore dettatura vocale': {'en': 'Voice dictation error', 'it': 'Errore dettatura vocale'},
    'Dettatura non disponibile': {'en': 'Dictation unavailable', 'it': 'Dettatura non disponibile'},
    'Dettatura non supportata su questo dispositivo': {'en': 'Dictation not supported on this device', 'it': 'Dettatura non supportata su questo dispositivo'},
    'Cancella tutto': {'en': 'Clear all', 'it': 'Cancella tutto'},
    'Invia descrizione pasto': {'en': 'Send meal description', 'it': 'Invia descrizione pasto'},
    'Stima Valori con IA': {'en': 'Estimate Values with AI', 'it': 'Stima Valori con IA'},
    'Configura la tua API Key Gemini nelle impostazioni per usare questa funzione.': {
      'en': 'Configure your Gemini API Key in settings to use this feature.',
      'it': 'Configura la tua API Key Gemini nelle impostazioni per usare questa funzione.'
    },
    'Analizzando il pasto con l\'IA...': {'en': 'Analyzing meal with AI...', 'it': 'Analizzando il pasto con l\'IA...'},
    'Stima IA Pasto Completo': {'en': 'AI Whole Meal Estimate', 'it': 'Stima IA Pasto Completo'},
    'Ingredienti Rilevati:': {'en': 'Detected Ingredients:', 'it': 'Ingredienti Rilevati:'},
    'Quantita\' Totale Stimata': {'en': 'Total Estimated Amount', 'it': 'Quantita\' Totale Stimata'},
    'Aggiungi pasto al diario': {'en': 'Add meal to diary', 'it': 'Aggiungi pasto al diario'},
    'Stima fallita. Riprova.': {'en': 'Estimation failed. Try again.', 'it': 'Stima fallita. Riprova.'},
    'Pasto aggiunto al diario!': {'en': 'Meal added to diary!', 'it': 'Pasto aggiunto al diario!'},
    'Chiudi': {'en': 'Close', 'it': 'Chiudi'},
    'Modifiche non salvate ⚠️': {'en': 'Unsaved changes ⚠️', 'it': 'Modifiche non salvate ⚠️'},
    'Ci sono modifiche non salvate nel tuo profilo. Vuoi salvare prima di uscire, uscire senza salvare o annullare?': {
      'en': 'There are unsaved changes in your profile. Do you want to save before leaving, leave without saving, or cancel?',
      'it': 'Ci sono modifiche non salvate nel tuo profilo. Vuoi salvare prima di uscire, uscire senza salvare o annullare?'
    },
    'Esci senza salvare': {'en': 'Leave without saving', 'it': 'Esci senza salvare'},
    'Salva ed esci': {'en': 'Save and leave', 'it': 'Salva ed esci'},
    'Acqua registrata con successo! 💧 +250ml': {'en': 'Water logged successfully! 💧 +250ml', 'it': 'Acqua registrata con successo! 💧 +250ml'},
    'Acqua registrata con successo! 💧 +500ml': {'en': 'Water logged successfully! 💧 +500ml', 'it': 'Acqua registrata con successo! 💧 +500ml'},
    'Guida Funzionalità NutrIA 💡': {'en': 'NutrIA Features Guide 💡', 'it': 'Guida Funzionalità NutrIA 💡'},
    '1. Inserimento Pasti con IA 🪄': {'en': '1. AI Meal Input 🪄', 'it': '1. Inserimento Pasti con IA 🪄'},
    'Fotografa il tuo piatto o descrivilo testualmente (es. "pasta corta con salsa, un uovo sodo"). L\'IA Gemini scompone gli alimenti stimando quantità e macro riferiti a 100g.': {
      'en': 'Take a photo of your dish or describe it in text (e.g., "pasta with sauce, one boiled egg"). Gemini AI breaks down the food, estimating quantities and macros per 100g.',
      'it': 'Fotografa il tuo piatto o descrivilo testualmente (es. "pasta corta con salsa, un uovo sodo"). L\'IA Gemini scompone gli alimenti stimando quantità e macro riferiti a 100g.'
    },
    '2. Scannerizzazione Barcode Avanzata 📷': {'en': '2. Advanced Barcode Scanner 📷', 'it': '2. Scannerizzazione Barcode Avanzata 📷'},
    'Inquadra il codice a barre per scansionarlo. Se il rilevamento automatico fallisce, scatta una foto al codice: Gemini Vision ne estrarrà i numeri per interrogare OpenFoodFacts.': {
      'en': 'Point at the barcode to scan it. If auto-detection fails, take a photo of the code: Gemini Vision will extract the numbers to query OpenFoodFacts.',
      'it': 'Inquadra il codice a barre per scansionarlo. Se il rilevamento automatico fallisce, scatta una foto al codice: Gemini Vision ne estrarrà i numeri per interrogare OpenFoodFacts.'
    },
    '3. Scannerizzazione Tabella Nutrizionale 🔍': {'en': '3. Nutrition Table Scanner 🔍', 'it': '3. Scannerizzazione Tabella Nutrizionale 🔍'},
    'Fai una foto alla tabella dei valori nutrizionali sul retro di qualsiasi confezione. L\'IA estrarrà automaticamente tutti i macronutrienti per 100g precompilando la scheda!': {
      'en': 'Take a photo of the nutrition table on the back of any packaging. The AI will automatically extract all macronutrients per 100g to prefill the form!',
      'it': 'Fai una foto alla tabella dei valori nutrizionali sul retro di qualsiasi confezione. L\'IA estrarrà automaticamente tutti i macronutrienti per 100g precompilando la scheda!'
    },
    '4. Sezione Alimenti & Storico 📊': {'en': '4. Food Section & History 📊', 'it': '4. Sezione Alimenti & Storico 📊'},
    'Gli alimenti aggiunti sono memorizzati nella scheda "I Miei Alimenti" per un inserimento rapido. Configura la tua API Key Gemini dal tuo Profilo per abilitare le elaborazioni visive.': {
      'en': 'Added foods are stored in the "My Foods" tab for quick entry. Configure your Gemini API Key in your Profile to enable visual processing.',
      'it': 'Gli alimenti aggiunti sono memorizzati nella scheda "I Miei Alimenti" per un inserimento rapido. Configura la tua API Key Gemini dal tuo Profilo per abilitare le elaborazioni visive.'
    },
    'Ho capito': {'en': 'Got it', 'it': 'Ho capito'},
    'Ciao! Pronto a registrare i tuoi pasti di oggi? Usa la stima con IA o scansiona un codice!': {
      'en': 'Hello! Ready to track today\'s meals? Use AI estimation or scan a code!',
      'it': 'Ciao! Pronto a registrare i tuoi pasti di oggi? Usa la stima con IA o scansiona un codice!'
    },
  };

  static String translate(String key, String lang) {
    final translations = _localizedValues[key];
    if (translations == null) return key;
    return translations[lang] ?? translations['en'] ?? key;
  }
}
