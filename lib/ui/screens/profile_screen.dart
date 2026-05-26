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
  // Controller inizializzati SOLO in didChangeDependencies - pattern Flutter corretto
  final _formKey = GlobalKey<FormState>();

  final _nameController       = TextEditingController();
  final _caloriesController   = TextEditingController();
  final _proteinsController   = TextEditingController();
  final _carbsController      = TextEditingController();
  final _fatsController       = TextEditingController();
  final _fibersController     = TextEditingController();
  final _apiKeyController     = TextEditingController();

  String _trackingMode = 'standard';
  bool   _use8020Mode  = true;
  bool   _obscureApiKey = true;
  bool   _initialized  = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Legge il profilo dal Provider e popola i controller UNA SOLA VOLTA
    if (!_initialized) {
      final user = context.read<AppState>().currentUser;
      if (user != null) {
        _nameController.text       = user.name;
        _caloriesController.text   = user.goalCalories.toInt().toString();
        _proteinsController.text   = user.goalProteins.toInt().toString();
        _carbsController.text      = user.goalCarbs.toInt().toString();
        _fatsController.text       = user.goalFats.toInt().toString();
        _fibersController.text     = user.goalFibers.toInt().toString();
        _apiKeyController.text     = user.geminiApiKey ?? '';
        _trackingMode              = user.trackingMode;
        _use8020Mode               = user.use8020Mode;
        _initialized = true;
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
    final profile  = UserProfileEntity()
      ..id            = appState.currentUser?.id ?? 1
      ..name          = _nameController.text.trim()
      ..goalCalories  = double.tryParse(_caloriesController.text) ?? 2000
      ..goalProteins  = double.tryParse(_proteinsController.text) ?? 150
      ..goalCarbs     = double.tryParse(_carbsController.text) ?? 200
      ..goalFats      = double.tryParse(_fatsController.text) ?? 60
      ..goalFibers    = double.tryParse(_fibersController.text) ?? 30
      ..trackingMode  = _trackingMode
      ..use8020Mode   = _use8020Mode
      ..geminiApiKey  = _apiKeyController.text.trim().isEmpty
                          ? null
                          : _apiKeyController.text.trim();
    appState.updateProfile(profile);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profilo salvato!'),
        backgroundColor: Color(0xFF00FFC2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Se i dati non sono ancora pronti, mostra solo uno spinner
    if (!_initialized) {
      // Tenta di inizializzare ad ogni rebuild finché il profilo non è disponibile
      final user = context.watch<AppState>().currentUser;
      if (user != null && !_initialized) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _nameController.text     = user.name;
            _caloriesController.text = user.goalCalories.toInt().toString();
            _proteinsController.text = user.goalProteins.toInt().toString();
            _carbsController.text    = user.goalCarbs.toInt().toString();
            _fatsController.text     = user.goalFats.toInt().toString();
            _fibersController.text   = user.goalFibers.toInt().toString();
            _apiKeyController.text   = user.geminiApiKey ?? '';
            _trackingMode            = user.trackingMode;
            _use8020Mode             = user.use8020Mode;
            _initialized             = true;
          });
        });
      }
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F13),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00FFC2)),
        ),
      );
    }

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

            // ── Modalità tracciamento ────────────────────────────────────────
            _SectionTitle(title: 'Modalita\' di Tracciamento'),
            const SizedBox(height: 10),
            Row(
              children: [
                _ModeChip(label: 'Light',    value: 'light',    selected: _trackingMode, onTap: (v) => setState(() => _trackingMode = v)),
                const SizedBox(width: 8),
                _ModeChip(label: 'Standard', value: 'standard', selected: _trackingMode, onTap: (v) => setState(() => _trackingMode = v)),
                const SizedBox(width: 8),
                _ModeChip(label: 'Custom',   value: 'custom',   selected: _trackingMode, onTap: (v) => setState(() => _trackingMode = v)),
              ],
            ),
            const SizedBox(height: 24),

            // ── Dati utente ──────────────────────────────────────────────────
            _SectionTitle(title: 'Dati Utente'),
            const SizedBox(height: 10),
            _Field(label: 'Nome', controller: _nameController, icon: Icons.person),
            const SizedBox(height: 12),
            _Field(label: 'Calorie obiettivo (kcal)', controller: _caloriesController,
                   icon: Icons.local_fire_department, numeric: true, suffix: 'kcal'),
            const SizedBox(height: 12),
            _Field(label: 'Proteine (g)', controller: _proteinsController,
                   icon: Icons.fitness_center, numeric: true, suffix: 'g'),

            if (_trackingMode != 'light') ...[
              const SizedBox(height: 12),
              _Field(label: 'Carboidrati (g)', controller: _carbsController,
                     icon: Icons.restaurant, numeric: true, suffix: 'g'),
              const SizedBox(height: 12),
              _Field(label: 'Grassi (g)', controller: _fatsController,
                     icon: Icons.water_drop, numeric: true, suffix: 'g'),
            ],

            if (_trackingMode == 'custom') ...[
              const SizedBox(height: 12),
              _Field(label: 'Fibre (g)', controller: _fibersController,
                     icon: Icons.grass, numeric: true, suffix: 'g'),
            ],
            const SizedBox(height: 24),

            // ── Regola 80/20 ─────────────────────────────────────────────────
            _SectionTitle(title: 'Regola 80/20'),
            const SizedBox(height: 10),
            _ToggleCard(
              title: 'Abilita modalita\' 80/20',
              subtitle: 'I giorni non tracciati vengono esclusi dalle medie settimanali.',
              value: _use8020Mode,
              onChanged: (v) => setState(() => _use8020Mode = v),
            ),
            const SizedBox(height: 24),

            // ── Gemini API ───────────────────────────────────────────────────
            _SectionTitle(title: 'Chiave API Gemini (AI)'),
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
            color: isOn ? const Color(0xFF00FFC2).withValues(alpha: 0.15) : const Color(0xFF1C1C24),
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
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo richiesto' : null,
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
