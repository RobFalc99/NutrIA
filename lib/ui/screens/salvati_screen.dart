import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../providers/app_state.dart';
import '../../providers/theme_provider.dart';
import 'recipe_builder_screen.dart';

class SalvatiScreen extends StatefulWidget {
  final bool isActive;
  const SalvatiScreen({super.key, this.isActive = true});

  @override
  State<SalvatiScreen> createState() => _SalvatiScreenState();
}

class _SalvatiScreenState extends State<SalvatiScreen> {
  static const accentCyan = Color(0xFF00FFC2);
  static const accentPink = Color(0xFFFF007F);
  static const accentYellow = Color(0xFFFFD700);
  static const bgCard = Color(0xFF16161D);

  final _searchController = TextEditingController();
  int _filterIndex = 0; // 0: Tutti, 1: Ricette, 2: Alimenti singoli

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final customFoods = appState.customFoods;
    final query = _searchController.text.trim().toLowerCase();

    var filtered = customFoods.where((food) {
      if (query.isNotEmpty && !food.name.toLowerCase().contains(query)) {
        return false;
      }
      if (_filterIndex == 1 && !food.isRecipe) return false;
      if (_filterIndex == 2 && food.isRecipe) return false;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: context.bgPrimary,
      appBar: AppBar(
        title: const Text(
          'Salvati',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tasto rapido Crea Ricetta con IA
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RecipeBuilderScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentPink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.soup_kitchen_rounded, size: 20),
                label: const Text(
                  'Crea Ricetta con IA 🍲',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),

              // Barra di Ricerca
              TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Cerca tra alimenti e ricette salvate...',
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.03),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 10),

              // Filter Chips
              Row(
                children: [
                  _buildFilterChip('Tutti (${customFoods.length})', 0),
                  const SizedBox(width: 8),
                  _buildFilterChip('Ricette (${customFoods.where((f) => f.isRecipe).length})', 1),
                  const SizedBox(width: 8),
                  _buildFilterChip('Cibi Singoli (${customFoods.where((f) => !f.isRecipe).length})', 2),
                ],
              ),
              const SizedBox(height: 12),

              // Lista elementi salvati
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bookmark_border_rounded, size: 48, color: Colors.white.withValues(alpha: 0.1)),
                            const SizedBox(height: 10),
                            Text(
                              customFoods.isEmpty
                                  ? 'Nessun alimento o ricetta personale salvata.\nAggiungili dalla sezione "Nuovo" per trovarli qui.'
                                  : 'Nessun risultato trovato per la ricerca.',
                              style: const TextStyle(color: Colors.white38, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final food = filtered[index];
                          return _buildFoodCard(context, appState, food);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final isSelected = _filterIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _filterIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? accentCyan.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? accentCyan : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? accentCyan : Colors.white60,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildFoodCard(BuildContext context, AppState appState, Food food) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: food.isRecipe ? accentPink.withValues(alpha: 0.12) : accentCyan.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            food.isRecipe ? Icons.soup_kitchen_rounded : Icons.bookmark_rounded,
            color: food.isRecipe ? accentPink : accentCyan,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                food.name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (food.isRecipe) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accentPink.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: accentPink.withValues(alpha: 0.3)),
                ),
                child: const Text('RICETTA', style: TextStyle(color: accentPink, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
            if (food.customServingGrams != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accentYellow.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: accentYellow.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${food.customServingGrams!.toInt()}g',
                  style: const TextStyle(color: accentYellow, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          '${food.caloriesPer100g.toStringAsFixed(0)} kcal/100g • P:${food.proteinsPer100g.toStringAsFixed(1)}g C:${food.carbsPer100g.toStringAsFixed(1)}g F:${food.fatsPer100g.toStringAsFixed(1)}g Fib:${food.fibersPer100g.toStringAsFixed(1)}g',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tasto Modifica
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.white60, size: 18),
              onPressed: () {
                if (food.isRecipe) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecipeBuilderScreen(initialRecipe: food),
                    ),
                  );
                } else {
                  _showEditFoodDialog(context, appState, food);
                }
              },
            ),
            // Tasto Elimina
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white30, size: 18),
              onPressed: () => _confirmDeleteFood(context, appState, food),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteFood(BuildContext context, AppState appState, Food food) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bgCard,
        title: Text(food.isRecipe ? 'Elimina Ricetta' : 'Elimina Alimento', style: const TextStyle(color: Colors.white)),
        content: Text('Sei sicuro di voler eliminare "${food.name}" dai tuoi salvati?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () {
              appState.deleteCustomFood(food.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('"${food.name}" rimosso.'), backgroundColor: accentPink),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: accentPink),
            child: const Text('Elimina', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditFoodDialog(BuildContext context, AppState appState, Food food) {
    final nomeController = TextEditingController(text: food.name);
    final marcaController = TextEditingController(text: food.brand ?? '');
    final kcalController = TextEditingController(text: food.caloriesPer100g.toStringAsFixed(1));
    final protController = TextEditingController(text: food.proteinsPer100g.toStringAsFixed(1));
    final carbController = TextEditingController(text: food.carbsPer100g.toStringAsFixed(1));
    final fatController = TextEditingController(text: food.fatsPer100g.toStringAsFixed(1));
    final fibController = TextEditingController(text: food.fibersPer100g.toStringAsFixed(1));
    final servController = TextEditingController(text: food.customServingGrams?.toInt().toString() ?? '100');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Modifica Alimento', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _dialogInputDeco('Nome alimento'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: marcaController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _dialogInputDeco('Marca (opzionale)'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: kcalController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: _dialogInputDeco('Kcal/100g'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: protController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: _dialogInputDeco('Prot/100g'))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: carbController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: _dialogInputDeco('Carb/100g'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: fatController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: _dialogInputDeco('Grassi/100g'))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: fibController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: _dialogInputDeco('Fibre/100g'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: servController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: _dialogInputDeco('Porzione (g)'))),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () {
              final updated = food.copyWith(
                name: nomeController.text.trim(),
                brand: marcaController.text.trim().isEmpty ? null : marcaController.text.trim(),
                caloriesPer100g: double.tryParse(kcalController.text) ?? food.caloriesPer100g,
                proteinsPer100g: double.tryParse(protController.text) ?? food.proteinsPer100g,
                carbsPer100g: double.tryParse(carbController.text) ?? food.carbsPer100g,
                fatsPer100g: double.tryParse(fatController.text) ?? food.fatsPer100g,
                fibersPer100g: double.tryParse(fibController.text) ?? food.fibersPer100g,
                customServingGrams: double.tryParse(servController.text),
              );
              appState.saveCustomFood(updated);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('"${updated.name}" modificato con successo!'), backgroundColor: accentCyan),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: accentCyan),
            child: const Text('Salva Modifiche', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  InputDecoration _dialogInputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    );
  }
}
