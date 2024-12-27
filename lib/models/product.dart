import 'package:flutter/material.dart';

class Product {
  final String itemId;
  final int code;
  final String itemName;
  final String taxId;
  final double price;
  final String currency;
  final int color;
  final String? sku;
  final String categoryId;
  final String categoryName;
  final String? note;
  final bool onSale;

  Product({
    required this.itemId,
    required this.code,
    required this.itemName,
    required this.taxId,
    required this.price,
    required this.currency,
    required this.color,
    this.sku,
    required this.categoryId,
    required this.categoryName,
    this.note,
    required this.onSale,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      itemId: json['itemId'] ?? '',
      code: json['code'] ?? 0,
      itemName: json['itemName'] ?? 'Neznámý produkt',
      taxId: json['taxId'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'CZK',
      color: json['color'] ?? 1,
      sku: json['sku'],
      categoryId: json['categoryId'] ?? '',
      categoryName: json['categoryName'] ?? 'Neznámá kategorie',
      note: json['note'],
      onSale: json['onSale'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'code': code,
      'itemName': itemName,
      'taxId': taxId,
      'price': price,
      'currency': currency,
      'color': color,
      'sku': sku,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'note': note,
      'onSale': onSale,
    };
  }
}

// Mapa barev pro čísla barev
const Map<int, Color> productColors = {
  1: Colors.green,           // Barva 1: zelená
  2: Colors.lightBlue,       // Barva 2: světle modrá
  3: Colors.blue,            // Barva 3: tmavě modrá
  4: Colors.yellow,          // Barva 4: žlutá
  5: Colors.orange,          // Barva 5: oranžová
  6: Colors.purple,          // Barva 6: fialová
  7: Colors.red,             // Barva 7: červená
  8: Color(0xFF8B4513),      // Barva 8: světle hnědá
};
