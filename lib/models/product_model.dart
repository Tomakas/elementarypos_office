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
      itemName: json['itemName'] ?? 'Unknown product',
      taxId: json['taxId'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'CZK',
      color: json['color'] ?? 1,
      sku: json['sku'],
      categoryId: json['categoryId'] ?? '',
      categoryName: json['categoryName'] ?? 'Unknown category',
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

// Mapa barev produktů
const Map<int, Color> productColors = {
  1: Colors.green,
  2: Colors.lightBlue,
  3: Colors.blue,
  4: Colors.yellow,
  5: Colors.orange,
  6: Colors.purple,
  7: Colors.red,
  8: Color(0xFFCD7537),
};
