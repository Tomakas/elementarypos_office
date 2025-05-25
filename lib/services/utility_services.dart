// lib/services/utility_services.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart'; // Import pro Locale a WidgetsBinding
import 'dart:convert';
import 'package:intl/intl.dart';
import '../models/dashboard_widget_model.dart'; // Import DashboardWidgetModel

class StorageService {
  // Klíče pro ukládání do SharedPreferences
  static const String _apiKeyKey = 'api_key';
  static const String _languageCodeKey = 'language_code';
  static const String _dashboardWidgetsKey = 'dashboard_widgets_order';
  static const String _productPurchasePricesKey = 'product_purchase_prices'; // Nový klíč

  /// Uloží API klíč do `SharedPreferences`.
  static Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, apiKey);
    print('API key was saved: $apiKey');
  }

  /// Načte API klíč z `SharedPreferences`.
  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString(_apiKeyKey);
    return apiKey;
  }

  /// Smaže API klíč z `SharedPreferences`.
  static Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiKeyKey);
    print('API key was deleted.');
  }

  /// Uloží jazykový kód do `SharedPreferences`.
  static Future<void> saveLanguageCode(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageCodeKey, languageCode);
    print('Saved language code: $languageCode');
  }

  /// Načte jazykový kód z `SharedPreferences`.
  static Future<String?> getLanguageCode() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_languageCodeKey);
    print('Loaded language code: $languageCode');
    return languageCode;
  }

  /// Uloží pořadí widgetů na dashboardu do `SharedPreferences`.
  static Future<void> saveDashboardWidgetsOrder(
      List<DashboardWidgetModel> widgets) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = widgets.map((w) => w.toJson()).toList();
    final jsonString = json.encode(jsonList);
    await prefs.setString(_dashboardWidgetsKey, jsonString);
    print('Widget order saved: $jsonString');
  }

  /// Načte pořadí widgetů z `SharedPreferences`.
  static Future<List<DashboardWidgetModel>> getDashboardWidgetsOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_dashboardWidgetsKey);
    if (jsonString == null) {
      print('Žádné uložené widgety na dashboardu nenalezeny.');
      return [];
    }
    final List<dynamic> jsonList = json.decode(jsonString);
    final widgets =
    jsonList.map((json) => DashboardWidgetModel.fromJson(json)).toList();
    print('Loaded widgets: $widgets');
    return widgets;
  }

  /// Smaže uložené widgety z `SharedPreferences`.
  static Future<void> clearDashboardWidgets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dashboardWidgetsKey);
    print('Widgets on dashboard were deleted.');
  }

  // --- Nové metody pro nákupní ceny produktů ---

  /// Uloží mapu nákupních cen produktů do `SharedPreferences`.
  /// Mapa má formát { productId: purchasePrice }.
  /// Hodnoty `null` pro cenu znamenají, že cena není explicitně nastavena.
  static Future<void> saveProductPurchasePrices(Map<String, double?> prices) async {
    final prefs = await SharedPreferences.getInstance();
    // Převod mapy na formát ukládatelný do JSON (double? se přímo nepodporuje, ale null hodnoty ano)
    final Map<String, dynamic> storableMap = prices.map((key, value) => MapEntry(key, value));
    final String jsonString = json.encode(storableMap);
    await prefs.setString(_productPurchasePricesKey, jsonString);
    print('Product purchase prices saved: $jsonString');
  }

  /// Načte mapu nákupních cen produktů z `SharedPreferences`.
  /// Vrátí mapu { productId: purchasePrice }.
  static Future<Map<String, double?>> loadProductPurchasePrices() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_productPurchasePricesKey);
    if (jsonString == null || jsonString.isEmpty) {
      print('No product purchase prices found in SharedPreferences.');
      return {};
    }
    try {
      final Map<String, dynamic> decodedMap = json.decode(jsonString);
      // Převod zpět na Map<String, double?>
      final Map<String, double?> prices = decodedMap.map((key, value) {
        if (value == null) {
          return MapEntry(key, null);
        }
        // Ošetření pro případ, že by hodnota nebyla num (i když by měla být)
        return MapEntry(key, (value as num).toDouble());
      });
      print('Product purchase prices loaded: $prices');
      return prices;
    } catch (e) {
      print('Error decoding product purchase prices: $e. Returning empty map.');
      return {};
    }
  }
}

class Utility {
  static String formatNumber(num value, {int decimals = 2, String? locale}) {
    final usedLocale = locale ?? 'cs_CZ';
    final format = NumberFormat('#,##0.##', usedLocale);
    return format.format(value);
  }

  static String formatCurrency(num value, {
    String? currencySymbol,
    String? locale,
    int decimals = 2,
    bool trimZeroDecimals = false // Nový parametr
  }) {
    final usedLocale = locale ?? 'cs_CZ'; // Nebo lépe AppLocalizations.of(context).locale.toString() pokud máte context
    NumberFormat format;

    bool isWholeNumber = value is int || (value is double && value == value.truncateToDouble());

    if (trimZeroDecimals && isWholeNumber) {
      format = NumberFormat.currency(
        locale: usedLocale,
        symbol: currencySymbol ?? 'Kč', // Použijte widget.localizations.translate('currency') pro dynamický symbol
        decimalDigits: 0, // Nezobrazovat desetinná místa pro celá čísla
      );
    } else {
      format = NumberFormat.currency(
        locale: usedLocale,
        symbol: currencySymbol ?? 'Kč',
        decimalDigits: decimals, // Standardní počet desetinných míst
      );
    }
    return format.format(value);
  }

  static String normalizeString(String input) {
    const withDiacritics = 'áčďéěíňóřšťúůýžÁČĎÉĚÍŇÓŘŠŤÚŮÝŽ';
    const withoutDiacritics = 'acdeeinorstuuyzACDEEINORSTUUYZ';
    return input.split('').map((char) {
      final index = withDiacritics.indexOf(char);
      return index != -1 ? withoutDiacritics[index] : char;
    }).join();
  }
}
class LocalizationService {
  /// Načte aktuální jazyk z `SharedPreferences` nebo vrátí systémový výchozí jazyk.
  static Future<Locale> getLocale() async {
    final languageCode = await StorageService.getLanguageCode();
    return Locale(
        languageCode ?? WidgetsBinding.instance.platformDispatcher.locale.languageCode); // Použijeme platformDispatcher
  }

  /// Uloží jazykový kód do `SharedPreferences`.
  static Future<void> saveLanguageCode(String languageCode) async {
    await StorageService.saveLanguageCode(languageCode);
  }
}

// Preferences helper class for storing and retrieving filter preferences
class PreferencesHelper {
  static const String sortCriteriaKey = 'sortCriteria';
  static const String sortAscendingKey = 'sortAscending';
  static const String showOnlyOnSaleKey = 'showOnlyOnSale';
  static const String showOnlyInStockKey = 'showOnlyInStock';
  static const String currentCategoryKey = 'currentCategory';

  static Future<void> saveFilterPreferences({
    required String sortCriteria,
    required bool sortAscending,
    required bool showOnlyOnSale,
    required bool showOnlyInStock,
    required String currentCategoryId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(sortCriteriaKey, sortCriteria);
    await prefs.setBool(sortAscendingKey, sortAscending);
    await prefs.setBool(showOnlyOnSaleKey, showOnlyOnSale);
    await prefs.setBool(showOnlyInStockKey, showOnlyInStock);
    await prefs.setString(currentCategoryKey, currentCategoryId);
  }

  static Future<Map<String, dynamic>> loadFilterPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'sortCriteria': prefs.getString(sortCriteriaKey) ?? 'name',
      'sortAscending': prefs.getBool(sortAscendingKey) ?? true,
      'showOnlyOnSale': prefs.getBool(showOnlyOnSaleKey) ?? true,
      'showOnlyInStock': prefs.getBool(showOnlyInStockKey) ?? false,
      'currentCategoryId': prefs.getString(currentCategoryKey) ?? '',
    };
  }
}