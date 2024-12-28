// lib/providers/product_provider.dart

import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../services/api_service.dart';

class ProductProvider extends ChangeNotifier {
  List<Product> products = [];
  List<Map<String, dynamic>> categories = [];
  bool isLoading = false;

  ProductProvider();

  /// Načtení kategorií
  Future<void> fetchCategories() async {
    isLoading = true;
    notifyListeners();

    try {
      categories = await ApiService.fetchCategories();
    } catch (e) {
      print('Error while loading (category): $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Načtení produktů
  Future<void> fetchProducts() async {
    isLoading = true;
    notifyListeners();

    try {
      products = await ApiService.fetchProducts();
    } catch (e) {
      print('Error while loading (product): $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Přidání nového produktu
  Future<void> addProduct(Product product) async {
    try {
      await ApiService.addProduct(product);
      await fetchProducts();
      notifyListeners();
    } catch (e) {
      print('Error while adding: $e');
    }
  }

  /// Úprava existujícího produktu
  Future<void> editProduct(Product product) async {
    try {
      await ApiService.editProduct(product);
      await fetchProducts();
      notifyListeners();
    } catch (e) {
      print('Error while editing: $e');
    }
  }

  /// Smazání produktu
  Future<void> deleteProduct(String productId) async {
    try {
      await ApiService.deleteProduct(productId);
      notifyListeners();
      await fetchProducts();
    } catch (e) {
      print('Error while deleting: $e');
    }
  }

  /// Metoda pro zajištění načtení kategorií
  Future<void> ensureCategoriesLoaded() async {
    if (categories.isEmpty) {
      await fetchCategories();
    }
  }

  /// Metoda pro získání produktu podle názvu
  Product? getProductByName(String productName) {
    try {
      return products.firstWhere(
        (product) =>
            product.itemName.toLowerCase() == productName.toLowerCase(),
      );
    } catch (e) {
      print('Product "$productName" not found.');
      return null;
    }
  }
}
