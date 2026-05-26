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
  
  TextEditingController? _nameController;
  TextEditingController? _caloriesController;
  TextEditingController? _proteinsController;
  TextEditingController? _carbsController;
  TextEditingController? _fatsController;
  TextEditingController? _fibersController;
  TextEditingController? _apiKeyController;

  String _trackingMode = 'standard';
  bool _use8020Mode = true;
  bool _obscureApiKey = true;
  bool _initialized = false;

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
    _nameController?.dispose();
    _caloriesController?.dispose();
    _proteinsController?.dispose();
    _carbsController?.dispose();
    _fatsController?.dispose();
    _fibersController?.dispose();
    _apiKeyController?.dispose();
    super.dispose();
  }

  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
      final appState = context.read<AppState>();
      
      final updatedProfile = UserProfileEntity()
        ..id = appState.currentUser?.id ?? 1
        ..name = _nameController!.text.trim()
        ..goalCalories = double.tryParse(_caloriesController!.text) ?? 2000
        ..goalProteins = double.tryParse(_proteinsController!.text) ?? 150
        ..goalCarbs = double.tryParse(_carbsController!.text) ?? 200
        ..goalFats = double.tryParse(_fatsController!.text) ?? 60
        ..goalFibers = double.tryParse(_fibersController!.text) ?? 30
        ..trackingMode = _trackingMode
        ..use8020Mode = _use8020Mode
        ..geminiApiKey = _apiKeyController!.text.trim().isEmpty ? null : _apiKeyController!.text.trim();

      appState.updateProfile(updatedProfile);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profilo salvato con successo!'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.currentUser;

    // Se Isar non ha ancora completato il caricamento del profilo, mostra un caricamento premium
    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F13),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00FFC2)),
        ),
      );
    }

    // Inizializza i controller solo una volta caricato il profilo
    if (!_initialized) {
      _initControllers(user);
    }

    const accentCyan = Color(0xFF00FFC2);
    const accentPink = Color(0xFFFF007F);
    
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text('Profilo & Target', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: accentCyan),
            onPressed: _saveProfile,
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentCyan.withOpacity(0.15), accentPink.withOpacity(0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Color(0xFF1B1B22),
                      child: Icon(Icons.person, size: 45, color: accentCyan),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _nameController!.text.isEmpty ? 'Atleta KCALcolatore' : _nameController!.text,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Personalizza il tuo piano nutrizionale premium',
                      style: TextStyle(fontSize: 13, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Tracking Mode
              const Text('Modalità di Tracciamento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    Expanded(child: _buildModeTab('light', 'Light')),
                    Expanded(child: _buildModeTab('standard', 'Standard')),
                    Expanded(child: _buildModeTab('custom', 'Custom')),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Macro Goals Container
              const Text('Target Nutrizionali Giornalieri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
                    _buildInputField('Nome Utente', _nameController!, TextInputType.name, prefix: Icons.badge),
                    const SizedBox(height: 16),
                    _buildInputField('Obiettivo Calorie (kcal)', _caloriesController!, TextInputType.number, prefix: Icons.local_fire_department, suffix: 'kcal'),
                    const SizedBox(height: 16),
                    _buildInputField('Obiettivo Proteine (g)', _proteinsController!, TextInputType.number, prefix: Icons.fitness_center, suffix: 'g'),
                    
                    if (_trackingMode != 'light') ...[
                      const SizedBox(height: 16),
                      _buildInputField('Obiettivo Carboidrati (g)', _carbsController!, TextInputType.number, prefix: Icons.restaurant_menu, suffix: 'g'),
                      const SizedBox(height: 16),
                      _buildInputField('Obiettivo Grassi (g)', _fatsController!, TextInputType.number, prefix: Icons.opacity, suffix: 'g'),
                    ],
                    
                    if (_trackingMode == 'custom') ...[
                      const SizedBox(height: 16),
                      _buildInputField('Obiettivo Fibre (g)', _fibersController!, TextInputType.number, prefix: Icons.grain, suffix: 'g'),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 80/20 Settings
              const Text('Regola 80/20 & Cheat Day', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: SwitchListTile(
                  value: _use8020Mode,
                  onChanged: (val) {
                    setState(() {
                      _use8020Mode = val;
                    });
                  },
                  activeColor: accentCyan,
                  title: const Text('Abilita Statistiche 80/20', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: const Text(
                    'Escludi automaticamente i giorni "liberi" (non tracciati) dalle medie nutrizionali settimanali per mantenere statistiche pulite.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // API Key Gemini
              const Text('Integrazione AI Google Gemini', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Gemini API Key',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(Icons.vpn_key, color: accentPink),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureApiKey ? Icons.visibility : Icons.visibility_off, color: Colors.white54),
                          onPressed: () {
                            setState(() {
                              _obscureApiKey = !_obscureApiKey;
                            });
                          },
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: accentCyan)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'La tua chiave API viene salvata esclusivamente nel database protetto offline sul tuo smartphone ed usata direttamente per le chiamate nutrizionali AI.',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Save Button
              ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentPink,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text(
                  'Salva Configurazione',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeTab(String mode, String label) {
    final isSelected = _trackingMode == mode;
    const accentCyan = Color(0xFF00FFC2);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _trackingMode = mode;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? accentCyan.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? accentCyan : Colors.white60,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, TextInputType keyboardType, {required IconData prefix, String? suffix}) {
    const accentCyan = Color(0xFF00FFC2);
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      validator: (val) {
        if (val == null || val.isEmpty) return 'Campo obbligatorio';
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(prefix, color: accentCyan),
        suffixText: suffix,
        suffixStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: accentCyan)),
      ),
    );
  }
}
