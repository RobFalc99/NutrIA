import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../domain/models.dart';

class OpenFoodFactsService {
  static const String _baseUrl = 'https://world.openfoodfacts.org';

  /// Cerca un prodotto tramite codice a barre
  Future<Food?> getProductByBarcode(String barcode) async {
    final url = Uri.parse('$_baseUrl/api/v0/product/$barcode.json');
    final headers = {
      'User-Agent': 'NutrIAApp/1.0.0 (tony@example.com) Flutter/Isar'
    };
    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 1 && data['product'] != null) {
          return _parseProduct(data['product']);
        }
      }
    } catch (e) {
      print('Errore OpenFoodFacts getProductByBarcode: $e');
    }
    return null;
  }

  /// Cerca prodotti tramite testo
  Future<List<Food>> searchProducts(String query) async {
    final searchTerms = query.trim();
    if (searchTerms.isEmpty) return [];

    final headers = {
      'User-Agent': 'NutrIAApp/1.0.0 (tony@example.com) Flutter/Isar',
      'Accept': 'application/json',
    };

    // world.openfoodfacts.org è il server globale centralizzato ed estremamente stabile.
    // Lo interroghiamo come prima scelta per una latenza minima e risposte certe.
    // In caso di errore o timeout di rete, facciamo fallback istantaneo su it.openfoodfacts.org.
    final configs = [
      {'host': 'world.openfoodfacts.org', 'lc': 'it', 'cc': 'it'},
      {'host': 'it.openfoodfacts.org', 'lc': 'it', 'cc': 'it'},
    ];

    for (final config in configs) {
      final host = config['host']!;
      final url = Uri.https(host, '/cgi/search.pl', {
        'search_terms': searchTerms,
        'search_simple': '1',
        'action': 'process',
        'json': '1',
        'page_size': '30',
        'lc': config['lc']!,
        'cc': config['cc']!,
      });

      try {
        final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['products'] != null) {
            final List products = data['products'];
            final List<Food> results = products
                .map((p) => _parseProduct(p))
                .where((food) => food != null)
                .cast<Food>()
                .toList();
            if (results.isNotEmpty) {
              return results;
            }
          }
        }
      } catch (e) {
        print('Errore OpenFoodFacts searchProducts su $host: $e. Tento fallback.');
      }
    }
    return [];
  }

  // Parser ultra-sicuro per prevenire eccezioni da tipi dati misti (int, double, String)
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Food? _parseProduct(Map<String, dynamic> productData) {
    try {
      final nutriments = productData['nutriments'] ?? {};
      
      final double calories = _parseDouble(nutriments['energy-kcal_100g']);
      final double proteins = _parseDouble(nutriments['proteins_100g']);
      final double carbs = _parseDouble(nutriments['carbohydrates_100g']);
      final double fats = _parseDouble(nutriments['fat_100g']);
      final double fibers = _parseDouble(nutriments['fiber_100g']); // Mappato per modalità Custom
      
      final String id = productData['code'] ?? '';
      final String name = productData['product_name'] ?? 'Alimento Sconosciuto';
      final String? brand = productData['brands'];

      return Food(
        id: id,
        name: name,
        brand: brand,
        caloriesPer100g: calories,
        proteinsPer100g: proteins,
        carbsPer100g: carbs,
        fatsPer100g: fats,
        fibersPer100g: fibers,
        isCustom: false,
        isOnline: false,
      );
    } catch (e) {
      print('Errore nel parsing del prodotto OpenFoodFacts: $e');
      return null;
    }
  }
}
