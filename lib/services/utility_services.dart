// lib/services/utility_services.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart'; // Import pro Locale a WidgetsBinding
import 'dart:convert';
import 'package:intl/intl.dart'; // Důležité pro NumberFormat
import '../models/dashboard_widget_model.dart'; // Import DashboardWidgetModel

class StorageService {
  // Klíče pro ukládání do SharedPreferences
  static const String _apiKeyKey = 'api_key';
  static const String _languageCodeKey = 'language_code';
  static const String _dashboardWidgetsKey = 'dashboard_widgets_order';

  /// Uloží API klíč do `SharedPreferences`.
  static Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, apiKey);
    print('API klíč byl uložen: $apiKey');
  }

  /// Načte API klíč z `SharedPreferences`.
  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString(_apiKeyKey);
    print('Načtený API klíč: $apiKey');
    return apiKey;
  }

  /// Smaže API klíč z `SharedPreferences`.
  static Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiKeyKey);
    print('API klíč byl smazán.');
  }

  /// Uloží jazykový kód do `SharedPreferences`.
  static Future<void> saveLanguageCode(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageCodeKey, languageCode);
    print('Jazykový kód byl uložen: $languageCode');
  }

  /// Načte jazykový kód z `SharedPreferences`.
  static Future<String?> getLanguageCode() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_languageCodeKey);
    print('Načtený jazykový kód: $languageCode');
    return languageCode;
  }

  /// Uloží pořadí widgetů na dashboardu do `SharedPreferences`.
  static Future<void> saveDashboardWidgetsOrder(List<DashboardWidgetModel> widgets) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = widgets.map((w) => w.toJson()).toList();
    final jsonString = json.encode(jsonList);
    await prefs.setString(_dashboardWidgetsKey, jsonString);
    print('Pořadí widgetů bylo uloženo: $jsonString');
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
    final widgets = jsonList.map((json) => DashboardWidgetModel.fromJson(json)).toList();
    print('Načtené widgety: $widgets');
    return widgets;
  }

  /// Smaže uložené widgety z `SharedPreferences`.
  static Future<void> clearDashboardWidgets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dashboardWidgetsKey);
    print('Widgety na dashboardu byly smazány.');
  }
}

class Utility {
  /// Metoda pro normální (plain) čísla bez měny.
  static String formatNumber(num value, {int decimals = 2, String? locale}) {
    final usedLocale = locale ?? 'cs_CZ';
    final format = NumberFormat('#,##0.##', usedLocale);
    // Pokud potřebujete fixní počet desetinných míst, upravte podle potřeby
    // např. NumberFormat('###,###.00', usedLocale)
    return format.format(value);
  }

  /// Metoda pro formátování hodnoty v měně.
  static String formatCurrency(num value, {String? currencySymbol, String? locale, int decimals = 2}) {
    final usedLocale = locale ?? 'cs_CZ';
    // Pokud nechcete vyloženě currency, lze použít NumberFormat.simpleCurrency
    // Ale s currency() získáte větší kontrolu nad parametry:
    final format = NumberFormat.currency(
      locale: usedLocale,
      symbol: currencySymbol ?? 'Kč',
      decimalDigits: decimals,
    );
    return format.format(value);
  }

  /// Normalizace textu odstraněním diakritiky
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
    return Locale(languageCode ?? WidgetsBinding.instance.window.locale.languageCode);
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