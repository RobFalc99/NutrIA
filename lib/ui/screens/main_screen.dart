import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'alimenti_screen.dart';

/// Schermata principale con BottomNavigationBar ed integrazione QuickActions (Android/iOS).
/// Dashboard, Alimenti e Impostazioni sono sempre montate nell'albero dei widget.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _isAddMenuOpen = false;
  
  // Istanza QuickActions per shortcut su icona app
  final QuickActions _quickActions = const QuickActions();

  @override
  void initState() {
    super.initState();
    _requestInitialPermissions();
    _setupQuickActions();
    _setupWidgetChannel();
  }

  Future<void> _requestInitialPermissions() async {
    // Richiedi permessi fotocamera e galleria (photos/storage) all'avvio
    try {
      await [
        Permission.camera,
        Permission.photos,
        Permission.storage,
      ].request();
    } catch (e) {
      debugPrint("Errore richiesta permessi iniziali: $e");
    }
  }

  void _setupQuickActions() {
    // Gestione dei tap sui collegamenti rapidi dell'icona
    _quickActions.initialize((String type) {
      if (type == 'action_manual') {
        final hour = DateTime.now().hour;
        String defaultMeal = 'Colazione';
        if (hour >= 11 && hour < 15) {
          defaultMeal = 'Pranzo';
        } else if (hour >= 15 && hour < 19) {
          defaultMeal = 'Spuntini';
        } else if (hour >= 19) {
          defaultMeal = 'Cena';
        }
        Navigator.pushNamed(context, '/addMeal', arguments: defaultMeal);
      } else if (type == 'action_alimenti') {
        setState(() {
          _currentIndex = 1; // Sposta alla tab Alimenti
          _isAddMenuOpen = false;
        });
      } else if (type == 'action_ia') {
        final hour = DateTime.now().hour;
        String defaultMeal = 'Colazione';
        if (hour >= 11 && hour < 15) {
          defaultMeal = 'Pranzo';
        } else if (hour >= 15 && hour < 19) {
          defaultMeal = 'Spuntini';
        } else if (hour >= 19) {
          defaultMeal = 'Cena';
        }
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => WholeMealAiDialog(defaultMeal: defaultMeal),
        );
      } else if (type == 'action_info') {
        _showInfoGuideDialog(context);
      }
    });

    // Definizione dei collegamenti rapidi registrati su Android/iOS
    _quickActions.setShortcutItems(const <ShortcutItem>[
      ShortcutItem(
        type: 'action_manual',
        localizedTitle: 'Manuale',
        icon: 'ic_manual', // Icona nativa di fallback
      ),
      ShortcutItem(
        type: 'action_alimenti',
        localizedTitle: 'Alimenti',
        icon: 'ic_alimenti',
      ),
      ShortcutItem(
        type: 'action_ia',
        localizedTitle: 'IA Pasto',
        icon: 'ic_ia',
      ),
      ShortcutItem(
        type: 'action_info',
        localizedTitle: 'Guida',
        icon: 'ic_info',
      ),
    ]);
  }

  void _setupWidgetChannel() {
    const channel = MethodChannel('com.example.kcal/widget');
    
    // 1. Ascolta le azioni in tempo reale se l'app è già aperta
    channel.setMethodCallHandler((call) async {
      if (call.method == 'onWidgetAction') {
        final String? action = call.arguments as String?;
        if (action != null) {
          _handleWidgetAction(action);
        }
      }
    });

    // 2. Controlla se c'è un'azione in sospeso (es. avviato a freddo)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final String? action = await channel.invokeMethod<String>('getWidgetAction');
        if (action != null) {
          _handleWidgetAction(action);
        }
      } catch (e) {
        debugPrint("Errore recupero azione widget iniziale: $e");
      }
    });
  }

  void _handleWidgetAction(String action) {
    if (!mounted) return;
    final appState = Provider.of<AppState>(context, listen: false);
    
    if (action == 'add_water') {
      appState.addWaterMl(250);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Acqua registrata con successo! 💧 +250ml'),
          backgroundColor: const Color(0xFF00FFC2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else if (action == 'add_water_500') {
      appState.addWaterMl(500);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Acqua registrata con successo! 💧 +500ml'),
          backgroundColor: const Color(0xFF00FFC2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else if (action == 'add_manual') {
      final hour = DateTime.now().hour;
      String defaultMeal = 'Colazione';
      if (hour >= 11 && hour < 15) {
        defaultMeal = 'Pranzo';
      } else if (hour >= 15 && hour < 19) {
        defaultMeal = 'Spuntini';
      } else if (hour >= 19) {
        defaultMeal = 'Cena';
      }
      Navigator.pushNamed(context, '/addMeal', arguments: defaultMeal);
    } else if (action == 'ai_pasto') {
      final hour = DateTime.now().hour;
      String defaultMeal = 'Colazione';
      if (hour >= 11 && hour < 15) {
        defaultMeal = 'Pranzo';
      } else if (hour >= 15 && hour < 19) {
        defaultMeal = 'Spuntini';
      } else if (hour >= 19) {
        defaultMeal = 'Cena';
      }
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WholeMealAiDialog(defaultMeal: defaultMeal),
      );
    }
  }

  static const _accentCyan = Color(0xFF00FFC2);
  static const _accentPink = Color(0xFFFF007F);
  static const _bgDark = Color(0xFF0F0F13);
  static const _bgCard = Color(0xFF16161D);

  // IndexedStack mantiene le tab sempre montate in memoria.
  final List<Widget> _screens = const [
    DashboardScreen(),
    AlimentiScreen(),
    ProfileScreen(),
  ];

  void _onTabTapped(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _currentIndex = index;
      _isAddMenuOpen = false; // Chiude il menu se si cambia tab
    });
  }

  void _showInfoGuideDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: _accentCyan, size: 24),
              SizedBox(width: 12),
              Text(
                'Guida Funzionalità kCali 💡',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildGuideSection(
                  title: '1. Inserimento Pasti con IA 🪄',
                  description:
                      'Fotografa il tuo piatto o descrivilo testualmente (es. "pasta corta con salsa, un uovo sodo"). L\'IA Gemini scompone gli alimenti stimando quantità e macro riferiti a 100g.',
                  color: _accentCyan,
                ),
                const SizedBox(height: 14),
                _buildGuideSection(
                  title: '2. Scannerizzazione Barcode Avanzata 📷',
                  description:
                      'Inquadra il codice a barre per scansionarlo. Se il rilevamento automatico fallisce, scatta una foto al codice: Gemini Vision ne estrarrà i numeri per interrogare OpenFoodFacts.',
                  color: _accentPink,
                ),
                const SizedBox(height: 14),
                _buildGuideSection(
                  title: '3. Scannerizzazione Tabella Nutrizionale 🔍',
                  description:
                      'Fai una foto alla tabella dei valori nutrizionali sul retro di qualsiasi confezione. L\'IA estrarrà automaticamente tutti i macronutrienti per 100g precompilando la scheda!',
                  color: Colors.orangeAccent,
                ),
                const SizedBox(height: 14),
                _buildGuideSection(
                  title: '4. Sezione Alimenti & Storico 📊',
                  description:
                      'Gli alimenti aggiunti sono memorizzati nella scheda "I Miei Alimenti" per un inserimento rapido. Configura la tua API Key Gemini dal tuo Profilo per abilitare le elaborazioni visive.',
                  color: Colors.blueAccent,
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentCyan,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Ho capito', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGuideSection({required String title, required String description, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildAddButton() {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          final hour = DateTime.now().hour;
          String defaultMeal = 'Colazione';
          if (hour >= 11 && hour < 15) {
            defaultMeal = 'Pranzo';
          } else if (hour >= 15 && hour < 19) {
            defaultMeal = 'Spuntini';
          } else if (hour >= 19) {
            defaultMeal = 'Cena';
          }
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => WholeMealAiDialog(defaultMeal: defaultMeal),
          );
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_circle_outline_rounded,
                color: _accentCyan,
                size: 26,
              ),
              SizedBox(height: 4),
              Text(
                'Aggiungi',
                style: TextStyle(
                  color: _accentCyan,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: _bgCard,
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.06), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
              _buildNavItem(1, Icons.restaurant_menu_rounded, Icons.restaurant_menu_outlined, 'Alimenti'),
              _buildAddButton(),
              _buildNavItem(2, Icons.manage_accounts_rounded, Icons.manage_accounts_outlined, 'Profilo'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isSelected = _currentIndex == index;
    final color = index == 0
        ? _accentCyan
        : index == 1
            ? Colors.orangeAccent
            : _accentPink;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTapped(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isSelected ? activeIcon : inactiveIcon,
                  key: ValueKey(isSelected),
                  color: isSelected ? color : Colors.white38,
                  size: 26,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: isSelected ? color : Colors.white38,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  letterSpacing: 0.3,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
