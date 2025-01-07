import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../providers/product_provider.dart';

class ReceiptProvider extends ChangeNotifier {
  List receipts = [];
  bool isLoading = false;

  // Rozsah dat pro filtrování
  DateTimeRange? dateRange;

  // Filtrační parametry pro typ platby a slevy
  bool showCash = true;
  bool showCard = true;
  bool showBank = true;
  bool showOther = true;
  bool showWithDiscount = false;

  ReceiptProvider();

  /// Celkový příjem z účtenek
  double get totalRevenue {
    return receipts.fold(
        0.0, (sum, receipt) => sum + (receipt['total'] as num).toDouble());
  }

  /// Průměrná hodnota účtenky
  double get averageValue {
    return receipts.isNotEmpty ? totalRevenue / receipts.length : 0.0;
  }

  /// Načtení účtenek
  Future<void> fetchReceipts() async {
    isLoading = true;
    notifyListeners();
    try {
      // Získání rozsahu dat
      String dateFrom = dateRange != null
          ? DateFormat('yyyy-MM-dd').format(dateRange!.start)
          : DateFormat('yyyy-MM-dd').format(DateTime.now());
      String dateTo = dateRange != null
          ? DateFormat('yyyy-MM-dd').format(dateRange!.end)
          : DateFormat('yyyy-MM-dd').format(DateTime.now());

      print('Loading Receipts, date from: $dateFrom, to: $dateTo');
      List allReceipts = await ApiService.fetchReceipts(dateFrom, dateTo, 500);

      // Filtrace účtenek podle filtračních parametrů
      receipts = allReceipts.where((receipt) {
        String paymentType = receipt['paymentType'];
        bool matchesPayment = (paymentType == 'CASH' && showCash) ||
            (paymentType == 'CARD' && showCard) ||
            (paymentType == 'BANK' && showBank) ||
            (paymentType == 'OTHER' && showOther);

        bool hasDiscount = false;
        if (receipt['items'] != null && receipt['items'] is List) {
          hasDiscount = (receipt['items'] as List).any((item) {
            var price = item['itemPrice'];
            return price is num && price < 0;
          });
        }
        // Pokud showWithDiscount == true, vyžadujeme, aby tam byla sleva
        return matchesPayment && (!showWithDiscount || hasDiscount);
      }).toList();

      print('Filtered Receipts: ${receipts.length}');
    } catch (e) {
      print('Error while getting Receipts: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Aktualizace rozsahu dat
  void updateDateRange(DateTimeRange? newDateRange) {
    dateRange = newDateRange;
  }

  /// Aktualizace filtračních parametrů
  void updateFilters({
    bool? showCash,
    bool? showCard,
    bool? showBank,
    bool? showOther,
    bool? showWithDiscount,
  }) {
    if (showCash != null) this.showCash = showCash;
    if (showCard != null) this.showCard = showCard;
    if (showBank != null) this.showBank = showBank;
    if (showOther != null) this.showOther = showOther;
    if (showWithDiscount != null) this.showWithDiscount = showWithDiscount;
    fetchReceipts();
  }

  /// Vrací seznam nejprodávanějších produktů podle tržby.
  List<Map<String, dynamic>> getTopProducts({int limit = 5}) {
    final Map<String, Map<String, dynamic>> productData = {};

    for (var receipt in receipts) {
      if (receipt['items'] != null && receipt['items'] is List) {
        for (var item in receipt['items']) {
          final productName = item['text'] ?? '';

          if (!productData.containsKey(productName)) {
            productData[productName] = {
              'name': productName,
              'quantity': 0.0,
              'revenue': 0.0,
            };
          }
          productData[productName]!['quantity'] +=
              (item['quantity'] as num).toDouble();
          productData[productName]!['revenue'] +=
              (item['priceToPay'] as num).toDouble();
        }
      }
    }

    final topList = productData.values.toList()
      ..sort((a, b) => b['revenue'].compareTo(a['revenue']));
    return topList.take(limit).toList();
  }

  /// Vrací seznam nejprodávanějších kategorií podle tržby (revenue).
  /// Struktura: [{ 'name': ..., 'quantity': ..., 'revenue': ... }, ...]
  List<Map<String, dynamic>> getTopCategories({
    int limit = 5,
    required ProductProvider productProvider,
  }) {
    final Map<String, Map<String, dynamic>> categoryMap = {};

    for (var receipt in receipts) {
      if (receipt['items'] != null && receipt['items'] is List) {
        for (var item in receipt['items']) {
          final productName = item['text'] ?? '';
          final product = productProvider.getProductByName(productName);

          final category = product?.categoryName ?? 'Uncategorized';
          final double quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
          final double price = (item['itemPrice'] as num?)?.toDouble() ?? 0.0;
          final double revenue = quantity * price;

          if (!categoryMap.containsKey(category)) {
            categoryMap[category] = {
              'name': category,
              'quantity': 0.0,
              'revenue': 0.0,
            };
          }
          categoryMap[category]!['quantity'] += quantity;
          categoryMap[category]!['revenue'] += revenue;
        }
      }
    }

    final sortedCategories = categoryMap.values.toList()
      ..sort((a, b) => b['revenue'].compareTo(a['revenue']));
    return sortedCategories.take(limit).toList();
  }

  // Řazení účtenek
  void sortReceipts(String criteria, bool ascending) {
    receipts.sort((a, b) {
        dynamic valueA;
        dynamic valueB;
        if (criteria == 'price') {
          valueA = a['total'];
          valueB = b['total'];
        } else if (criteria == 'time') {
          valueA = DateTime.parse(a['dateTime']);
          valueB = DateTime.parse(b['dateTime']);
        }
        if (ascending) {
          return Comparable.compare(valueA, valueB);
        } else {
          return Comparable.compare(valueB, valueA);
        }
      });
    notifyListeners(); // notifyListeners() se zavolá zde
  }
}
