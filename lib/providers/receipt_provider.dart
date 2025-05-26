// lib/providers/receipt_provider.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../providers/product_provider.dart'; // Potřebné pro getTopCategories

class ReceiptProvider extends ChangeNotifier {
  List receipts = [];
  bool isLoading = false;
  // Rozsah dat pro filtrování
  DateTimeRange? dateRange; // [cite: 196]

  ReceiptProvider();

  /// Celkový příjem z účtenek
  double get totalRevenue {
    return receipts.fold(
        0.0, (sum, receipt) => sum + (receipt['total'] as num).toDouble()); // [cite: 196]
  }

  /// Průměrná hodnota účtenky
  double get averageValue {
    return receipts.isNotEmpty ? totalRevenue / receipts.length : 0.0; // [cite: 197, 198]
  }

  // Upravená metoda fetchReceipts - přijímá filtrační parametry
  Future<void> fetchReceipts({
    DateTimeRange? dateRange,
    bool showCash = true,
    bool showCard = true,
    bool showBank = true,
    bool showOther = true,
    bool showWithDiscount = false,
  }) async {
    isLoading = true; // [cite: 199]
    notifyListeners(); // [cite: 199]
    try {
      // Získání rozsahu dat
      String dateFrom = dateRange != null
          ? DateFormat('yyyy-MM-dd').format(dateRange.start) // [cite: 199, 200]
          : DateFormat('yyyy-MM-dd').format(DateTime.now()); // [cite: 200]
      String dateTo = dateRange != null
          ? DateFormat('yyyy-MM-dd').format(dateRange.end) // [cite: 201, 202]
          : DateFormat('yyyy-MM-dd').format(DateTime.now()); // [cite: 202]

      print('Loading ALL Receipts (with pagination), date from: $dateFrom, to: $dateTo');
      // Volání upravené metody ApiService.fetchReceipts, která řeší paginaci interně.
      // 'initialLimit' je zde použit pro první volání v rámci paginace v ApiService.
      List allReceipts = await ApiService.fetchReceipts(dateFrom, dateTo, initialLimit: 500); // [cite: 203]

      // Filtrace účtenek - přesunuto z ReceiptListScreen (zůstává)
      receipts = allReceipts.where((receipt) {
        String paymentType = receipt['paymentType'];
        bool matchesPayment = (paymentType == 'CASH' && showCash) ||
            (paymentType == 'CARD' && showCard) ||
            (paymentType == 'BANK' && showBank) ||
            (paymentType == 'CRYPTO' && showOther);

        bool hasDiscount = false; // [cite: 204]
        if (receipt['items'] != null && receipt['items'] is List) { // [cite: 204]
          hasDiscount = (receipt['items'] as List).any((item) { // [cite: 204]
            var price = item['itemPrice']; // [cite: 204]
            return price is num && price < 0; // [cite: 204]
          });
        }

        return matchesPayment && (!showWithDiscount || hasDiscount); // [cite: 205]
      }).toList();

      print('Filtered Receipts (after pagination): ${receipts.length}'); // [cite: 205]
    } catch (e) {
      print('Error while getting Receipts in Provider: $e'); // [cite: 206]
      // Zde můžete přidat specifickou chybovou hlášku pro uživatele, pokud je potřeba
      receipts = []; // V případě chyby vyprázdníme seznam, aby se nezobrazovala stará data
    } finally {
      isLoading = false; // [cite: 207]
      notifyListeners(); // [cite: 207, 208]
    }
  }

  /// Aktualizace rozsahu dat
  void updateDateRange(DateTimeRange? newDateRange) {
    dateRange = newDateRange; // [cite: 208, 209]
    // Není potřeba zde volat notifyListeners(), fetchReceipts to udělá po načtení
  }

  /// Vrací seznam nejprodávanějších produktů podle tržby.
  List<Map<String, dynamic>> getTopProducts({int limit = 5}) {
    final Map<String, Map<String, dynamic>> productData = {}; // [cite: 209]
    for (var receipt in receipts) { // [cite: 210]
      if (receipt['items'] != null && receipt['items'] is List) { // [cite: 210]
        for (var item in receipt['items']) { // [cite: 210]
          final productName = item['text'] ?? ''; // [cite: 210, 211]

          if (!productData.containsKey(productName)) { // [cite: 211]
            productData[productName] = { // [cite: 211]
              'name': productName, // [cite: 211]
              'quantity': 0.0, // [cite: 211]
              'revenue': 0.0, // [cite: 211]
            };
          }
          productData[productName]!['quantity'] +=
              (item['quantity'] as num).toDouble(); // [cite: 212, 213]
          productData[productName]!['revenue'] +=
              (item['priceToPay'] as num).toDouble(); // [cite: 213, 214]
        }
      }
    }

    final topList = productData.values.toList() // [cite: 214]
      ..sort((a, b) => b['revenue'].compareTo(a['revenue'])); // [cite: 214]
    return topList.take(limit).toList(); // [cite: 215]
  }

  /// Vrací seznam nejprodávanějších kategorií podle tržby (revenue).
  /// Struktura: [{ 'name': ..., 'quantity': ..., 'revenue': ... }, ...]
  List<Map<String, dynamic>> getTopCategories({ // [cite: 216]
    int limit = 5,
    required ProductProvider productProvider,
  }) {
    final Map<String, Map<String, dynamic>> categoryMap = {}; // [cite: 216]
    for (var receipt in receipts) { // [cite: 217]
      if (receipt['items'] != null && receipt['items'] is List) { // [cite: 217]
        for (var item in receipt['items']) { // [cite: 217]
          final productName = item['text'] ?? ''; // [cite: 217, 218]
          final product = productProvider.getProductByName(productName); // [cite: 218]

          final category = product?.categoryName ?? 'Uncategorized'; // [cite: 218]
          final double quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0; // [cite: 218]
          final double price = (item['itemPrice'] as num?)?.toDouble() ?? 0.0; // [cite: 219]
          final double revenue = quantity * price; // [cite: 219]
          if (!categoryMap.containsKey(category)) { // [cite: 220]
            categoryMap[category] = { // [cite: 220]
              'name': category, // [cite: 220]
              'quantity': 0.0, // [cite: 220]
              'revenue': 0.0, // [cite: 221]
            };
          }
          categoryMap[category]!['quantity'] += quantity; // [cite: 221]
          categoryMap[category]!['revenue'] += revenue; // [cite: 221, 222]
        }
      }
    }

    final sortedCategories = categoryMap.values.toList() // [cite: 222]
      ..sort((a, b) => b['revenue'].compareTo(a['revenue'])); // [cite: 222]
    return sortedCategories.take(limit).toList(); // [cite: 223]
  }

  // Řazení účtenek
  void sortReceipts(String criteria, bool ascending) {
    receipts.sort((a, b) { // [cite: 223]
      dynamic valueA;
      dynamic valueB;
      if (criteria == 'price') { // [cite: 223]
        valueA = a['total']; // [cite: 223]
        valueB = b['total']; // [cite: 223]
      } else if (criteria == 'time') { // [cite: 223]
        valueA = DateTime.parse(a['dateTime']); // [cite: 223]
        valueB = DateTime.parse(b['dateTime']); // [cite: 223, 224]
      }
      if (ascending) { // [cite: 224]
        return Comparable.compare(valueA, valueB); // [cite: 224]
      } else {
        return Comparable.compare(valueB, valueA); // [cite: 224]
      }
    });
    notifyListeners(); // [cite: 225]
  }
}