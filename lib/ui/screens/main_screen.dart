import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'alimenti_screen.dart';

/// Schermata principale con BottomNavigationBar.
/// Dashboard, Alimenti e Impostazioni sono sempre montate nell'albero dei widget
/// (usando IndexedStack) — nessuna navigazione, nessun problema di context.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _isAddMenuOpen = false;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          
          // Overlay scuro se il menu "+" è aperto
          if (_isAddMenuOpen)
            GestureDetector(
              onTap: () {
                setState(() {
                  _isAddMenuOpen = false;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                color: Colors.black.withOpacity(0.6),
              ),
            ),

          // Menu popup dei bottoni "+" posizionato sopra il tasto
          if (_isAddMenuOpen)
            Positioned(
              bottom: 84, // Subito sopra la bottom nav bar
              right: MediaQuery.of(context).size.width * 0.14, // Allineato con il pulsante Aggiungi
              child: _buildPopUpMenu(),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildPopUpMenu() {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPopupItem(
            icon: Icons.menu_book,
            label: 'Manuale ✍️',
            color: _accentPink,
            onTap: () {
              setState(() => _isAddMenuOpen = false);
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
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Divider(color: Colors.white10, height: 1),
          ),
          _buildPopupItem(
            icon: Icons.auto_awesome,
            label: 'Analisi IA 🪄',
            color: _accentCyan,
            onTap: () {
              setState(() => _isAddMenuOpen = false);
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
          ),
        ],
      ),
    );
  }

  Widget _buildPopupItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          setState(() {
            _isAddMenuOpen = !_isAddMenuOpen;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedRotation(
                turns: _isAddMenuOpen ? 0.125 : 0, // Ruota di 45 gradi (0.125 giri) se aperto per fare una "x"
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: Icon(
                  _isAddMenuOpen ? Icons.add_circle : Icons.add_circle_outline_rounded,
                  color: _isAddMenuOpen ? _accentPink : _accentCyan,
                  size: 26,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: _isAddMenuOpen ? _accentPink : _accentCyan,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
                child: const Text('Aggiungi'),
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
