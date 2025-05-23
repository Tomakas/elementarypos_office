// lib/providers/purchase_provider.dart
import 'package:flutter/material.dart';
import '../models/purchase_model.dart';
import '../services/purchase_storage_service.dart';

class PurchaseProvider extends ChangeNotifier {
  final PurchaseStorageService _storageService = PurchaseStorageService();
  List<Purchase> _purchases = [];
  bool _isLoading = false;

  List<Purchase> get purchases => _purchases;
  bool get isLoading => _isLoading;

  PurchaseProvider() {
    loadPurchases();
  }

  Future<void> loadPurchases() async {
    _isLoading = true;
    notifyListeners();
    _purchases = await _storageService.loadPurchases();
    _isLoading = false;
    notifyListeners();
    print('PurchaseProvider: Nákupy načteny, počet: ${_purchases.length}');
  }

  Future<void> addPurchase(Purchase purchase) async {
    _isLoading = true; // Může být krátké, ale pro konzistenci
    notifyListeners();
    _purchases.add(purchase);
    // Seřadit nákupy od nejnovějšího po nejstarší
    _purchases.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
    await _storageService.savePurchases(_purchases);
    _isLoading = false;
    notifyListeners();
    print('PurchaseProvider: Nákup přidán a uložen. Celkem: ${_purchases.length}');
  }

  Future<void> updatePurchase(Purchase updatedPurchase) async {
    _isLoading = true;
    notifyListeners();
    final index = _purchases.indexWhere((p) => p.id == updatedPurchase.id);
    if (index != -1) {
      _purchases[index] = updatedPurchase;
      _purchases.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
      await _storageService.savePurchases(_purchases);
      print('PurchaseProvider: Nákup s ID ${updatedPurchase.id} aktualizován.');
    } else {
      print('PurchaseProvider: Nákup s ID ${updatedPurchase.id} pro aktualizaci nenalezen.');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> deletePurchase(String purchaseId) async {
    _isLoading = true;
    notifyListeners();
    _purchases.removeWhere((p) => p.id == purchaseId);
    await _storageService.savePurchases(_purchases);
    print('PurchaseProvider: Nákup s ID $purchaseId smazán.');
    _isLoading = false;
    notifyListeners();
  }

  Purchase? getPurchaseById(String purchaseId) {
    try {
      return _purchases.firstWhere((p) => p.id == purchaseId);
    } catch (e) {
      return null;
    }
  }
}