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
    print('PurchaseProvider: Inicializace, volám loadPurchases...');
    loadPurchases();
  }

  Future<void> loadPurchases() async {
    print('PurchaseProvider: Začátek loadPurchases.');
    _isLoading = true;
    notifyListeners(); // Notifikuj o začátku načítání
    _purchases = await _storageService.loadPurchases();
    _isLoading = false;
    print('PurchaseProvider: Nákupy načteny, počet: ${_purchases.length}. Volám notifyListeners.');
    notifyListeners(); // Notifikuj o dokončení načítání a nových datech
  }

  Future<void> addPurchase(Purchase purchase) async {
    print('PurchaseProvider: Začátek addPurchase pro nákup ID: ${purchase.id}');
    _isLoading = true;
    notifyListeners();

    // Vytvoříme novou instanci seznamu, abychom zajistili, že referenční rovnost se změní
    // a Consumer/Provider.of si toho všimne jistěji.
    final List<Purchase> updatedPurchases = List.from(_purchases);
    updatedPurchases.add(purchase);
    updatedPurchases.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));

    _purchases = updatedPurchases; // Přiřadíme nový seznam

    print('PurchaseProvider: Před uložením, lokální seznam má ${_purchases.length} nákupů.');
    await _storageService.savePurchases(_purchases);
    _isLoading = false;
    print('PurchaseProvider: Nákup přidán a uložen. Volám notifyListeners. Celkem: ${_purchases.length}');
    notifyListeners();
  }

  Future<void> updatePurchase(Purchase updatedPurchase) async {
    print('PurchaseProvider: Začátek updatePurchase pro nákup ID: ${updatedPurchase.id}');
    _isLoading = true;
    notifyListeners();
    final index = _purchases.indexWhere((p) => p.id == updatedPurchase.id);
    if (index != -1) {
      final List<Purchase> updatedPurchases = List.from(_purchases);
      updatedPurchases[index] = updatedPurchase;
      updatedPurchases.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
      _purchases = updatedPurchases;
      await _storageService.savePurchases(_purchases);
      print('PurchaseProvider: Nákup s ID ${updatedPurchase.id} aktualizován.');
    } else {
      print('PurchaseProvider: Nákup s ID ${updatedPurchase.id} pro aktualizaci nenalezen.');
    }
    _isLoading = false;
    print('PurchaseProvider: updatePurchase dokončen. Volám notifyListeners.');
    notifyListeners();
  }

  Future<void> deletePurchase(String purchaseId) async {
    print('PurchaseProvider: Začátek deletePurchase pro nákup ID: $purchaseId');
    _isLoading = true;
    notifyListeners();
    final List<Purchase> updatedPurchases = List.from(_purchases);
    updatedPurchases.removeWhere((p) => p.id == purchaseId);
    _purchases = updatedPurchases;
    await _storageService.savePurchases(_purchases);
    print('PurchaseProvider: Nákup s ID $purchaseId smazán.');
    _isLoading = false;
    print('PurchaseProvider: deletePurchase dokončen. Volám notifyListeners.');
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