// lib/providers/receipt_provider.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../providers/product_provider.dart'; // Potřebné pro getTopCategoriesFromList
import '../l10n/app_localizations.dart';


class ReceiptProvider extends ChangeNotifier {
  bool _isLoading = false;
  DateTimeRange? _currentDateRange; // Interní stav pro datumový rozsah používaný obrazovkami

  bool get isLoading => _isLoading;
  DateTimeRange? get currentDateRange => _currentDateRange;

  /// Aktualizuje interní datumový rozsah.
  /// Obrazovky by měly po zavolání této metody typicky spustit fetchReceipts.
  void updateDateRange(DateTimeRange? newDateRange) {
    _currentDateRange = newDateRange;
    // Zde nevoláme notifyListeners() záměrně.
    // Změna samotného rozsahu nemusí nutně znamenat nová data, dokud se nespustí fetch.
    // Obrazovka, která mění rozsah, by měla být zodpovědná za vyvolání fetch.
    // Pokud bys chtěl, aby jiné widgety reagovaly přímo na změnu _currentDateRange,
    // mohl bys zde notifyListeners() přidat, ale pak by se muselo ošetřit, jak se s tím pracuje.
  }

  /// Načte účtenky z API a vrátí je jako seznam.
  /// Filtrování probíhá na základě předaných parametrů.
  Future<List<dynamic>> fetchReceipts({
    required DateTimeRange dateRange, // Datumový rozsah je nyní vyžadován přímo od volajícího
    bool showCash = true,
    bool showCard = true,
    bool showBank = true,
    bool showOther = true,
    bool showWithDiscount = false,
  }) async {
    _isLoading = true;
    notifyListeners(); // Oznamujeme začátek načítání

    List<dynamic> fetchedAndFilteredReceipts = [];
    try {
      String dateFrom = DateFormat('yyyy-MM-dd').format(dateRange.start);
      String dateTo = DateFormat('yyyy-MM-dd').format(dateRange.end);

      print('ReceiptProvider: Načítám účtenky z API pro rozsah $dateFrom do $dateTo');
      List allApiReceipts = await ApiService.fetchReceipts(dateFrom, dateTo, initialLimit: 500);

      fetchedAndFilteredReceipts = allApiReceipts.where((receipt) {
        String paymentType = receipt['paymentType'] ?? 'OTHER';
        bool matchesPayment = (paymentType == 'CASH' && showCash) ||
            (paymentType == 'CARD' && showCard) ||
            (paymentType == 'BANK' && showBank) ||
            (paymentType == 'CRYPTO' && showOther) || // Předpokládáme, že 'CRYPTO' je mapováno na 'otherFilter'
            (paymentType == 'OTHER' && showOther);


        bool hasDiscount = false;
        if (receipt['items'] != null && receipt['items'] is List) {
          hasDiscount = (receipt['items'] as List).any((item) {
            var price = item['itemPrice'];
            return price is num && price < 0;
          });
        }
        return matchesPayment && (!showWithDiscount || hasDiscount);
      }).toList();
      print('ReceiptProvider: Načteno a filtrováno ${fetchedAndFilteredReceipts.length} účtenek.');
    } catch (e) {
      print('ReceiptProvider: Chyba při načítání účtenek: $e');
      // Můžeš zvážit rethrow e; pokud chceš chybu zpracovat výše
    } finally {
      _isLoading = false;
      notifyListeners(); // Oznamujeme konec načítání
    }
    return fetchedAndFilteredReceipts;
  }

  // --- Statické pomocné metody pro výpočty nad seznamem účtenek ---

  static double calculateTotalRevenue(List<dynamic> receiptsToCalculate) {
    if (receiptsToCalculate.isEmpty) return 0.0;
    return receiptsToCalculate.fold(
        0.0, (sum, receipt) => sum + ((receipt['total'] as num?)?.toDouble() ?? 0.0));
  }

  static double calculateAverageValue(List<dynamic> receiptsToCalculate) {
    if (receiptsToCalculate.isEmpty) return 0.0;
    double totalRevenue = calculateTotalRevenue(receiptsToCalculate);
    return totalRevenue / receiptsToCalculate.length;
  }

  static List<Map<String, dynamic>> getTopProductsFromList(List<dynamic> receiptsToCalculate, {int limit = 5}) {
    final Map<String, Map<String, dynamic>> productData = {};
    for (var receipt in receiptsToCalculate) {
      if (receipt['items'] != null && receipt['items'] is List) {
        for (var item in receipt['items']) {
          final productName = item['text'] as String? ?? 'Neznámý produkt'; // Můžeš lokalizovat
          if (!productData.containsKey(productName)) {
            productData[productName] = {'name': productName, 'quantity': 0.0, 'revenue': 0.0};
          }
          // Předpokládáme, že 'quantity' a 'priceToPay' jsou typu num
          productData[productName]!['quantity'] += (item['quantity'] as num?)?.toDouble() ?? 0.0;
          productData[productName]!['revenue'] += (item['priceToPay'] as num?)?.toDouble() ?? 0.0;
        }
      }
    }
    final topList = productData.values.toList()
      ..sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
    return topList.take(limit).toList();
  }

  static List<Map<String, dynamic>> getTopCategoriesFromList(
      List<dynamic> receiptsToCalculate, {
        int limit = 5,
        required ProductProvider productProvider, // ProductProvider je stále potřeba pro mapování produktů na kategorie
        required AppLocalizations localizations, // Pro lokalizaci "Uncategorized"
      }) {
    final Map<String, Map<String, dynamic>> categoryMap = {};
    for (var receipt in receiptsToCalculate) {
      if (receipt['items'] != null && receipt['items'] is List) {
        for (var item in receipt['items']) {
          final productName = item['text'] as String? ?? '';
          final product = productProvider.getProductByName(productName); // Vyhledání produktu

          // Použijeme název kategorie z produktu, nebo výchozí, pokud produkt/kategorie není nalezena
          final category = product?.categoryName ?? localizations.translate('unknownCategory');

          final double quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
          // Pro revenue z kategorie použijeme itemPrice * quantity, priceToPay může zahrnovat slevy na celou účtenku
          final double itemPrice = (item['itemPrice'] as num?)?.toDouble() ?? 0.0;
          final double revenue = quantity * itemPrice;

          if (!categoryMap.containsKey(category)) {
            categoryMap[category] = {'name': category, 'quantity': 0.0, 'revenue': 0.0};
          }
          categoryMap[category]!['quantity'] += quantity;
          categoryMap[category]!['revenue'] += revenue;
        }
      }
    }
    final sortedCategories = categoryMap.values.toList()
      ..sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
    return sortedCategories.take(limit).toList();
  }
}