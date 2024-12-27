// lib/providers/product_provider.dart

import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/utility_services.dart';

class ProductProvider extends ChangeNotifier {
  String apiKey;
  List<Product> products = [];
  List<Map<String, dynamic>> categories = [];
  bool isLoading = false;

  ProductProvider(this.apiKey);

  /// Načtení kategorií
  Future<void> fetchCategories() async {
    isLoading = true;
    notifyListeners();

    try {
      // Dynamické načtení aktuálního API klíče
      apiKey = await StorageService.getApiKey() ?? '';

      categories = await ApiService.fetchCategories(apiKey);
    } catch (e) {
      print('Chyba při načítání kategorií: $e');
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
      // Dynamické načtení aktuálního API klíče
      apiKey = await StorageService.getApiKey() ?? '';

      print('Načítání produktů s API klíčem: $apiKey');
      products = await ApiService.fetchProducts(apiKey);
    } catch (e) {
      print('Chyba při načítání produktů: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Přidání nového produktu
  Future<void> addProduct(Product product) async {
    try {
      // Dynamické načtení aktuálního API klíče
      apiKey = await StorageService.getApiKey() ?? '';

      await ApiService.addProduct(apiKey, product);
      await fetchProducts();
      notifyListeners();
    } catch (e) {
      print('Chyba při přidávání produktu: $e');
    }
  }

  /// Úprava existujícího produktu
  Future<void> editProduct(Product product) async {
    try {
      // Dynamické načtení aktuálního API klíče
      apiKey = await StorageService.getApiKey() ?? '';

      await ApiService.editProduct(apiKey, product);
      await fetchProducts();
      notifyListeners();
    } catch (e) {
      print('Chyba při úpravě produktu: $e');
    }
  }

  /// Smazání produktu
  Future<void> deleteProduct(String productId) async {
    try {
      // Dynamické načtení aktuálního API klíče
      apiKey = await StorageService.getApiKey() ?? '';

      await ApiService.deleteProduct(apiKey, productId);
      notifyListeners();
      await fetchProducts();
    } catch (e) {
      print('Chyba při mazání produktu: $e');
    }
  }

  /// Metoda pro zajištění načtení kategorií (pokud ještě nejsou načtené)
  Future<void> ensureCategoriesLoaded() async {
    if (categories.isEmpty) {
      await fetchCategories();
    }
  }

  /// Metoda pro získání produktu podle názvu
  Product? getProductByName(String productName) {
    try {
      return products.firstWhere(
            (product) => product.itemName.toLowerCase() == productName.toLowerCase(),
      );
    } catch (e) {
      print('Produkt s názvem "$productName" nebyl nalezen.');
      return null;
    }
  }
}
