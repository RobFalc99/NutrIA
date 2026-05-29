import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../data/local/entities/user_profile_entity.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Watches the AppState for changes. Rebuilds automatically when AppState notifies listeners.
    final user = context.watch<AppState>().currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F13),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00FFC2)),
        ),
      );
    }

    return ProfileForm(user: user);
  }
}

class ProfileForm extends StatefulWidget {
  final UserProfileEntity user;
  const ProfileForm({super.key, required this.user});

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinsController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatsController;
  late final TextEditingController _fibersController;
  late final TextEditingController _apiKeyController;

  late String _trackingMode;
  late bool _use8020Mode;
  late String _selectedModel;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    _nameController = TextEditingController(text: widget.user.name);
    _caloriesController = TextEditingController(text: widget.user.goalCalories.toInt().toString());
    _proteinsController = TextEditingController(text: widget.user.goalProteins.toInt().toString());
    _carbsController = TextEditingController(text: widget.user.goalCarbs.toInt().toString());
    _fatsController = TextEditingController(text: widget.user.goalFats.toInt().toString());
    _fibersController = TextEditingController(text: widget.user.goalFibers.toInt().toString());
    _apiKeyController = TextEditingController(text: widget.user.geminiApiKey ?? '');

    _trackingMode = widget.user.trackingMode;
    _use8020Mode = widget.user.use8020Mode;
    _selectedModel = widget.user.geminiModel ?? 'gemma-4-26b-a4b-it';

    _proteinsController.addListener(_updateCalculatedGoalCalories);
    _carbsController.addListener(_updateCalculatedGoalCalories);
    _fatsController.addListener(_updateCalculatedGoalCalories);
    _fibersController.addListener(_updateCalculatedGoalCalories);
  }

  void _updateCalculatedGoalCalories() {
    final protText = _proteinsController.text.trim();
    final carbText = _carbsController.text.trim();
    final fatText = _fatsController.text.trim();
    final fibText = _fibersController.text.trim();

    if (protText.isEmpty && carbText.isEmpty && fatText.isEmpty && fibText.isEmpty) {
      return;
    }

    final prot = double.tryParse(protText) ?? 0.0;
    final carb = double.tryParse(carbText) ?? 0.0;
    final fat = double.tryParse(fatText) ?? 0.0;
    final fib = double.tryParse(fibText) ?? 0.0;

    final double calculated = (prot * 4.0) + (carb * 4.0) + (fat * 9.0) + (fib * 2.0);
    _caloriesController.text = calculated.toStringAsFixed(calculated % 1 == 0 ? 0 : 1);
  }

  @override
  void didUpdateWidget(ProfileForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user != oldWidget.user) {
      if (_nameController.text != widget.user.name) {
        _nameController.text = widget.user.name;
      }
      final calStr = widget.user.goalCalories.toInt().toString();
      if (_caloriesController.text != calStr) {
        _caloriesController.text = calStr;
      }
      final protStr = widget.user.goalProteins.toInt().toString();
      if (_proteinsController.text != protStr) {
        _proteinsController.text = protStr;
      }
      final carbStr = widget.user.goalCarbs.toInt().toString();
      if (_carbsController.text != carbStr) {
        _carbsController.text = carbStr;
      }
      final fatStr = widget.user.goalFats.toInt().toString();
      if (_fatsController.text != fatStr) {
        _fatsController.text = fatStr;
      }
      final fibStr = widget.user.goalFibers.toInt().toString();
      if (_fibersController.text != fibStr) {
        _fibersController.text = fibStr;
      }
      final apiKeyStr = widget.user.geminiApiKey ?? '';
      if (_apiKeyController.text != apiKeyStr) {
        _apiKeyController.text = apiKeyStr;
      }
      final modelStr = widget.user.geminiModel ?? 'gemma-4-26b-a4b-it';
      if (_selectedModel != modelStr) {
        setState(() {
          _selectedModel = modelStr;
        });
      }
      if (_trackingMode != widget.user.trackingMode) {
        setState(() {
          _trackingMode = widget.user.trackingMode;
        });
      }
      if (_use8020Mode != widget.user.use8020Mode) {
        setState(() {
          _use8020Mode = widget.user.use8020Mode;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinsController.dispose();
    _carbsController.dispose();
    _fatsController.dispose();
    _fibersController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final appState = context.read<AppState>();
    final profile = UserProfileEntity()
      ..id = appState.currentUser?.id ?? 1
      ..name = _nameController.text.trim().isEmpty ? 'Atleta KCALcolatore' : _nameController.text.trim()
      ..goalCalories = double.tryParse(_caloriesController.text) ?? 2000
      ..goalProteins = double.tryParse(_proteinsController.text) ?? 150
      ..goalCarbs = double.tryParse(_carbsController.text) ?? 200
      ..goalFats = double.tryParse(_fatsController.text) ?? 60
      ..goalFibers = double.tryParse(_fibersController.text) ?? 30
      ..trackingMode = _trackingMode
      ..use8020Mode = _use8020Mode
      ..geminiApiKey = _apiKeyController.text.trim().isEmpty
          ? null
          : _apiKeyController.text.trim()
      ..geminiModel = _selectedModel;
    appState.updateProfile(profile);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profilo salvato!'),
        backgroundColor: Color(0xFF00FFC2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Profilo & Impostazioni',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'SALVA',
              style: TextStyle(
                color: Color(0xFF00FFC2),
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Streak Card ──────────────────────────────────────────────────
            FutureBuilder<int>(
              future: context.read<AppState>().getTrackingStreak(),
              builder: (context, snapshot) {
                final streak = snapshot.data ?? 0;
                final hasStreak = streak > 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: hasStreak
                          ? [const Color(0xFFFF6B00).withOpacity(0.18), const Color(0xFFFFD700).withOpacity(0.08)]
                          : [Colors.white.withOpacity(0.03), Colors.white.withOpacity(0.01)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: hasStreak ? const Color(0xFFFF6B00).withOpacity(0.3) : Colors.white.withOpacity(0.06),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Fuocherello animato/statico
                      Text(
                        hasStreak ? '🔥' : '🌱',
                        style: const TextStyle(fontSize: 36),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasStreak ? '$streak ${streak == 1 ? 'giorno' : 'giorni'} di streak!' : 'Inizia il tuo streak oggi!',
                              style: TextStyle(
                                color: hasStreak ? const Color(0xFFFFD700) : Colors.white54,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              hasStreak
                                  ? 'Stai tracciando i tuoi pasti ogni giorno 💪'
                                  : 'Registra almeno un pasto per iniziare',
                              style: const TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (hasStreak) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B00).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFF6B00).withOpacity(0.3)),
                          ),
                          child: Text(
                            '🔥$streak',
                            style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),

            // ── Modalità tracciamento ────────────────────────────────────────
            const _SectionTitle(title: 'Modalita\' di Tracciamento'),
            const SizedBox(height: 10),
            Row(
              children: [
                _ModeChip(label: 'Light', value: 'light', selected: _trackingMode, onTap: (v) => setState(() => _trackingMode = v)),
                const SizedBox(width: 8),
                _ModeChip(label: 'Standard', value: 'standard', selected: _trackingMode, onTap: (v) => setState(() => _trackingMode = v)),
                const SizedBox(width: 8),
                _ModeChip(label: 'Custom', value: 'custom', selected: _trackingMode, onTap: (v) => setState(() => _trackingMode = v)),
              ],
            ),
            const SizedBox(height: 24),

            // ── Dati utente ──────────────────────────────────────────────────
            const _SectionTitle(title: 'Dati Utente'),
            const SizedBox(height: 10),
            _Field(label: 'Nome', controller: _nameController, icon: Icons.person),
            const SizedBox(height: 12),
            _Field(label: 'Calorie obiettivo (kcal)', controller: _caloriesController, icon: Icons.local_fire_department, numeric: true, suffix: 'kcal'),
            const SizedBox(height: 12),
            _Field(label: 'Proteine (g)', controller: _proteinsController, icon: Icons.fitness_center, numeric: true, suffix: 'g'),

            if (_trackingMode != 'light') ...[
              const SizedBox(height: 12),
              _Field(label: 'Carboidrati (g)', controller: _carbsController, icon: Icons.restaurant, numeric: numericKeyboardType(), suffix: 'g'),
              const SizedBox(height: 12),
              _Field(label: 'Grassi (g)', controller: _fatsController, icon: Icons.water_drop, numeric: true, suffix: 'g'),
            ],

            if (_trackingMode == 'custom') ...[
              const SizedBox(height: 12),
              _Field(label: 'Fibre (g)', controller: _fibersController, icon: Icons.grass, numeric: true, suffix: 'g'),
            ],
            const SizedBox(height: 24),

            // ── Regola 80/20 ─────────────────────────────────────────────────
            const _SectionTitle(title: 'Regola 80/20'),
            const SizedBox(height: 10),
            _ToggleCard(
              title: 'Abilita modalita\' 80/20',
              subtitle: 'I giorni non tracciati vengono esclusi dalle medie settimanali.',
              value: _use8020Mode,
              onChanged: (v) => setState(() => _use8020Mode = v),
            ),
            const SizedBox(height: 24),

            // ── Gemini API ───────────────────────────────────────────────────
            const _SectionTitle(title: 'Chiave API Gemini (AI)'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _apiKeyController,
              obscureText: _obscureApiKey,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Gemini API Key',
                labelStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.vpn_key, color: Color(0xFFFF007F)),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureApiKey ? Icons.visibility : Icons.visibility_off,
                    color: Colors.white38,
                  ),
                  onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                ),
                filled: true,
                fillColor: const Color(0xFF1C1C24),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00FFC2)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Salvata solo sul dispositivo. Usata per le funzioni AI.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 16),

            // ── Modello IA ───────────────────────────────────────────────────
            const _SectionTitle(title: 'Modello IA Selezionato'),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedModel,
              style: const TextStyle(color: Colors.white),
              dropdownColor: const Color(0xFF1C1C24),
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Seleziona Modello IA',
                labelStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.settings_suggest, color: Color(0xFF00FFC2)),
                filled: true,
                fillColor: const Color(0xFF1C1C24),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00FFC2)),
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'gemma-4-26b-a4b-it',
                  child: Text('Gemma 4 26B (Mixture-of-Experts) - Consigliato'),
                ),
                DropdownMenuItem(
                  value: 'gemma-4-31b-it',
                  child: Text('Gemma 4 31B (Dense)'),
                ),
                DropdownMenuItem(
                  value: 'gemini-3.5-flash',
                  child: Text('Gemini 3.5 Flash'),
                ),
                DropdownMenuItem(
                  value: 'gemini-3-flash',
                  child: Text('Gemini 3 Flash'),
                ),
                DropdownMenuItem(
                  value: 'gemini-3.1-flash-lite',
                  child: Text('Gemini 3.1 Flash Lite'),
                ),
                DropdownMenuItem(
                  value: 'gemini-2.5-flash',
                  child: Text('Gemini 2.5 Flash'),
                ),
                DropdownMenuItem(
                  value: 'gemini-2.5-flash-lite',
                  child: Text('Gemini 2.5 Flash Lite'),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedModel = val;
                  });
                }
              },
            ),
            const SizedBox(height: 32),

            // ── Bottone salva ────────────────────────────────────────────────
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FFC2),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'Salva Configurazione',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  bool numericKeyboardType() => true;
}

// ─── Widget ausiliari semplici ────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});
  @override
  Widget build(BuildContext context) => Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      );
}

class _ModeChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final void Function(String) onTap;
  const _ModeChip({required this.label, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isOn = selected == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isOn ? const Color(0xFF00FFC2).withOpacity(0.15) : const Color(0xFF1C1C24),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isOn ? const Color(0xFF00FFC2) : Colors.white12,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isOn ? const Color(0xFF00FFC2) : Colors.white54,
              fontWeight: isOn ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool numeric;
  final String? suffix;

  const _Field({
    required this.label,
    required this.controller,
    required this.icon,
    this.numeric = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      validator: (v) {
        if (v == null || v.trim().isEmpty) {
          return null; // Non richiesto, usiamo fallbacks sicuri al salvataggio
        }
        if (numeric && double.tryParse(v) == null) {
          return 'Inserisci un numero valido';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: const Color(0xFF00FFC2), size: 20),
        suffixText: suffix,
        suffixStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: const Color(0xFF1C1C24),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00FFC2)),
        ),
        errorStyle: const TextStyle(color: Color(0xFFFF6B6B)),
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final void Function(bool) onChanged;

  const _ToggleCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C24),
        borderRadius: BorderRadius.circular(14),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF00FFC2),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ),
    );
  }
}
