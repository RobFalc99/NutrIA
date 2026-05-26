import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../data/local/entities/user_profile_entity.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _caloriesController;
  late TextEditingController _proteinsController;
  late TextEditingController _carbsController;
  late TextEditingController _fatsController;
  late TextEditingController _fibersController;
  late TextEditingController _apiKeyController;

  String _trackingMode = 'standard';
  bool _use8020Mode = true;
  bool _obscureApiKey = true;
  bool _initialized = false;

  // Costanti colori
  static const _accentCyan = Color(0xFF00FFC2);
  static const _accentPink = Color(0xFFFF007F);
  static const _bgDark = Color(0xFF0F0F13);

  void _initControllers(UserProfileEntity user) {
    _nameController = TextEditingController(text: user.name);
    _caloriesController = TextEditingController(text: user.goalCalories.toInt().toString());
    _proteinsController = TextEditingController(text: user.goalProteins.toInt().toString());
    _carbsController = TextEditingController(text: user.goalCarbs.toInt().toString());
    _fatsController = TextEditingController(text: user.goalFats.toInt().toString());
    _fibersController = TextEditingController(text: user.goalFibers.toInt().toString());
    _apiKeyController = TextEditingController(text: user.geminiApiKey ?? '');
    _trackingMode = user.trackingMode;
    _use8020Mode = user.use8020Mode;
    _initialized = true;
  }

  @override
  void dispose() {
    if (_initialized) {
      _nameController.dispose();
      _caloriesController.dispose();
      _proteinsController.dispose();
      _carbsController.dispose();
      _fatsController.dispose();
      _fibersController.dispose();
      _apiKeyController.dispose();
    }
    super.dispose();
  }

  void _saveProfile() {
    if (!_initialized) return;
    if (_formKey.currentState!.validate()) {
      final appState = context.read<AppState>();

      final updatedProfile = UserProfileEntity()
        ..id = appState.currentUser?.id ?? 1
        ..name = _nameController.text.trim()
        ..goalCalories = double.tryParse(_caloriesController.text) ?? 2000
        ..goalProteins = double.tryParse(_proteinsController.text) ?? 150
        ..goalCarbs = double.tryParse(_carbsController.text) ?? 200
        ..goalFats = double.tryParse(_fatsController.text) ?? 60
        ..goalFibers = double.tryParse(_fibersController.text) ?? 30
        ..trackingMode = _trackingMode
        ..use8020Mode = _use8020Mode
        ..geminiApiKey = _apiKeyController.text.trim().isEmpty
            ? null
            : _apiKeyController.text.trim();

      appState.updateProfile(updatedProfile);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profilo salvato!'),
          backgroundColor: _accentCyan.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
      // Non c'e' piu' Navigator.pop: ProfileScreen e' una tab permanente
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.currentUser;

    // Schermata di caricamento premium mentre Isar non ha ancora restituito il profilo
    if (user == null) {
      return const Scaffold(
        backgroundColor: _bgDark,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: _accentCyan),
              SizedBox(height: 16),
              Text(
                'Caricamento profilo...',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // Inizializza i controller solo una volta, quando il profilo è disponibile
    if (!_initialized) {
      _initControllers(user);
    }

    final displayName = _nameController.text.trim().isEmpty
        ? 'Atleta KCALcolatore'
        : _nameController.text.trim();

    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Profilo & Target',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.check, color: _accentCyan),
            label: const Text('Salva', style: TextStyle(color: _accentCyan, fontWeight: FontWeight.bold)),
            onPressed: _saveProfile,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Avatar Banner ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_accentCyan.withOpacity(0.12), _accentPink.withOpacity(0.06)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1B1B22),
                        border: Border.all(color: _accentCyan.withOpacity(0.4), width: 2),
                      ),
                      child: const Icon(Icons.person, size: 44, color: _accentCyan),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Personalizza il tuo piano nutrizionale',
                      style: TextStyle(fontSize: 13, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Modalità di Tracciamento ──────────────────────────────
              _sectionLabel('Modalita\' di Tracciamento'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    Expanded(child: _buildModeTab('light', 'Light', Icons.flash_on)),
                    Expanded(child: _buildModeTab('standard', 'Standard', Icons.bar_chart)),
                    Expanded(child: _buildModeTab('custom', 'Custom', Icons.tune)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Target Nutrizionali ───────────────────────────────────
              _sectionLabel('Target Nutrizionali Giornalieri'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  children: [
                    _buildInputField('Nome Utente', _nameController, TextInputType.name, prefix: Icons.badge),
                    const SizedBox(height: 16),
                    _buildInputField('Calorie (kcal)', _caloriesController, TextInputType.number, prefix: Icons.local_fire_department, suffix: 'kcal', color: _accentPink),
                    const SizedBox(height: 16),
                    _buildInputField('Proteine (g)', _proteinsController, TextInputType.number, prefix: Icons.fitness_center, suffix: 'g', color: _accentCyan),

                    if (_trackingMode != 'light') ...[
                      const SizedBox(height: 16),
                      _buildInputField('Carboidrati (g)', _carbsController, TextInputType.number, prefix: Icons.restaurant_menu, suffix: 'g', color: const Color(0xFFFFD700)),
                      const SizedBox(height: 16),
                      _buildInputField('Grassi (g)', _fatsController, TextInputType.number, prefix: Icons.opacity, suffix: 'g', color: const Color(0xFFFF6B35)),
                    ],

                    if (_trackingMode == 'custom') ...[
                      const SizedBox(height: 16),
                      _buildInputField('Fibre (g)', _fibersController, TextInputType.number, prefix: Icons.grain, suffix: 'g', color: const Color(0xFF00E676)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Regola 80/20 ──────────────────────────────────────────
              _sectionLabel('Regola 80/20 & Cheat Day'),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: SwitchListTile(
                  value: _use8020Mode,
                  onChanged: (val) => setState(() => _use8020Mode = val),
                  activeColor: _accentCyan,
                  title: const Text(
                    'Abilita Statistiche 80/20',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Escludi automaticamente i "cheat day" dalle medie settimanali per statistiche accurate.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Integrazione Gemini AI ────────────────────────────────
              _sectionLabel('Integrazione AI — Google Gemini'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _apiKeyController,
                      obscureText: _obscureApiKey,
                      style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        labelText: 'Gemini API Key',
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: 'Incolla qui la tua chiave AI...',
                        hintStyle: const TextStyle(color: Colors.white24),
                        prefixIcon: const Icon(Icons.vpn_key, color: _accentPink),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureApiKey ? Icons.visibility : Icons.visibility_off,
                            color: Colors.white54,
                          ),
                          onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(color: _accentCyan),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.lock_outline, size: 14, color: Colors.white38),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'La chiave viene salvata solo sul tuo dispositivo e usata direttamente per le chiamate AI.',
                            style: TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // ── Bottone Salva ─────────────────────────────────────────
              ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                  shadowColor: _accentCyan.withOpacity(0.4),
                ),
                child: const Text(
                  'Salva Configurazione',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildModeTab(String mode, String label, IconData icon) {
    final isSelected = _trackingMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _trackingMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? _accentCyan.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: _accentCyan.withOpacity(0.4), width: 1)
              : null,
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: isSelected ? _accentCyan : Colors.white38),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? _accentCyan : Colors.white54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    TextInputType keyboardType, {
    required IconData prefix,
    String? suffix,
    Color color = _accentCyan,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      validator: (val) {
        if (val == null || val.trim().isEmpty) return 'Campo obbligatorio';
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: Icon(prefix, color: color, size: 20),
        suffixText: suffix,
        suffixStyle: TextStyle(color: color.withOpacity(0.7), fontWeight: FontWeight.bold),
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color.withOpacity(0.6)),
        ),
        errorStyle: const TextStyle(color: Color(0xFFFF6B6B)),
      ),
    );
  }
}
