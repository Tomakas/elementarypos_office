// lib/services/utility_services.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../models/dashboard_widget_model.dart'; // Ujisti se, že cesta k modelu je správná

class StorageService {
  // Klíče pro ukládání do SharedPreferences
  static const String _apiKeyKey = 'api_key';
  static const String _languageCodeKey = 'language_code';
  static const String _dashboardWidgetsKey = 'dashboard_widgets_order';
  static const String _productPurchasePricesKey = 'product_purchase_prices';

  static Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, apiKey);
    print('API key was saved: $apiKey');
  }

  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString(_apiKeyKey);
    return apiKey;
  }

  static Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiKeyKey);
    print('API key was deleted.');
  }

  static Future<void> saveLanguageCode(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageCodeKey, languageCode);
    print('Saved language code: $languageCode');
  }

  static Future<String?> getLanguageCode() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_languageCodeKey);
    print('Loaded language code: $languageCode');
    return languageCode;
  }

  static Future<void> saveDashboardWidgetsOrder(
      List<DashboardWidgetModel> widgets) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = widgets.map((w) => w.toJson()).toList();
    final jsonString = json.encode(jsonList);
    await prefs.setString(_dashboardWidgetsKey, jsonString);
    print('Widget order saved: $jsonString');
  }

  static Future<List<DashboardWidgetModel>> getDashboardWidgetsOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_dashboardWidgetsKey);
    if (jsonString == null) {
      print('Žádné uložené widgety na dashboardu nenalezeny.');
      return [];
    }
    final List<dynamic> jsonList = json.decode(jsonString);
    final widgets =
    jsonList.map((jsonMap) => DashboardWidgetModel.fromJson(jsonMap as Map<String, dynamic>)).toList();
    print('Loaded widgets: $widgets');
    return widgets;
  }

  static Future<void> clearDashboardWidgets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dashboardWidgetsKey);
    print('Widgets on dashboard were deleted.');
  }

  static Future<void> saveProductPurchasePrices(Map<String, double?> prices) async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> storableMap = prices.map((key, value) => MapEntry(key, value));
    final String jsonString = json.encode(storableMap);
    await prefs.setString(_productPurchasePricesKey, jsonString);
    print('Product purchase prices saved: $jsonString');
  }

  static Future<Map<String, double?>> loadProductPurchasePrices() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_productPurchasePricesKey);
    if (jsonString == null || jsonString.isEmpty) {
      print('No product purchase prices found in SharedPreferences.');
      return {};
    }
    try {
      final Map<String, dynamic> decodedMap = json.decode(jsonString);
      final Map<String, double?> prices = decodedMap.map((key, value) {
        if (value == null) {
          return MapEntry(key, null);
        }
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
    bool trimZeroDecimals = false
  }) {
    final usedLocale = locale ?? 'cs_CZ';
    NumberFormat format;
    bool isWholeNumber = value is int || (value is double && value == value.truncateToDouble());
    if (trimZeroDecimals && isWholeNumber) {
      format = NumberFormat.currency(locale: usedLocale, symbol: currencySymbol ?? 'Kč', decimalDigits: 0);
    } else {
      format = NumberFormat.currency(locale: usedLocale, symbol: currencySymbol ?? 'Kč', decimalDigits: decimals);
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

class PreferencesHelper {
  static const String sortCriteriaKey = 'sortCriteria';
  static const String sortAscendingKey = 'sortAscending';
  static const String showOnlyOnSaleKey = 'showOnlyOnSale';
  static const String showOnlyInStockKey = 'showOnlyInStock';
  static const String currentCategoryKey = 'currentCategory';
  static const String isCategoryViewKey = 'isCategoryView';

  static Future<void> saveFilterPreferences({
    required String sortCriteria,
    required bool sortAscending,
    required bool showOnlyOnSale,
    required bool showOnlyInStock,
    required String currentCategoryId,
    required bool isCategoryView,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(sortCriteriaKey, sortCriteria);
    await prefs.setBool(sortAscendingKey, sortAscending);
    await prefs.setBool(showOnlyOnSaleKey, showOnlyOnSale);
    await prefs.setBool(showOnlyInStockKey, showOnlyInStock);
    await prefs.setString(currentCategoryKey, currentCategoryId);
    await prefs.setBool(isCategoryViewKey, isCategoryView);
    print("Preferences saved. isCategoryView: $isCategoryView");
  }

  static Future<Map<String, dynamic>> loadFilterPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final loadedPrefs = {
      'sortCriteria': prefs.getString(sortCriteriaKey) ?? 'name',
      'sortAscending': prefs.getBool(sortAscendingKey) ?? true,
      'showOnlyOnSale': prefs.getBool(showOnlyOnSaleKey) ?? false,
      'showOnlyInStock': prefs.getBool(showOnlyInStockKey) ?? false,
      'currentCategoryId': prefs.getString(currentCategoryKey) ?? '',
      'isCategoryView': prefs.getBool(isCategoryViewKey) ?? true,
    };
    print("Preferences loaded: $loadedPrefs");
    return loadedPrefs;
  }
}