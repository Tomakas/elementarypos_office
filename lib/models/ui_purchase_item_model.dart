// lib/models/ui_purchase_item_model.dart

class UIPurchaseItem {
  String id;
  String productId; // Nové pole pro ID produktu
  String productName;
  double quantity;
  double? unitPrice;
  double? totalItemPrice;

  UIPurchaseItem({
    required this.id,
    required this.productId, // Přidáno do konstruktoru
    this.productName = '',
    this.quantity = 1.0,
    this.unitPrice,
    this.totalItemPrice,
  });

  void calculatePrices() {
    if (quantity == 0) {
      if(unitPrice != null) totalItemPrice = 0;
      if(totalItemPrice != null) unitPrice = 0;
      return;
    }
    if (unitPrice != null) {
      totalItemPrice = quantity * unitPrice!;
    } else if (totalItemPrice != null && quantity > 0) { // Přidána kontrola quantity > 0
      unitPrice = totalItemPrice! / quantity;
    } else if (totalItemPrice != null && quantity == 0) {
      unitPrice = 0;
    }
  }

  // Metoda pro převod instance na JSON mapu
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId, // Přidáno do JSON serializace
      'productName': productName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalItemPrice': totalItemPrice,
    };
  }

  // Factory konstruktor pro vytvoření instance z JSON mapy
  factory UIPurchaseItem.fromJson(Map<String, dynamic> json) {
    return UIPurchaseItem(
      id: json['id'] as String,
      productId: json['productId'] as String, // Přidáno do JSON deserializace
      productName: json['productName'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unitPrice'] as num?)?.toDouble(),
      totalItemPrice: (json['totalItemPrice'] as num?)?.toDouble(),
    );
  }
}