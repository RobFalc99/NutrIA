import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';

/// Schermata principale con BottomNavigationBar.
/// Dashboard e Impostazioni sono sempre montate nell'albero dei widget
/// (usando IndexedStack) — nessuna navigazione, nessun problema di context.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _requestInitialPermissions();
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

  static const _accentCyan = Color(0xFF00FFC2);
  static const _accentPink = Color(0xFFFF007F);
  static const _bgDark = Color(0xFF0F0F13);
  static const _bgCard = Color(0xFF16161D);

  // IndexedStack mantiene entrambe le tab sempre montate in memoria.
  // Così ProfileScreen non deve mai "navigare" e il suo stato è sempre disponibile.
  final List<Widget> _screens = const [
    DashboardScreen(),
    ProfileScreen(),
  ];

  void _onTabTapped(int index) {
    HapticFeedback.lightImpact();
    setState(() => _currentIndex = index);
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

  void _showAddMealOptions(BuildContext context) {
    final hour = DateTime.now().hour;
    String defaultMeal = 'Colazione';
    if (hour >= 11 && hour < 15) {
      defaultMeal = 'Pranzo';
    } else if (hour >= 15 && hour < 19) {
      defaultMeal = 'Spuntini';
    } else if (hour >= 19) {
      defaultMeal = 'Cena';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16161D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return AddMealOptionsSheet(defaultMeal: defaultMeal);
      },
    );
  }

  Widget _buildAddButton() {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          _showAddMealOptions(context);
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.add_circle_outline_rounded,
                color: _accentCyan,
                size: 26,
              ),
              const SizedBox(height: 4),
              const Text(
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
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
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
              _buildAddButton(),
              _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
              _buildNavItem(1, Icons.manage_accounts_rounded, Icons.manage_accounts_outlined, 'Profilo'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isSelected = _currentIndex == index;
    final color = index == 0 ? _accentCyan : _accentPink;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTapped(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
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
