import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/utility_services.dart';
import '../providers/product_provider.dart'; // Důležité pro getTopCategories

class ReceiptProvider extends ChangeNotifier {
  String? apiKey;
  List receipts = [];
  bool isLoading = false;

  // Rozsah dat pro filtrování (zde jej ukládáme pro fetchReceipts)
  DateTimeRange? dateRange;

  // Filtrační parametry pro typ platby a slevy
  bool showCash = true;
  bool showCard = true;
  bool showBank = true;
  bool showOther = true;
  bool showWithDiscount = false;

  ReceiptProvider(this.apiKey);

  /// Celkový příjem z účtenek
  double get totalRevenue {
    return receipts.fold(0.0, (sum, receipt) => sum + (receipt['total'] as num).toDouble());
  }

  /// Průměrná hodnota účtenky
  double get averageValue {
    return receipts.isNotEmpty ? totalRevenue / receipts.length : 0.0;
  }

  /// Načtení účtenek z API
  Future<void> fetchReceipts() async {
    isLoading = true;
    notifyListeners();
    try {
      // Dynamické načtení aktuálního API klíče
      apiKey = await StorageService.getApiKey();
      if (apiKey == null || apiKey!.isEmpty) {
        print('Chyba: API klíč není zadán.');
        return;
      }
      // Získání rozsahu dat
      String dateFrom = dateRange != null
          ? DateFormat('yyyy-MM-dd').format(dateRange!.start)
          : DateFormat('yyyy-MM-dd').format(DateTime.now());
      String dateTo = dateRange != null
          ? DateFormat('yyyy-MM-dd').format(dateRange!.end)
          : DateFormat('yyyy-MM-dd').format(DateTime.now());

      print('Načítání účtenek, datum od: $dateFrom, do: $dateTo');
      List allReceipts = await ApiService.fetchReceipts(apiKey!, dateFrom, dateTo, 500);

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

      print('Filtrované účtenky: ${receipts.length}');
    } catch (e) {
      print('Chyba při načítání účtenek: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Aktualizace rozsahu dat
  void updateDateRange(DateTimeRange? newDateRange) {
    dateRange = newDateRange;
    fetchReceipts();
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

  /// Nastavení API klíče (používá se při přímé aktualizaci bez načítání z úložiště)
  void setApiKey(String newApiKey) {
    apiKey = newApiKey;
    notifyListeners();
    fetchReceipts();
  }

  /// Vrací seznam nejprodávanějších produktů podle tržby (revenue).
  /// Struktura: [{ 'name': ..., 'quantity': ..., 'revenue': ... }, ...]
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
          productData[productName]!['quantity'] += (item['quantity'] as num).toDouble();
          productData[productName]!['revenue'] += (item['priceToPay'] as num).toDouble();
        }
      }
    }

    final topList = productData.values.toList()
      ..sort((a, b) => b['revenue'].compareTo(a['revenue']));
    return topList.take(limit).toList();
  }

  /// Vrací seznam nejprodávanějších kategorií podle tržby (revenue).
  /// Struktura: [{ 'name': ..., 'quantity': ..., 'revenue': ... }, ...]
  /// K zjištění názvu kategorie (product.categoryName) využívá ProductProvider.
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
}
