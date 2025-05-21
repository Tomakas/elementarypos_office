// lib/models/ui_purchase_item_model.dart

class UIPurchaseItem {
  String id; // Unikátní ID pro UI účely (např. UUID)
  String productName; // Nebo reference na plnohodnotný produkt
  double quantity;
  double? unitPrice;
  double? totalItemPrice;
  // Controllery pro textová pole, aby se zachoval stav při rebuild
  // Tyto by se měly inicializovat a dispose-ovat ve StatefulWidgetu, který je používá

  UIPurchaseItem({
    required this.id,
    this.productName = '',
    this.quantity = 1.0,
    this.unitPrice,
    this.totalItemPrice,
  });

  // Metoda pro výpočet chybějící ceny
  void calculatePrices() {
    if (quantity == 0) {
      if(unitPrice != null) totalItemPrice = 0;
      if(totalItemPrice != null) unitPrice = 0;
      return;
    }
    if (unitPrice != null) {
      totalItemPrice = quantity * unitPrice!;
    } else if (totalItemPrice != null) {
      unitPrice = totalItemPrice! / quantity;
    }
  }
}