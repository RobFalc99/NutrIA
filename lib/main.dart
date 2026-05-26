import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'data/local/entities/daily_log_entity.dart';
import 'data/local/entities/user_profile_entity.dart';
import 'providers/app_state.dart';
import 'ui/screens/main_screen.dart';
import 'ui/screens/add_meal_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inizializza Isar Database
  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(
    [UserProfileEntitySchema, DailyLogEntitySchema],
    directory: dir.path,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState(isar)),
      ],
      child: const KCALcolatoreApp(),
    ),
  );
}

class KCALcolatoreApp extends StatelessWidget {
  const KCALcolatoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KCALcolatore',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F13),
        primaryColor: const Color(0xFF00FFC2),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FFC2),
          secondary: Color(0xFFFF007F),
        ),
        useMaterial3: true,
      ),
      // MainScreen è la root: contiene Dashboard + Profilo via BottomNavigationBar
      // Non serve più la route '/profile' perché la navigazione è interna all'IndexedStack
      initialRoute: '/',
      routes: {
        '/': (context) => const MainScreen(),
        '/addMeal': (context) => const AddMealScreen(),
      },
    );
  }
}
