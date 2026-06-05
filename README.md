# NutrIA 🍎📱

<p align="center">
  <img src="assets/logo.png" alt="NutrIA Logo" width="180"/>
</p>

**NutrIA** is an advanced Flutter application for tracking nutrients and calories, designed to offer a premium, responsive user experience supported by artificial intelligence (Google Gemini). The app merges the precision of manual tracking with the speed of AI, allowing users to log entire meals or days with a single sentence or photo.

---

## 🌟 Key Features

### 1. 🪄 AI Meal Logger (Text, Image, and Voice)
* **Whole Meal Estimation:** Enter a text description (e.g., *"Tuna pasta about 100g, 10g of olive oil, and 20g of parmesan"*) or snap/upload a photo of the meal. Gemini AI will estimate the weight of the ingredients and their nutritional values.
* **"Whole Day" Mode:** Describe your entire day's meals in a single sentence (e.g., *"For breakfast an apple and rusks, for lunch 80g of rice"*). The AI extracts the ingredients and automatically distributes them to their respective meals of the day (Breakfast, Lunch, Dinner, Snacks).
* **Voice Dictation:** Integrated microphone support to log meals using speech-to-text.
* **Quick Clear Button (C):** Clean up the entered text box and the currently estimated food items instantly.

### 2. 🔍 Advanced Food Scanner
* **Nutrition Table Scanner:** Take a photo or select an image from your gallery of the nutrition facts table on the back of any packaging. The AI automatically extracts calories and macronutrients per 100g, pre-filling the new food form.
* **Barcode Reader:** Scan a product's barcode (or upload a photo from your gallery) to instantly query the online database of **Open Food Facts**.

### 3. 📊 Dashboard & Nutrition Diary
* **Macro Monitoring:** Track your target calories, proteins, carbohydrates, fats, and fibers in real-time, displaying remaining macros.
* **Water Tracker:** Log your daily water intake with quick buttons (with quick chips for 5g, 10g, and 25g in quantity dialogs).
* **80/20 Rule:** Enable the 80/20 mode to exclude untracked days (cheat days) from the calculation of weekly averages.
* **Historical Mini-Calendar:** Navigate quickly to previous days to view or edit your diary.

### 4. 🍎 Food Library
* **Saved Foods (Personal Library):** Edit any saved food item (name, brand, macros) via a handy edit pencil icon.
* **Web Search:** Search for any food item in the Open Food Facts database in a robust and optimized way.
* **New Food:** Manually create new food items with name, brand, macros, calories, and fibers, with a streamlined UI.
* **Food History:** Displays recently used foods. The history limit defaults to 100 items but can be customized in settings.

### 5. ⚙️ Settings & Customizable Startup Screen
* Configure the application to start directly on:
  * **Dashboard (Home)**
  * **Food Library** (selecting the default tab: *Saved*, *Web*, *New*, or *History*)
  * **AI Meal Logger** (starting the dialog pre-set to *"Whole day"*)
* Full support for system **QuickActions** (long-press on the app icon) and home screen **Widgets**.

---

## 🛠️ Tech Stack

* **Framework:** [Flutter](https://flutter.dev) (Dart)
* **Local Database:** [Isar Database](https://isar.dev) (high-performance NoSQL database for Flutter)
* **Artificial Intelligence:** [Google Generative AI SDK](https://pub.dev/packages/google_generative_ai) (Gemini 2.0 Flash Lite / custom models)
* **Food Database Integration:** [Open Food Facts API](https://world.openfoodfacts.org)
* **State Management:** [Provider](https://pub.dev/packages/provider)
* **Native Integration:** `QuickActions` for icon shortcuts and `MethodChannel` for system widget updates.

---

## 🚀 Installation & Setup

### Prerequisites
* Flutter SDK (minimum Dart SDK version 3.11.4)
* Android Studio / Xcode

### Local Configuration
1. Clone the repository:
   ```bash
   git clone https://github.com/RobFalc99/NutrIA.git
   cd NutrIA
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Generate Isar schema and support files:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
4. Run the application on a connected device or emulator:
   ```bash
   flutter run
   ```

### AI Configuration
To enable meal estimation and visual scanners:
1. Obtain a free Gemini API key from [Google AI Studio](https://aistudio.google.com/).
2. Open the **Profile** tab in the app.
3. Paste your key into the **Gemini API Key** field and save the configuration.

---

## 📦 Automatic Release Pipeline
The project includes the `./build_and_upload.sh` script which automates:
1. Running the unit test suite.
2. Compilating the release APK (`app-release.apk`).
3. Committing, pushing, and tagging the release on GitHub.
4. Uploading the compiled APK to GitHub Releases.
5. Sending a Telegram notification with the download link and QR code.

---

## 🔒 Security & Privacy
* **Local Data:** All your diaries, personal food items, and goals are saved locally on your device via Isar Database.
* **Gemini API Key:** The API key is stored securely on your device and sent directly to Google Generative AI APIs, without passing through intermediate servers.
* **Clean Git Repository:** Sensitive credentials and publish tokens are protected via un-tracked local configuration files (like `.env`) and excluded in `.gitignore`.
