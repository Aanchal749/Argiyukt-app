import 'package:flutter/foundation.dart';

class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  final List<Map<String, dynamic>> _items = [];

  List<Map<String, dynamic>> get items => _items;

  // ✅ This matches the 3 arguments required by your Buyer Screen
  void addToCart(Map<String, dynamic> crop, double qty, double totalPrice) {
    _items.add({
      'crop': crop,
      'quantity': qty,
      'total_price': totalPrice,
    });
    notifyListeners();
  }

  void removeFromCart(int index) {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);
      notifyListeners();
    }
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}
