import 'package:flutter/foundation.dart';

class CartService {
  // Singleton Pattern (One cart instance for the whole app)
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  // The List of Items in the Cart
  final List<Map<String, dynamic>> _items = [];

  List<Map<String, dynamic>> get items => _items;

  // Add Item to Cart
  void addToCart(Map<String, dynamic> crop, double qty, double total) {
    _items.add({
      'crop_id': crop['id'],
      'name': crop['name'], // Ensures we use the new column name
      'image_url': crop['image_url'],
      'farmer_id': crop['farmer_id'],
      'price_per_unit': crop['price'],
      'quantity_kg': qty, // Matches 'orders' table schema
      'total_price': total, // Matches 'orders' table schema (price_offered)
    });
  }

  // Remove Item
  void removeFromCart(int index) {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);
    }
  }

  // Clear Cart (After successful order)
  void clearCart() {
    _items.clear();
  }

  // Calculate Grand Total
  double get grandTotal {
    return _items.fold(
        0.0, (sum, item) => sum + (item['total_price'] as num).toDouble());
  }
}
