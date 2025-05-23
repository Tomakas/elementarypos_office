// lib/models/purchase_model.dart
import 'package:elementarypos_office/models/ui_purchase_item_model.dart';

class Purchase {
  final String id; // Unikátní ID pro nákup
  final String? supplier;
  final DateTime purchaseDate;
  final String? purchaseNumber;
  final String? notes;
  final List<UIPurchaseItem> items;
  final double overallTotalPrice;

  Purchase({
    required this.id,
    this.supplier,
    required this.purchaseDate,
    this.purchaseNumber,
    this.notes,
    required this.items,
    required this.overallTotalPrice,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'supplier': supplier,
      'purchaseDate': purchaseDate.toIso8601String(), // Uložíme jako ISO string
      'purchaseNumber': purchaseNumber,
      'notes': notes,
      'items': items.map((item) => item.toJson()).toList(),
      'overallTotalPrice': overallTotalPrice,
    };
  }

  factory Purchase.fromJson(Map<String, dynamic> json) {
    var itemsList = json['items'] as List;
    List<UIPurchaseItem> parsedItems = itemsList
        .map((itemJson) => UIPurchaseItem.fromJson(itemJson as Map<String, dynamic>))
        .toList();

    return Purchase(
      id: json['id'] as String,
      supplier: json['supplier'] as String?,
      purchaseDate: DateTime.parse(json['purchaseDate'] as String), // Načteme z ISO stringu
      purchaseNumber: json['purchaseNumber'] as String?,
      notes: json['notes'] as String?,
      items: parsedItems,
      overallTotalPrice: (json['overallTotalPrice'] as num).toDouble(),
    );
  }
}