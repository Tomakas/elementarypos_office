//lib/services/dashboard_widgets.dart

import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/product.dart';

class ApiService {
  static const String baseUrl = 'https://api.elementarypos.com/v1';
  static const Duration requestTimeout = Duration(seconds: 10);

  /// Generická metoda pro HTTP požadavky
  static Future<dynamic> _makeRequest(
      Uri url,
      String apiKey, {
        String method = 'GET',
        Map<String, String>? headers,
        dynamic body,
      }) async {
    final defaultHeaders = {
      'accept': 'application/json',
      'X-Api-Key': apiKey,
      'Content-Type': 'application/json',
    };

    final combinedHeaders = {...defaultHeaders, if (headers != null) ...headers};

    http.Response response;

    try {
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http
              .get(url, headers: combinedHeaders)
              .timeout(requestTimeout);
          break;
        case 'POST':
          response = await http
              .post(url, headers: combinedHeaders, body: json.encode(body))
              .timeout(requestTimeout);
          break;
        default:
          throw UnsupportedError('HTTP metoda $method není podporována.');
      }

      print('HTTP status: ${response.statusCode}');
      print('HTTP odpověď: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        throw HttpException(
            'Chyba při požadavku na $url: ${response.statusCode} - ${response.body}');
      }
    } on SocketException {
      throw SocketException('Nelze se připojit k serveru.');
    } on HttpException catch (e) {
      throw HttpException(e.message);
    } on FormatException {
      throw const FormatException('Chybný formát odpovědi.');
    } on TimeoutException {
      throw TimeoutException('Požadavek vypršel čas.');
    } catch (e) {
      throw Exception('Neznámá chyba: $e');
    }
  }

  /// Načtení účtenek z API
  static Future<List<dynamic>> fetchReceipts(
      String apiKey, String dateFrom, String dateTo, int limit) async {
    final url = Uri.parse(
        '$baseUrl/receipt/receipts?dateFrom=$dateFrom&dateTo=$dateTo&limit=$limit');
    print('Volání API pro účtenky: $url');

    final data = await _makeRequest(
      url,
      apiKey,
      method: 'GET',
    );

    return data['receipts'] ?? [];
  }

  /// Načtení kategorií z API
  static Future<List<Map<String, dynamic>>> fetchCategories(String apiKey) async {
    final url = Uri.parse('$baseUrl/category/get-categories');
    print('Volání API pro kategorie: $url');

    final data = await _makeRequest(
      url,
      apiKey,
      method: 'POST',
    );

    return List<Map<String, dynamic>>.from(data['categories'] ?? []);
  }

  /// Načtení produktů z API
  static Future<List<Product>> fetchProducts(
      String apiKey, {
        String? filterCategoryId,
        String? filterCategoryName,
        int? filterColor,
      }) async {
    final url = Uri.parse('$baseUrl/item/get-sales-items');
    print('Volání API pro produkty: $url');

    final body = {
      'filterCategoryId': filterCategoryId,
      'filterCategoryName': filterCategoryName,
      'filterColor': filterColor,
    };

    final data = await _makeRequest(
      url,
      apiKey,
      method: 'POST',
      body: body,
    );

    return (data['items'] as List)
        .map((item) => Product.fromJson(item))
        .toList();
  }

  /// Načtení stavu skladu
  static Future<List<Map<String, dynamic>>> fetchActualStockData(String apiKey) async {
    final url = Uri.parse('$baseUrl/stock/get-actual-stock-data');
    print('Volání API pro sklad: $url');

    final data = await _makeRequest(
      url,
      apiKey,
      method: 'POST',
    );

    return List<Map<String, dynamic>>.from(data['list'] ?? []);
  }

  /// Přidání produktu
  static Future<void> addProduct(String apiKey, Product product) async {
    final url = Uri.parse('$baseUrl/item/add-sale-item');
    print('Přidání produktu: $url');

    final productJson = product.toJson();
    print('JSON tělo požadavku: $productJson');

    await _makeRequest(
      url,
      apiKey,
      method: 'POST',
      body: productJson,
    );

    print('Produkt úspěšně přidán.');
  }

  /// Úprava produktu
  static Future<void> editProduct(String apiKey, Product product) async {
    final url = Uri.parse('$baseUrl/item/edit-sale-item');
    print('Úprava produktu: $url');

    final productJson = product.toJson();
    print('JSON tělo požadavku: $productJson');

    await _makeRequest(
      url,
      apiKey,
      method: 'POST',
      body: productJson,
    );

    print('Produkt úspěšně upraven.');
  }

  /// Smazání produktu
  static Future<void> deleteProduct(String apiKey, String itemId) async {
    final url = Uri.parse('$baseUrl/item/delete-sale-item');
    print('Mazání produktu: $url');

    final body = {'itemId': itemId};


    await _makeRequest(
      url,
      apiKey,
      method: 'POST',
      body: body,
    );

    print('Produkt úspěšně smazán.');
  }

  /// Načtení daňových sazeb
  static Future<List<Map<String, dynamic>>> fetchTaxSettings(String apiKey) async {
    final url = Uri.parse('$baseUrl/tax/get-tax-settings');
    print('Volání API pro daňové sazby: $url');

    final data = await _makeRequest(
      url,
      apiKey,
      method: 'POST',
    );

    final taxes = List<Map<String, dynamic>>.from(data['taxes'] ?? []);
    return taxes.where((tax) => tax['deleted'] == false).toList();
  }

  /// Načtení zákazníků
  static Future<List<Map<String, dynamic>>> fetchCustomers(String apiKey) async {
    final url = Uri.parse('$baseUrl/customer/get-customers');
    print('Volání API pro zákazníky: $url');

    final data = await _makeRequest(
      url,
      apiKey,
      method: 'POST',
    );

    return List<Map<String, dynamic>>.from(data['customers'] ?? []);
  }

  /// Načtení detailu zákazníka
  static Future<Map<String, dynamic>> fetchCustomerDetail(
      String apiKey, String customerId) async {
    final url = Uri.parse('$baseUrl/customer/get-customer');
    print('Volání API pro detail zákazníka: $url');

    final body = {'customerId': customerId};

    final data = await _makeRequest(
      url,
      apiKey,
      method: 'POST',
      body: body,
    );

    return data;
  }

  /// Úprava zákazníka
  static Future<void> editCustomer(
      String apiKey, Map<String, dynamic> customerData) async {
    final url = Uri.parse('$baseUrl/customer/edit-customer');
    print('Úprava zákazníka: $url');

    await _makeRequest(
      url,
      apiKey,
      method: 'POST',
      body: customerData,
    );

    print('Zákazník úspěšně upraven.');
  }

  /// Vytvoření zákazníka
  static Future<String> createCustomer(
      String apiKey, Map<String, dynamic> customerData) async {
    final url = Uri.parse('$baseUrl/customer/create-customer');
    print('Vytváření zákazníka: $url');

    final data = await _makeRequest(
      url,
      apiKey,
      method: 'POST',
      body: customerData,
    );

    print('Zákazník úspěšně vytvořen.');
    return data['customerId'];
  }
}
