import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../domain/models.dart';

class OpenFoodFactsService {
  static const String _baseUrl = 'https://world.openfoodfacts.org';

  /// Cerca un prodotto tramite codice a barre
  Future<Food?> getProductByBarcode(String barcode) async {
    final url = Uri.parse('$_baseUrl/api/v0/product/$barcode.json');
    try {
      final response = await http.get(url);
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
    final url = Uri.https('world.openfoodfacts.org', '/cgi/search.pl', {
      'search_terms': query,
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'page_size': '20',
    });
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['products'] != null) {
          final List products = data['products'];
          return products
              .map((p) => _parseProduct(p))
              .where((food) => food != null)
              .cast<Food>()
              .toList();
        }
      }
    } catch (e) {
      print('Errore OpenFoodFacts searchProducts: $e');
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
