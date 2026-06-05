import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';

import 'data/local/entities/daily_log_entity.dart';
import 'data/local/entities/user_profile_entity.dart';
import 'providers/app_state.dart';
import 'ui/screens/main_screen.dart';
import 'ui/screens/alimenti_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? path;
  if (!kIsWeb) {
    final dir = await getApplicationDocumentsDirectory();
    path = dir.path;
  }

  // Inizializza Isar Database
  final isar = await Isar.open(
    [UserProfileEntitySchema, DailyLogEntitySchema],
    directory: path ?? '',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState(isar)),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const NutrIAApp(),
    ),
  );
}

class NutrIAApp extends StatelessWidget {
  const NutrIAApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NutrIA',
      debugShowCheckedModeBanner: false,

      // ── DARK THEME (base) ─────────────────────────────────────────────────
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0F0F13),
        primaryColor: const Color(0xFF00FFC2),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FFC2),
          secondary: Color(0xFFFF007F),
          surface: Color(0xFF16161D),
          surfaceContainerHighest: Color(0xFF1C1C24),
          onSurface: Colors.white,
          onSurfaceVariant: Color(0xFFB0B0C8),
        ),
        cardColor: const Color(0xFF16161D),
        dividerColor: Colors.white12,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
          bodySmall: TextStyle(color: Color(0xFFB0B0C8)),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? const Color(0xFF00FFC2)
                  : Colors.white54),
          trackColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? const Color(0xFF00FFC2).withOpacity(0.3)
                  : Colors.white12),
        ),
      ),

      // ── LIGHT THEME ───────────────────────────────────────────────────────
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF2F4F8),
        primaryColor: const Color(0xFF00BFA0),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF00BFA0),
          secondary: Color(0xFFFF007F),
          surface: Color(0xFFFFFFFF),
          surfaceContainerHighest: Color(0xFFEFF1F7),
          onSurface: Color(0xFF1A1A2E),
          onSurfaceVariant: Color(0xFF5A5A7A),
        ),
        cardColor: const Color(0xFFFFFFFF),
        dividerColor: const Color(0xFF1A1A2E).withOpacity(0.08),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF1A1A2E)),
          titleTextStyle: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFF1A1A2E)),
          bodySmall: TextStyle(color: Color(0xFF5A5A7A)),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? const Color(0xFF00BFA0)
                  : Colors.white),
          trackColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? const Color(0xFF00BFA0).withOpacity(0.4)
                  : const Color(0xFF1A1A2E).withOpacity(0.15)),
        ),
      ),

      themeMode: context.watch<ThemeProvider>().themeMode,
      initialRoute: '/',
      routes: {
        '/': (context) => const MainScreen(),
        '/addMeal': (context) {
          final mealTarget = ModalRoute.of(context)?.settings.arguments as String?;
          return AlimentiScreen(initialMealTarget: mealTarget);
        },
      },
    );
  }
}
