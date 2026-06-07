import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/app_state.dart';
import '../../data/local/entities/user_profile_entity.dart';
import '../../providers/translations.dart';
import '../../domain/models.dart';

enum ProfileSection {
  main,
  datiUtente,
  analisiSettimanale,
  impostazioniTracciamento,
  impostazioniAI,
  impostazioniGenerali,
  feedbackSupporto,
}

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
  late int _historyLimit;
  late String _startupScreen;
  late int _defaultAlimentiTab;
  late String _languageCode;
  bool _obscureApiKey = true;

  bool _isDirty = false;
  ProfileSection _currentSection = ProfileSection.main;

  void _checkIfDirty() {
    final nameVal = _nameController.text.trim().isEmpty ? 'Atleta NutrIA' : _nameController.text.trim();
    final calVal = double.tryParse(_caloriesController.text) ?? 2000;
    final protVal = double.tryParse(_proteinsController.text) ?? 150;
    final carbVal = double.tryParse(_carbsController.text) ?? 200;
    final fatVal = double.tryParse(_fatsController.text) ?? 60;
    final fibVal = double.tryParse(_fibersController.text) ?? 30;
    final trackingVal = _trackingMode;
    final use8020Val = _use8020Mode;
    final apiKeyVal = _apiKeyController.text.trim().isEmpty ? null : _apiKeyController.text.trim();
    final modelVal = _selectedModel;
    final historyLimitVal = _historyLimit;
    final startupScreenVal = _startupScreen;
    final defaultAlimentiTabVal = _defaultAlimentiTab;
    final languageVal = _languageCode;

    final user = widget.user;
    final bool dirty = nameVal != user.name ||
        calVal != user.goalCalories ||
        protVal != user.goalProteins ||
        carbVal != user.goalCarbs ||
        fatVal != user.goalFats ||
        fibVal != user.goalFibers ||
        trackingVal != user.trackingMode ||
        use8020Val != user.use8020Mode ||
        apiKeyVal != user.geminiApiKey ||
        modelVal != user.geminiModel ||
        historyLimitVal != user.historyLimit ||
        startupScreenVal != user.startupScreen ||
        defaultAlimentiTabVal != user.defaultAlimentiTab ||
        languageVal != user.languageCode;

    if (dirty != _isDirty) {
      setState(() {
        _isDirty = dirty;
      });
      context.read<AppState>().isProfileDirty = dirty;
    }
  }

  @override
  void initState() {
    super.initState();
    _initControllers();
    context.read<AppState>().saveProfileCallback = _save;
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
    _historyLimit = widget.user.historyLimit;
    _startupScreen = widget.user.startupScreen;
    _defaultAlimentiTab = widget.user.defaultAlimentiTab;
    _languageCode = widget.user.languageCode;

    _proteinsController.addListener(_updateCalculatedGoalCalories);
    _carbsController.addListener(_updateCalculatedGoalCalories);
    _fatsController.addListener(_updateCalculatedGoalCalories);
    _fibersController.addListener(_updateCalculatedGoalCalories);

    _nameController.addListener(_checkIfDirty);
    _caloriesController.addListener(_checkIfDirty);
    _proteinsController.addListener(_checkIfDirty);
    _carbsController.addListener(_checkIfDirty);
    _fatsController.addListener(_checkIfDirty);
    _fibersController.addListener(_checkIfDirty);
    _apiKeyController.addListener(_checkIfDirty);
  }

  void _updateCalculatedGoalCalories() {
    final protText = _proteinsController.text.trim();
    final carbText = _carbsController.text.trim();
    final fatText = _fatsController.text.trim();
    final fiberText = _fibersController.text.trim();

    final protVal = double.tryParse(protText) ?? 0;
    final carbVal = (_trackingMode == 'light') ? 0.0 : (double.tryParse(carbText) ?? 0.0);
    final fatVal = (_trackingMode == 'light') ? 0.0 : (double.tryParse(fatText) ?? 0.0);
    final fiberVal = (_trackingMode == 'custom') ? (double.tryParse(fiberText) ?? 0.0) : 0.0;

    final double calculatedKcal = (protVal * 4) + (carbVal * 4) + (fatVal * 9) + (fiberVal * 2);

    if (calculatedKcal > 0) {
      final String calString = calculatedKcal.toInt().toString();
      if (_caloriesController.text != calString) {
        _caloriesController.text = calString;
      }
    }
  }

  @override
  void didUpdateWidget(ProfileForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user != oldWidget.user) {
      _proteinsController.removeListener(_updateCalculatedGoalCalories);
      _carbsController.removeListener(_updateCalculatedGoalCalories);
      _fatsController.removeListener(_updateCalculatedGoalCalories);
      _fibersController.removeListener(_updateCalculatedGoalCalories);

      _nameController.removeListener(_checkIfDirty);
      _caloriesController.removeListener(_checkIfDirty);
      _proteinsController.removeListener(_checkIfDirty);
      _carbsController.removeListener(_checkIfDirty);
      _fatsController.removeListener(_checkIfDirty);
      _fibersController.removeListener(_checkIfDirty);
      _apiKeyController.removeListener(_checkIfDirty);

      _nameController.text = widget.user.name;
      _caloriesController.text = widget.user.goalCalories.toInt().toString();
      _proteinsController.text = widget.user.goalProteins.toInt().toString();
      _carbsController.text = widget.user.goalCarbs.toInt().toString();
      _fatsController.text = widget.user.goalFats.toInt().toString();
      _fibersController.text = widget.user.goalFibers.toInt().toString();
      _apiKeyController.text = widget.user.geminiApiKey ?? '';

      setState(() {
        _trackingMode = widget.user.trackingMode;
        _use8020Mode = widget.user.use8020Mode;
        _selectedModel = widget.user.geminiModel ?? 'gemma-4-26b-a4b-it';
        _historyLimit = widget.user.historyLimit;
        _startupScreen = widget.user.startupScreen;
        if (_defaultAlimentiTab != widget.user.defaultAlimentiTab) {
          _defaultAlimentiTab = widget.user.defaultAlimentiTab;
        }
        _languageCode = widget.user.languageCode;
      });

      _proteinsController.addListener(_updateCalculatedGoalCalories);
      _carbsController.addListener(_updateCalculatedGoalCalories);
      _fatsController.addListener(_updateCalculatedGoalCalories);
      _fibersController.addListener(_updateCalculatedGoalCalories);

      _nameController.addListener(_checkIfDirty);
      _caloriesController.addListener(_checkIfDirty);
      _proteinsController.addListener(_checkIfDirty);
      _carbsController.addListener(_checkIfDirty);
      _fatsController.addListener(_checkIfDirty);
      _fibersController.addListener(_checkIfDirty);
      _apiKeyController.addListener(_checkIfDirty);

      _checkIfDirty();
    }
  }

  @override
  void dispose() {
    context.read<AppState>().saveProfileCallback = null;
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
      ..name = _nameController.text.trim().isEmpty ? 'Atleta NutrIA' : _nameController.text.trim()
      ..goalCalories = double.tryParse(_caloriesController.text) ?? 2000
      ..goalProteins = double.tryParse(_proteinsController.text) ?? 150
      ..goalCarbs = double.tryParse(_carbsController.text) ?? 200
      ..goalFats = double.tryParse(_fatsController.text) ?? 60
      ..goalFibers = double.tryParse(_fibersController.text) ?? 30
      ..trackingMode = _trackingMode
      ..use8020Mode = _use8020Mode
      ..geminiApiKey = _apiKeyController.text.trim().isEmpty ? null : _apiKeyController.text.trim()
      ..geminiModel = _selectedModel
      ..historyLimit = _historyLimit
      ..startupScreen = _startupScreen
      ..defaultAlimentiTab = _defaultAlimentiTab
      ..languageCode = _languageCode;

    appState.updateProfile(profile);
    setState(() {
      _isDirty = false;
    });
    appState.isProfileDirty = false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('Profilo salvato!')),
        backgroundColor: const Color(0xFF00FFC2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F13),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF00FFC2))),
      );
    }
    final stats = appState.weeklyStats;

    return Scaffold(
      backgroundColor: context.bgPrimary,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentSection == ProfileSection.main
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _currentSection = ProfileSection.main;
                  });
                },
              ),
        title: Text(
          _getSectionTitle(_currentSection),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          if (_isDirty)
            TextButton(
              onPressed: _save,
              child: Text(
                context.tr('SALVA'),
                style: const TextStyle(
                  color: Color(0xFF00FFC2),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: _buildBody(context, user, stats, appState),
      ),
    );
  }

  String _getSectionTitle(ProfileSection section) {
    switch (section) {
      case ProfileSection.main:
        return context.tr('Profilo & Impostazioni');
      case ProfileSection.datiUtente:
        return context.tr('Dati Utente & Target');
      case ProfileSection.analisiSettimanale:
        return context.tr('Analisi Settimanale');
      case ProfileSection.impostazioniTracciamento:
        return context.tr('Tracciamento');
      case ProfileSection.impostazioniAI:
        return context.tr('Impostazioni AI');
      case ProfileSection.impostazioniGenerali:
        return context.tr('Impostazioni Generali');
      case ProfileSection.feedbackSupporto:
        return context.tr('Feedback & Supporto');
    }
  }

  Widget _buildBody(BuildContext context, UserProfileEntity user, WeeklyStats stats, AppState appState) {
    switch (_currentSection) {
      case ProfileSection.main:
        return _buildMainSection(context, appState);
      case ProfileSection.datiUtente:
        return _buildDatiUtenteSection(context);
      case ProfileSection.analisiSettimanale:
        return _buildAnalisiSettimanaleSection(context, stats, appState, user);
      case ProfileSection.impostazioniTracciamento:
        return _buildImpostazioniTracciamentoSection(context);
      case ProfileSection.impostazioniAI:
        return _buildImpostazioniAISection(context);
      case ProfileSection.impostazioniGenerali:
        return _buildImpostazioniGeneraliSection(context);
      case ProfileSection.feedbackSupporto:
        return _buildFeedbackSupportoSection(context);
    }
  }

  Widget _buildMainSection(BuildContext context, AppState appState) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        // Streak Card
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
                  colors: [const Color(0xFF00FFC2).withAlpha((0.08 * 255).toInt()), Colors.transparent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withAlpha((0.08 * 255).toInt())),
              ),
              child: Row(
                children: [
                  Icon(
                    hasStreak ? Icons.local_fire_department : Icons.local_fire_department_outlined,
                    color: hasStreak ? const Color(0xFFFF007F) : Colors.white30,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Streak di Tracciamento'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasStreak
                              ? '$streak ${streak == 1 ? context.tr('giorno di streak!') : context.tr('giorni di streak!')}'
                              : context.tr('Inizia il tuo streak oggi!'),
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (hasStreak) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withAlpha((0.15 * 255).toInt()),
                        borderRadius: BorderRadius.circular(10),
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

        // Menu items
        _buildMenuItem(
          title: context.tr('Dati Utente & Target'),
          subtitle: context.tr('Nome, calorie target e obiettivi macronutrienti'),
          icon: Icons.person_outline_rounded,
          color: const Color(0xFF00FFC2),
          onTap: () => setState(() => _currentSection = ProfileSection.datiUtente),
        ),
        _buildMenuItem(
          title: context.tr('Analisi Settimanale'),
          subtitle: context.tr('Statistiche, medie e rispetto della regola 80/20'),
          icon: Icons.analytics_outlined,
          color: const Color(0xFFFF007F),
          onTap: () => setState(() => _currentSection = ProfileSection.analisiSettimanale),
        ),
        _buildMenuItem(
          title: context.tr('Impostazioni di Tracciamento'),
          subtitle: context.tr('Modalità di tracking (Light/Standard/Custom) e regola 80/20'),
          icon: Icons.track_changes_rounded,
          color: const Color(0xFFFFD700),
          onTap: () => setState(() => _currentSection = ProfileSection.impostazioniTracciamento),
        ),
        _buildMenuItem(
          title: context.tr('Impostazioni AI'),
          subtitle: context.tr('Configura chiave API Gemini e modello IA preferito'),
          icon: Icons.auto_awesome_outlined,
          color: Colors.cyan,
          onTap: () => setState(() => _currentSection = ProfileSection.impostazioniAI),
        ),
        _buildMenuItem(
          title: context.tr('Impostazioni Generali'),
          subtitle: context.tr('Schermata iniziale, limiti, lingua e aspetto visivo'),
          icon: Icons.settings_outlined,
          color: const Color(0xFF00E676),
          onTap: () => setState(() => _currentSection = ProfileSection.impostazioniGenerali),
        ),
        _buildMenuItem(
          title: context.tr('Feedback & Supporto'),
          subtitle: context.tr('Contatta il supporto, lascia feedback o scopri di più'),
          icon: Icons.help_outline_rounded,
          color: Colors.purpleAccent,
          onTap: () => setState(() => _currentSection = ProfileSection.feedbackSupporto),
        ),
      ],
    );
  }

  Widget _buildDatiUtenteSection(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        _Field(label: context.tr('Nome'), controller: _nameController, icon: Icons.person),
        const SizedBox(height: 12),
        _Field(label: context.tr('Calorie obiettivo (kcal)'), controller: _caloriesController, icon: Icons.local_fire_department, numeric: true, suffix: 'kcal'),
        const SizedBox(height: 12),
        _Field(label: context.tr('Proteine (g)'), controller: _proteinsController, icon: Icons.fitness_center, numeric: true, suffix: 'g'),
        if (_trackingMode != 'light') ...[
          const SizedBox(height: 12),
          _Field(label: context.tr('Carboidrati (g)'), controller: _carbsController, icon: Icons.restaurant, numeric: true, suffix: 'g'),
          const SizedBox(height: 12),
          _Field(label: context.tr('Grassi (g)'), controller: _fatsController, icon: Icons.water_drop, numeric: true, suffix: 'g'),
        ],
        if (_trackingMode == 'custom') ...[
          const SizedBox(height: 12),
          _Field(label: context.tr('Fibre (g)'), controller: _fibersController, icon: Icons.grass, numeric: true, suffix: 'g'),
        ],
      ],
    );
  }

  Widget _buildAnalisiSettimanaleSection(BuildContext context, WeeklyStats stats, AppState appState, UserProfileEntity user) {
    final hasData = appState.hasEnoughDataForAverage;
    final compl8020 = stats.trackingPercentage;

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        // 80/20 compliance card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF00FFC2).withValues(alpha: 0.08), const Color(0xFFFF007F).withValues(alpha: 0.04)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr('Rispetto Regola 80/20'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${stats.trackedDays.length}/7 ${context.tr('Giorni Tracciati')}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: compl8020 / 100,
                backgroundColor: Colors.white12,
                color: compl8020 >= 80 ? const Color(0xFF00FFC2) : const Color(0xFFFFD700),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 12),
              Text(
                '${compl8020.toInt()}% di aderenza questa settimana. La regola consiglia l\'80% per sostenibilità (circa 5-6 giorni su 7).',
                style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Averages card
        if (!hasData)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
            child: Row(
              children: [
                const Icon(Icons.hourglass_empty, color: Colors.white38, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr('Dati insufficienti — registra almeno 7 giorni per vedere le medie.'),
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              ],
            ),
          )
        else ...[
          const _SectionTitle(title: 'Medie ultimi 7 giorni (esclusi Cheat Days)'),
          const SizedBox(height: 10),
          _buildAverageRow(context.tr('Calorie Medie'), '${stats.averageCalories.toInt()} / ${user.goalCalories.toInt()} kcal', stats.averageCalories <= user.goalCalories ? const Color(0xFF00FFC2) : const Color(0xFFFF007F)),
          _buildAverageRow(context.tr('Proteine Medie'), '${stats.averageProteins.toInt()} / ${user.goalProteins.toInt()} g', stats.averageProteins >= user.goalProteins ? const Color(0xFF00FFC2) : const Color(0xFFFFD700)),
          if (user.trackingMode != 'light') ...[
            _buildAverageRow(context.tr('Carboidrati Medi'), '${stats.averageCarbs.toInt()} / ${user.goalCarbs.toInt()} g', const Color(0xFFFFD700)),
            _buildAverageRow(context.tr('Grassi Medi'), '${stats.averageFats.toInt()} / ${user.goalFats.toInt()} g', const Color(0xFF00E676)),
          ],
          if (user.trackingMode == 'custom') ...[
            _buildAverageRow(context.tr('Fibre Medie'), '${stats.averageFibers.toInt()} / ${user.goalFibers.toInt()} g', Colors.cyan),
          ],
        ],

        const SizedBox(height: 20),
        const _SectionTitle(title: 'Dettaglio Giornaliero Settimana'),
        const SizedBox(height: 10),
        // Day-by-day detail
        ...stats.days.map((day) {
          final String dayName = _getFormattedDayName(day.date);
          final String trackingLabel = day.isTracked ? context.tr('Tracciato') : context.tr('Cheat/Libero');
          final Color badgeColor = day.isTracked ? const Color(0xFF00FFC2) : const Color(0xFFFF007F);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.01),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dayName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${day.dailyCalories.toInt()} kcal · P:${day.dailyProteins.toInt()}g | C:${day.dailyCarbs.toInt()}g | G:${day.dailyFats.toInt()}g',
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.2), width: 0.8),
                  ),
                  child: Text(
                    trackingLabel,
                    style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAverageRow(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  String _getFormattedDayName(DateTime date) {
    final weekday = date.weekday;
    final formattedDate = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
    switch (weekday) {
      case 1:
        return 'Lunedì ($formattedDate)';
      case 2:
        return 'Martedì ($formattedDate)';
      case 3:
        return 'Mercoledì ($formattedDate)';
      case 4:
        return 'Giovedì ($formattedDate)';
      case 5:
        return 'Venerdì ($formattedDate)';
      case 6:
        return 'Sabato ($formattedDate)';
      case 7:
      default:
        return 'Domenica ($formattedDate)';
    }
  }

  Widget _buildImpostazioniTracciamentoSection(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        const _SectionTitle(title: 'Modalita\' di Tracciamento'),
        const SizedBox(height: 10),
        Row(
          children: [
            _ModeChip(label: 'Light', value: 'light', selected: _trackingMode, onTap: (v) => setState(() { _trackingMode = v; _checkIfDirty(); })),
            const SizedBox(width: 8),
            _ModeChip(label: 'Standard', value: 'standard', selected: _trackingMode, onTap: (v) => setState(() { _trackingMode = v; _checkIfDirty(); })),
            const SizedBox(width: 8),
            _ModeChip(label: 'Custom', value: 'custom', selected: _trackingMode, onTap: (v) => setState(() { _trackingMode = v; _checkIfDirty(); })),
          ],
        ),
        const SizedBox(height: 24),
        const _SectionTitle(title: 'Regola 80/20'),
        const SizedBox(height: 10),
        _ToggleCard(
          title: context.tr('Abilita modalita\' 80/20'),
          subtitle: context.tr('I giorni non tracciati vengono escluse dalle medie settimanali.'),
          value: _use8020Mode,
          onChanged: (v) => setState(() { _use8020Mode = v; _checkIfDirty(); }),
        ),
      ],
    );
  }

  Widget _buildImpostazioniAISection(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00FFC2))),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.tr('Salvata solo sul dispositivo. Usata per le funzioni AI.'),
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        const SizedBox(height: 24),
        const _SectionTitle(title: 'Modello IA Selezionato'),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _selectedModel,
          style: const TextStyle(color: Colors.white),
          dropdownColor: const Color(0xFF1C1C24),
          isExpanded: true,
          decoration: InputDecoration(
            labelText: context.tr('Seleziona Modello IA'),
            labelStyle: const TextStyle(color: Colors.white54),
            prefixIcon: const Icon(Icons.settings_suggest, color: Color(0xFF00FFC2)),
            filled: true,
            fillColor: const Color(0xFF1C1C24),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00FFC2))),
          ),
          items: const [
            DropdownMenuItem(value: 'gemma-4-26b-a4b-it', child: Text('Gemma 4 26B (Mixture-of-Experts) - Consigliato')),
            DropdownMenuItem(value: 'gemma-4-31b-it', child: Text('Gemma 4 31B (Dense)')),
            DropdownMenuItem(value: 'gemini-3.5-flash', child: Text('Gemini 3.5 Flash')),
            DropdownMenuItem(value: 'gemini-3-flash', child: Text('Gemini 3 Flash')),
            DropdownMenuItem(value: 'gemini-3.1-flash-lite', child: Text('Gemini 3.1 Flash Lite')),
            DropdownMenuItem(value: 'gemini-2.5-flash', child: Text('Gemini 2.5 Flash')),
            DropdownMenuItem(value: 'gemini-2.5-flash-lite', child: Text('Gemini 2.5 Flash Lite')),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() { _selectedModel = val; });
              _checkIfDirty();
            }
          },
        ),
      ],
    );
  }

  Widget _buildImpostazioniGeneraliSection(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        const _SectionTitle(title: 'Schermata di Avvio'),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _startupScreen,
          style: const TextStyle(color: Colors.white),
          dropdownColor: const Color(0xFF1C1C24),
          isExpanded: true,
          decoration: InputDecoration(
            labelText: context.tr('Schermata iniziale'),
            labelStyle: const TextStyle(color: Colors.white54),
            prefixIcon: const Icon(Icons.launch, color: Color(0xFF00FFC2)),
            filled: true,
            fillColor: const Color(0xFF1C1C24),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00FFC2))),
          ),
          items: [
            DropdownMenuItem(value: 'home', child: Text('Dashboard (${context.tr('Home')})')),
            DropdownMenuItem(value: 'alimenti', child: Text(context.tr('Alimenti'))),
            DropdownMenuItem(value: 'pasto_ia', child: Text(context.tr('Pasto IA'))),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() { _startupScreen = val; });
              _checkIfDirty();
            }
          },
        ),
        const SizedBox(height: 16),
        if (_startupScreen == 'alimenti') ...[
          const _SectionTitle(title: 'Scheda Alimenti Predefinita'),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            initialValue: _defaultAlimentiTab,
            style: const TextStyle(color: Colors.white),
            dropdownColor: const Color(0xFF1C1C24),
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.tr('Scheda iniziale alimenti'),
              labelStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.tab, color: Color(0xFF00FFC2)),
              filled: true,
              fillColor: const Color(0xFF1C1C24),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00FFC2))),
            ),
            items: [
              DropdownMenuItem(value: 0, child: Text(context.tr('Salvati'))),
              DropdownMenuItem(value: 1, child: Text(context.tr('Web (Ricerca)'))),
              DropdownMenuItem(value: 2, child: Text(context.tr('Nuovo (Inserimento)'))),
              DropdownMenuItem(value: 3, child: Text(context.tr('Cronologia'))),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() { _defaultAlimentiTab = val; });
                _checkIfDirty();
              }
            },
          ),
          const SizedBox(height: 16),
        ],
        const _SectionTitle(title: 'Limite Cronologia Alimenti'),
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(
          initialValue: _historyLimit,
          style: const TextStyle(color: Colors.white),
          dropdownColor: const Color(0xFF1C1C24),
          isExpanded: true,
          decoration: InputDecoration(
            labelText: context.tr('Limite Cronologia'),
            labelStyle: const TextStyle(color: Colors.white54),
            prefixIcon: const Icon(Icons.history, color: Color(0xFF00FFC2)),
            filled: true,
            fillColor: const Color(0xFF1C1C24),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00FFC2))),
          ),
          items: [
            DropdownMenuItem(value: 50, child: Text('50 ${context.tr('elementi')}')),
            DropdownMenuItem(value: 100, child: Text('100 ${context.tr('elementi (Predefinito)')}')),
            DropdownMenuItem(value: 200, child: Text('200 ${context.tr('elementi')}')),
            DropdownMenuItem(value: 500, child: Text('500 ${context.tr('elementi')}')),
            DropdownMenuItem(value: 1000, child: Text('1000 ${context.tr('elementi')}')),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() { _historyLimit = val; });
              _checkIfDirty();
            }
          },
        ),
        const SizedBox(height: 24),
        const _SectionTitle(title: 'Lingua'),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _languageCode,
          style: const TextStyle(color: Colors.white),
          dropdownColor: const Color(0xFF1C1C24),
          decoration: InputDecoration(
            labelText: context.tr('Seleziona Lingua'),
            labelStyle: const TextStyle(color: Colors.white54),
            prefixIcon: const Icon(Icons.language, color: Color(0xFF00FFC2)),
            filled: true,
            fillColor: const Color(0xFF1C1C24),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00FFC2))),
          ),
          items: const [
            DropdownMenuItem(value: 'en', child: Text('English (EN)')),
            DropdownMenuItem(value: 'it', child: Text('Italiano (IT)')),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() { _languageCode = val; });
              _checkIfDirty();
            }
          },
        ),
        const SizedBox(height: 24),
        const _SectionTitle(title: 'Aspetto'),
        const SizedBox(height: 10),
        Builder(builder: (ctx) {
          final themeProvider = ctx.watch<ThemeProvider>();
          return Container(
            decoration: BoxDecoration(
              color: ctx.bgCardAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ctx.borderColor),
            ),
            child: SwitchListTile(
              value: themeProvider.isDarkMode,
              onChanged: (isDark) => themeProvider.toggleTheme(isDark),
              activeThumbColor: ctx.accentCyan,
              inactiveThumbColor: ctx.accentCyan,
              inactiveTrackColor: ctx.accentCyan.withValues(alpha: 0.3),
              secondary: Icon(
                themeProvider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: ctx.accentCyan,
              ),
              title: Text(
                themeProvider.isDarkMode ? ctx.tr('Modalità Scura') : ctx.tr('Modalità Chiara'),
                style: TextStyle(color: ctx.textPrimary, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                ctx.tr('Cambia il tema visivo dell\'app'),
                style: TextStyle(color: ctx.textMuted, fontSize: 12),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFeedbackSupportoSection(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        const _SectionTitle(title: 'Feedback & Supporto'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.bgCardAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Hai suggerimenti o hai riscontrato un problema? Contattami a:'),
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(Icons.email_outlined, color: Color(0xFF00FFC2), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'robsfalc+nutria@gmail.com',
                    style: TextStyle(
                      color: Color(0xFF00FFC2),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
        onTap: onTap,
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
        style: TextStyle(
          color: context.textPrimary,
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
            color: isOn
                ? context.accentCyan.withAlpha((0.15 * 255).toInt())
                : context.bgCardAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isOn ? context.accentCyan : context.borderColor,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isOn ? context.accentCyan : context.textMuted,
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
      style: TextStyle(color: context.textPrimary),
      validator: (v) {
        if (v == null || v.trim().isEmpty) {
          return null;
        }
        if (numeric && double.tryParse(v) == null) {
          return 'Inserisci un numero valido';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.textMuted),
        prefixIcon: Icon(icon, color: context.accentCyan, size: 20),
        suffixText: suffix,
        suffixStyle: TextStyle(color: context.textMuted),
        filled: true,
        fillColor: context.bgCardAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.accentCyan),
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
        color: context.bgCardAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: context.accentCyan,
        title: Text(title, style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(color: context.textMuted, fontSize: 12)),
      ),
    );
  }
}
