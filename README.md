# NutrIA 🍎📱

<p align="center">
  <img src="assets/logo.png" alt="NutrIA Logo" width="180"/>
</p>

**NutrIA** è un'applicazione Flutter avanzata per il tracciamento dei nutrienti e delle calorie, progettata per offrire un'esperienza utente premium, reattiva e supportata dall'intelligenza artificiale (Google Gemini). L'app unisce la precisione del tracciamento manuale alla velocità dell'IA, consentendo di registrare interi pasti o giornate con una sola frase o foto.

---

## 🌟 Funzionalità Principali

### 1. 🪄 Aggiunta Pasto con IA (Testo, Immagine e Voce)
* **Stima Pasto Completo:** Inserisci una descrizione testuale (es. *"Pasta al tonno circa 100g, 10g d'olio e 20g di parmigiano"*) o scatta/carica una foto del pasto. L'IA di Gemini stimerà la grammatura degli ingredienti e i relativi valori nutrizionali.
* **Modalità "Tutta la giornata":** Permette di descrivere l'intera giornata alimentare in un'unica frase (es. *"A colazione una mela e fette biscottate, a pranzo 80g di riso"*). L'IA estrae gli ingredienti e li distribuisce automaticamente nei rispettivi pasti della giornata (Colazione, Pranzo, Cena, Spuntini).
* **Dettatura Vocale:** Integra il microfono per inserire i pasti tramite sintesi vocale.
* **Tasto Cancella Rapido (C):** Consente di ripulire istantaneamente il testo inserito e le stime correnti.

### 2. 🔍 Scanner Alimentare Avanzato
* **Scanner Tabella Nutrizionale:** Scatta una foto o seleziona un'immagine dalla galleria della tabella nutrizionale sul retro delle confezioni. L'IA estrae automaticamente calorie e macronutrienti per 100g, precompilando la scheda del nuovo alimento.
* **Lettore Codici a Barre:** Inquadra il codice a barre di un prodotto (o carica una foto dalla galleria) per interrogare istantaneamente il database online di **Open Food Facts**.

### 3. 📊 Dashboard e Diario Nutrizionale
* **Visualizzazione Macro:** Monitora in tempo reale calorie, proteine, carboidrati, grassi e fibre rimaste per raggiungere l'obiettivo giornaliero.
* **Tracciamento dell'Acqua:** Registra l'acqua assunta durante la giornata con pulsanti rapidi (con l'aggiunta di chip rapidi per 5g, 10g, 25g, 50g ecc. nei dialog quantitativi).
* **Regola 80/20:** Abilita la modalità 80/20 per escludere i giorni non tracciati (cheat days) dal calcolo delle medie settimanali.
* **Mini Calendario Storico:** Naviga rapidamente nei giorni precedenti per visualizzare o modificare il diario.

### 4. 🍎 Sezione Alimenti
* **Alimenti Salvati (Libreria Personale):** Modifica liberamente qualsiasi alimento salvato (nome, marca, macros) tramite una comoda icona a matita.
* **Ricerca Web:** Cerca qualsiasi alimento nel database Open Food Facts in modo robusto e ottimizzato.
* **Nuovo (New Food):** Manual creation of a new food item with name, brand, macros, calories, and fibers, with streamlined UI.
* **Cronologia Alimenti:** Mostra gli alimenti usati di recente. La lunghezza della cronologia è limitata di default a 100 elementi, ma può essere personalizzata nelle impostazioni.

### 5. ⚙️ Impostazioni e Schermata di Avvio Personalizzabile
* Consente di configurare l'applicazione per aprirsi all'avvio direttamente su:
  * **Dashboard (Home)**
  * **Sezione Alimenti** (selezionando anche la scheda predefinita tra *Salvati*, *Web*, *Nuovo*, *Cronologia*)
  * **Aggiungi Pasto con IA** (avviando direttamente il dialog preimpostato su *"Tutta la giornata"*)
* Supporto completo alle **QuickActions** del sistema operativo (pressione prolungata sull'icona dell'app) e ai **Widget** della schermata iniziale.

---

## 🛠️ Tecnologie Utilizzate

* **Framework:** [Flutter](https://flutter.dev) (Dart)
* **Database Locale:** [Isar Database](https://isar.dev) (database NoSQL ad altissime prestazioni per Flutter)
* **Intelligenza Artificiale:** [Google Generative AI SDK](https://pub.dev/packages/google_generative_ai) (Gemini 2.0 Flash Lite / modelli personalizzabili)
* **Integrazione Dati Alimentari:** [Open Food Facts API](https://world.openfoodfacts.org)
* **Gestione Stato:** [Provider](https://pub.dev/packages/provider)
* **Funzionalità Native:** `QuickActions` per le scorciatoie dell'icona e `MethodChannel` per l'integrazione di widget di sistema.

---

## 🚀 Guida all'Installazione e Sviluppo

### Prerequisiti
* Flutter SDK (versione minima Dart SDK 3.11.4)
* Android Studio / Xcode

### Configurazione Locale
1. Clona il repository:
   ```bash
   git clone https://github.com/RobFalc99/NutrIA.git
   cd NutrIA
   ```
2. Installa le dipendenze:
   ```bash
   flutter pub get
   ```
3. Genera i file Isar e di supporto:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
4. Avvia l'applicazione sul dispositivo o emulatore collegato:
   ```bash
   flutter run
   ```

### Configurazione delle Funzionalità IA
Per attivare la stima dei pasti e gli scanner visivi tramite intelligenza artificiale:
1. Ottieni una chiave API Gemini gratuita su [Google AI Studio](https://aistudio.google.com/).
2. Apri la scheda **Profilo** all'interno dell'app.
3. Inserisci la tua API Key nel campo **Chiave API Gemini** e salva la configurazione.

---

## 📦 Pipeline di Rilascio Automatico
Il progetto include lo script `./build_and_upload.sh` che automatizza:
1. Il superamento della suite di test unitari.
2. La compilazione del file `app-release.apk`.
3. Il commit, push e la creazione del tag su GitHub.
4. L'upload dell'APK compilato sulle GitHub Releases.
5. L'invio di una notifica Telegram con il QR code di download.

---

## 🔒 Sicurezza e Privacy
* **Dati Locali:** Tutti i tuoi diari, alimenti personali e obiettivi sono salvati localmente tramite Isar Database sul tuo dispositivo.
* **API Key Gemini:** La chiave API inserita viene memorizzata in modo sicuro esclusivamente sul tuo dispositivo e inviata direttamente alle API ufficiali di Google Generative AI, senza passare da server intermediari.
* **Ambiente Git Pulito:** Le credenziali sensibili e i token di pubblicazione sono protetti da file locali non tracciati (es. `.env`) e regolarmente ignorati in `.gitignore`.
