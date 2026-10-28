import 'dart:math';
import 'package:flutter/material.dart';

class NutriaThinkingQuotes {
  static final List<String> quotes = [
    "Sto calcolando quante calorie bruci solo guardando questa ricetta... poche, purtroppo.",
    "Un momento, sto negoziando con le proteine per farti mettere muscoli.",
    "Analisi in corso: se togliamo il burro piange il piatto, se lo lasciamo piange la bilancia.",
    "Consulto il gran consiglio delle Nutrie Nutrizioniste... dicono che i carboidrati sono vita.",
    "Sto contando i carboidrati uno per uno. Prometto di non mangiarne nessuno nel tragitto.",
    "Calcolo quantistico: 1 fetta di torta = 15 minuti di pura felicità cosmica.",
    "Sto spiegando ai grassi che dovrebbero trasformarsi direttamente in addominali scolpiti.",
    "Controllo se questa ricetta rispetta le antiche leggi della Nutria Gourmet...",
    "Aspetta un secondo, sto resistendo alla tentazione di assaggiare il tuo pasto virtuale.",
    "Masticando numeri e macinando macronutrienti... quasi fatto!",
    "La scienza dice insalata, il cuore dice pizza. Vediamo cosa decide l'algoritmo.",
    "Scomponendo gli atomi di calorie in puro sapore... attendi prego.",
    "Se questa ricetta fosse una canzone, sarebbe un glorioso assolo di carboidrati.",
    "Sto calcolando se puoi fare il bis senza sensi di colpa. Spoiler: assolutamente sì.",
    "Attendi: una nutria sta correndo sulla ruota per alimentare i supercomputer dell'IA.",
    "Bilanciamento macro in corso: più proteine per te, più carote per me.",
    "Sto leggendo il futuro nella farina d'avena... vedo ottimi guadagni muscolari!",
    "Non sono calorie, sono piccoli folletti che stringono i tuoi jeans di notte.",
    "Sto pesando ogni singolo grammo con la precisione di un orologiaio svizzero goloso.",
    "NutrIA al lavoro: trasforma semplici ingredienti in un capolavoro di macros!",
  ];

  static String getRandom() {
    final rand = Random();
    return quotes[rand.nextInt(quotes.length)];
  }
}

class NutriaThinkingView extends StatefulWidget {
  final String? message;
  final VoidCallback? onCancel;

  const NutriaThinkingView({
    super.key,
    this.message,
    this.onCancel,
  });

  @override
  State<NutriaThinkingView> createState() => _NutriaThinkingViewState();
}

class _NutriaThinkingViewState extends State<NutriaThinkingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  late final String _randomQuote;

  static const accentCyan = Color(0xFF00FFC2);
  static const accentPink = Color(0xFFFF007F);
  static const bgDark = Color(0xFF0F0F13);

  @override
  void initState() {
    super.initState();
    _randomQuote = NutriaThinkingQuotes.getRandom();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),

              // Mascotte Nutria con respiro/pulsazione
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentCyan.withValues(alpha: 0.15),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/thinking_clear.png',
                    height: 220,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Titolo animato
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_awesome, color: accentCyan, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    widget.message ?? 'La Nutria sta pensando...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Barra di caricamento elegante
              SizedBox(
                width: 180,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: const LinearProgressIndicator(
                    minHeight: 4,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(accentCyan),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Card Frase Divertente
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  children: [
                    const Text(
                      '🦫 PERLA DEL GIORNO',
                      style: TextStyle(
                        color: accentPink,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '“$_randomQuote”',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13.5,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              if (widget.onCancel != null)
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text(
                    'Annulla',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class NutriaThinkingDialog {
  static void show(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (_) => NutriaThinkingView(message: message),
    );
  }

  static void hide(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }
}
