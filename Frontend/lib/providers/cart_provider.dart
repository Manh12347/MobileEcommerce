import 'package:flutter/material.dart';

import '../models/cart.dart';
import '../services/api_service.dart';

class CartProvider extends ChangeNotifier {
  Cart? _cart;
  bool _isLoading = false;
  String _errorMessage = '';

  Cart? get cart => _cart;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  int get itemCount => _cart?.totalItems ?? 0;

  Future<void> loadCart({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = '';
      notifyListeners();
    }

    try {
      final response = await ApiService.getCart();
      if (response.success && response.data != null) {
        _cart = response.data;
        _errorMessage = '';
      } else {
        _errorMessage = response.message.isNotEmpty
            ? response.message
            : 'Không tải được giỏ hàng';
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addToCart({
    required int productItemId,
    required int quantity,
  }) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final response = await ApiService.addCartItem(
        productItemId: productItemId,
        quantity: quantity,
      );
      if (response.success && response.data != null) {
        _cart = response.data;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = response.message.isNotEmpty
          ? response.message
          : 'Không thêm được vào giỏ';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateQuantity({
    required int cartItemId,
    required int quantity,
  }) async {
    if (quantity < 1) {
      return removeItem(cartItemId);
    }

    try {
      final response = await ApiService.updateCartItem(
        cartItemId: cartItemId,
        quantity: quantity,
      );
      if (response.success && response.data != null) {
        _cart = response.data;
        notifyListeners();
        return true;
      }
      _errorMessage = response.message.isNotEmpty
          ? response.message
          : 'Cập nhật thất bại';
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeItem(int cartItemId) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final response = await ApiService.removeCartItem(cartItemId);
      if (response.success) {
        if (response.data != null) {
          _cart = response.data;
        } else {
          await loadCart(silent: true);
        }
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = response.message.isNotEmpty ? response.message : 'Xóa thất bại';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearLocal() {
    _cart = null;
    _errorMessage = '';
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage.isEmpty) return;
    _errorMessage = '';
    notifyListeners();
  }
}
