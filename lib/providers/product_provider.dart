// lib/providers/product_provider.dart

import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../services/api_service.dart';
import '../services/utility_services.dart';
// Import StorageService

class ProductProvider extends ChangeNotifier {
  List<Product> products = [];
  List<Map<String, dynamic>> categories = [];
  Map<String, double> stockData = {};
  bool isLoading = false;

  // Mapa pro lokálně uložené nákupní ceny produktů (productId -> purchasePrice)
  Map<String, double?> _productStoredPurchasePrices = {};

  ProductProvider() {
    // Odstraněno volání fetchAllProductData odsud, bude se volat z initState obrazovek
    // nebo tam, kde je to explicitně potřeba.
    // Načtení uložených nákupních cen můžeme také nechat na fetchAllProductData
    // nebo zavolat samostatně, pokud je to potřeba dříve.
  }

  /// Načtení lokálně uložených nákupních cen produktů
  Future<void> _loadStoredProductPurchasePrices() async {
    _productStoredPurchasePrices = await StorageService.loadProductPurchasePrices();
    // Není potřeba zde volat notifyListeners(), pokud je to součást větší operace
    // jako fetchAllProductData, která zavolá notifyListeners() na konci.
    // Cyklus pro aktualizaci produktů byl odstraněn, protože produkty
    // budou aktuálně načteny z API a poté sloučeny v _mergeProductsWithStoredPurchasePrices.
    print('Loaded stored product purchase prices: ${_productStoredPurchasePrices.length} items.');
  }

  /// Uložení aktuální mapy nákupních cen produktů
  Future<void> _saveStoredProductPurchasePrices() async {
    await StorageService.saveProductPurchasePrices(_productStoredPurchasePrices);
  }

  /// Aktualizace a uložení nákupní ceny pro konkrétní produkt
  Future<void> updateStoredProductPurchasePrice(String productId, double? newPrice) async {
    _productStoredPurchasePrices[productId] = newPrice;
    // Najdeme produkt v seznamu `products` a aktualizujeme jeho `purchasePrice`
    final productIndex = products.indexWhere((p) => p.itemId == productId);
    if (productIndex != -1) {
      final currentProduct = products[productIndex];
      // Vytvoření nové instance produktu s aktualizovanou cenou
      // Toto je důležité, pokud widgety porovnávají instance objektů.
      products[productIndex] = Product(
        itemId: currentProduct.itemId,
        code: currentProduct.code,
        itemName: currentProduct.itemName,
        taxId: currentProduct.taxId,
        sellingPrice: currentProduct.sellingPrice,
        purchasePrice: newPrice, // Aktualizovaná nákupní cena
        currency: currentProduct.currency,
        color: currentProduct.color,
        sku: currentProduct.sku,
        categoryId: currentProduct.categoryId,
        categoryName: currentProduct.categoryName,
        note: currentProduct.note,
        onSale: currentProduct.onSale,
      );
    }
    await _saveStoredProductPurchasePrices();
    notifyListeners();
    print('Stored purchase price for product $productId updated to $newPrice and saved.');
  }

  /// Získání uložené nákupní ceny pro produkt
  double? getStoredPurchasePrice(String productId) {
    return _productStoredPurchasePrices[productId];
  }

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
      // Po načtení produktů z API, sloučíme s lokálně uloženými nákupními cenami
      await _mergeProductsWithStoredPurchasePrices();
    } catch (e) {
      print('Error while loading (product): $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Sloučení načtených produktů s lokálně uloženými nákupními cenami
  Future<void> _mergeProductsWithStoredPurchasePrices() async {
    // Ujistíme se, že lokální ceny jsou načteny
    if (_productStoredPurchasePrices.isEmpty) {
      await _loadStoredProductPurchasePrices(); // Načte, pokud ještě nebyly
    }

    if (products.isNotEmpty) {
      for (var i = 0; i < products.length; i++) {
        final product = products[i];
        if (_productStoredPurchasePrices.containsKey(product.itemId)) {
          // Pokud má produkt v API `purchasePrice` null nebo 0, a my máme lokální, použijeme lokální.
          // Nebo pokud chceme, aby lokální cena měla vždy přednost:
          final storedPrice = _productStoredPurchasePrices[product.itemId];
          if (storedPrice != null ) { // Pouze pokud je lokální cena nastavena
            products[i] = Product(
              itemId: product.itemId,
              code: product.code,
              itemName: product.itemName,
              taxId: product.taxId,
              sellingPrice: product.sellingPrice,
              purchasePrice: storedPrice, // Aktualizujeme na uloženou cenu
              currency: product.currency,
              color: product.color,
              sku: product.sku,
              categoryId: product.categoryId,
              categoryName: product.categoryName,
              note: product.note,
              onSale: product.onSale,
            );
          }
        }
      }
    }
  }


  /// Přidání nového produktu
  Future<void> addProduct(Product product) async {
    try {
      // API volání pro přidání produktu
      await ApiService.addProduct(product);
      // Po úspěšném přidání do API, znovu načteme všechny produkty,
      // což zahrne i nově přidaný a zavolá _mergeProductsWithStoredPurchasePrices.
      await fetchProducts();
      // Pokud má nově přidaný produkt nastavenou purchasePrice, uložíme ji i lokálně
      if (product.purchasePrice != null) {
        // Potřebujeme itemId nově přidaného produktu z API odpovědi, pokud API vrací celý objekt.
        // Prozatím předpokládáme, že `product.itemId` je prázdné a API ho negeneruje zpět v této fázi.
        // Pokud bychom chtěli okamžitě uložit NC pro nově přidaný produkt, museli bychom získat jeho ID z API.
        // Jednodušší je, že NC se uloží při prvním nákupu tohoto produktu.
        // Alternativně, pokud by addProduct vracelo ID:
        // String newProductId = await ApiService.addProduct(product);
        // Předpoklad, že vrací ID
        // await updateStoredProductPurchasePrice(newProductId, product.purchasePrice);
      }
      // notifyListeners(); // fetchProducts() již volá notifyListeners()
    } catch (e) {
      print('Error while adding: $e');
      rethrow; // Abychom mohli chybu zpracovat na UI
    }
  }

  /// Úprava existujícího produktu
  Future<void> editProduct(Product product) async {
    try {
      await ApiService.editProduct(product);
      // Po úspěšné úpravě v API, znovu načteme všechny produkty
      await fetchProducts();
      // Aktualizujeme i lokálně uloženou nákupní cenu, pokud byla součástí úpravy
      if (product.purchasePrice != null) {
        await updateStoredProductPurchasePrice(product.itemId, product.purchasePrice);
      } else {
        // Pokud byla NC produktu explicitně odstraněna (nastavena na null při editaci)
        await updateStoredProductPurchasePrice(product.itemId, null);
      }
      // notifyListeners(); // fetchProducts() již volá notifyListeners()
    } catch (e) {
      print('Error while editing: $e');
      rethrow;
    }
  }

  /// Smazání produktu
  Future<void> deleteProduct(String productId) async {
    try {
      await ApiService.deleteProduct(productId);
      // Odstraníme i lokálně uloženou nákupní cenu
      _productStoredPurchasePrices.remove(productId);
      await _saveStoredProductPurchasePrices();
      await fetchProducts(); // Znovu načteme seznam produktů
      // notifyListeners(); // fetchProducts() již volá notifyListeners()
    } catch (e) {
      print('Error while deleting: $e');
      rethrow;
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
      // print('Product "$productName" not found.'); // Může být příliš "ukecané"
      return null;
    }
  }

  /// Metoda pro získání produktu podle ID
  Product? getProductById(String productId) {
    try {
      return products.firstWhere((product) => product.itemId == productId);
    } catch (e) {
      return null;
    }
  }

  /// Metoda pro kompletní načtení produktových dat:
  Future<void> fetchAllProductData() async {
    isLoading = true;
    notifyListeners();

    try {
      // 0) Načíst lokálně uložené NC
      await _loadStoredProductPurchasePrices();
      // 1) Načíst kategorie
      categories = await ApiService.fetchCategories();
      // 2) Načíst produkty z API
      products = await ApiService.fetchProducts();
      // 3) Sloučit produkty z API s lokálně uloženými NC
      await _mergeProductsWithStoredPurchasePrices();
      // 4) Načíst stavy skladu
      final stockList = await ApiService.fetchActualStockData();
      stockData = {
        for (var item in stockList)
          if (item['sku'] != null) item['sku']: (item['quantity'] as num?)?.toDouble() ?? 0.0,
      };
    } catch (e) {
      print('Error while loading all product data: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // Samostatné volání pro stavy skladu (může zůstat pro refresh)
  Future<void> fetchStockData() async {
    isLoading = true;
    notifyListeners();

    try {
      final stockList = await ApiService.fetchActualStockData();
      stockData = {
        for (var item in stockList)
          if (item['sku'] != null) item['sku']: (item['quantity'] as num?)?.toDouble() ?? 0.0,
      };
    } catch (e) {
      print('Error while loading stock data: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}