//lib/services/dashboard_widgets.dart

import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/product_model.dart';
import '../services/utility_services.dart';

class ApiService {
  static const String baseUrl = 'https://api.elementarypos.com/v1';
  static const Duration requestTimeout = Duration(seconds: 10);

  /// Generická metoda pro HTTP požadavky
  static Future<dynamic> _makeRequest(
    Uri url, {
    String method = 'GET',
    Map<String, String>? headers,
    dynamic body,
  }) async {
    final defaultHeaders = {
      'accept': 'application/json',
      'Content-Type': 'application/json',
    };

    final combinedHeaders = {
      ...defaultHeaders,
      if (headers != null) ...headers
    };
    final storedApiKey = await StorageService.getApiKey();
    if (storedApiKey == null || storedApiKey.isEmpty) {
      print('Error: API key not available.');
      return;
    }
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
          throw UnsupportedError('HTTP method $method is not supported.');
      }

      print('HTTP status: ${response.statusCode}');
      print('HTTP response: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        throw HttpException(
            'Request error on $url: ${response.statusCode} - ${response.body}');
      }
    } on SocketException {
      throw SocketException('Server is unavailable');
    } on HttpException catch (e) {
      throw HttpException(e.message);
    } on FormatException {
      throw const FormatException('Wrong response format');
    } on TimeoutException {
      throw TimeoutException('Request timeout');
    } catch (e) {
      throw Exception('Unknown error: $e');
    }
  }

  /// Načtení účtenek
  static Future<List<dynamic>> fetchReceipts(
      String dateFrom, String dateTo, int limit) async {
    final url = Uri.parse(
        '$baseUrl/receipt/receipts?dateFrom=$dateFrom&dateTo=$dateTo&limit=$limit');
    print('API call for Receipts: $url');

    final data = await _makeRequest(
      url,
      method: 'GET',
    );

    return data['receipts'] ?? [];
  }

  /// Načtení kategorií
  static Future<List<Map<String, dynamic>>> fetchCategories() async {
    final url = Uri.parse('$baseUrl/category/get-categories');
    print('API call for Categories: $url');

    final data = await _makeRequest(
      url,
      method: 'POST',
    );

    return List<Map<String, dynamic>>.from(data['categories'] ?? []);
  }

  /// Načtení produktů
  static Future<List<Product>> fetchProducts({
    String? filterCategoryId,
    String? filterCategoryName,
    int? filterColor,
  }) async {
    final url = Uri.parse('$baseUrl/item/get-sales-items');
    print('API call for products: $url');

    final body = {
      'filterCategoryId': filterCategoryId,
      'filterCategoryName': filterCategoryName,
      'filterColor': filterColor,
    };

    final data = await _makeRequest(
      url,
      method: 'POST',
      body: body,
    );

    return (data['items'] as List)
        .map((item) => Product.fromJson(item))
        .toList();
  }

  /// Načtení stavu skladu
  static Future<List<Map<String, dynamic>>> fetchActualStockData() async {
    final url = Uri.parse('$baseUrl/stock/get-actual-stock-data');
    print('API call for stock: $url');

    final data = await _makeRequest(
      url,
      method: 'POST',
    );

    return List<Map<String, dynamic>>.from(data['list'] ?? []);
  }

  /// Přidání produktu
  static Future<void> addProduct(Product product) async {
    final url = Uri.parse('$baseUrl/item/add-sale-item');
    print('Adding product: $url');

    final productJson = product.toJson();
    print('JSON request body: $productJson');

    await _makeRequest(
      url,
      method: 'POST',
      body: productJson,
    );

    print('Product successfully added');
  }

  /// Úprava produktu
  static Future<void> editProduct(Product product) async {
    final url = Uri.parse('$baseUrl/item/edit-sale-item');
    print('Edit Product: $url');

    final productJson = product.toJson();
    print('JSON request body: $productJson');

    await _makeRequest(
      url,
      method: 'POST',
      body: productJson,
    );

    print('Product successfully edited.');
  }

  /// Smazání produktu
  static Future<void> deleteProduct(String itemId) async {
    final url = Uri.parse('$baseUrl/item/delete-sale-item');
    print('Deleting Product: $url');

    final body = {'itemId': itemId};

    await _makeRequest(
      url,
      method: 'POST',
      body: body,
    );

    print('Product successfully deleted.');
  }

  /// Načtení daňových sazeb
  static Future<List<Map<String, dynamic>>> fetchTaxSettings() async {
    final url = Uri.parse('$baseUrl/tax/get-tax-settings');
    print('API call for tax rates: $url');

    final data = await _makeRequest(
      url,
      method: 'POST',
    );

    final taxes = List<Map<String, dynamic>>.from(data['taxes'] ?? []);
    return taxes.where((tax) => tax['deleted'] == false).toList();
  }

  /// Načtení zákazníků
  static Future<List<Map<String, dynamic>>> fetchCustomers() async {
    final url = Uri.parse('$baseUrl/customer/get-customers');
    print('API call for Customers: $url');

    final data = await _makeRequest(
      url,
      method: 'POST',
    );

    return List<Map<String, dynamic>>.from(data['customers'] ?? []);
  }

  /// Načtení detailu zákazníka
  static Future<Map<String, dynamic>> fetchCustomerDetail(
      String customerId) async {
    final url = Uri.parse('$baseUrl/customer/get-customer');
    print('API call for Customer details: $url');

    final body = {'customerId': customerId};

    final data = await _makeRequest(
      url,
      method: 'POST',
      body: body,
    );

    return data;
  }

  /// Úprava zákazníka
  static Future<void> editCustomer(Map<String, dynamic> customerData) async {
    final url = Uri.parse('$baseUrl/customer/edit-customer');
    print('Edit Customer: $url');

    await _makeRequest(
      url,
      method: 'POST',
      body: customerData,
    );

    print('Customer successfully edited.');
  }

  /// Vytvoření zákazníka
  static Future<String> createCustomer(
      Map<String, dynamic> customerData) async {
    final url = Uri.parse('$baseUrl/customer/create-customer');
    print('Creating Custumer: $url');

    final data = await _makeRequest(
      url,
      method: 'POST',
      body: customerData,
    );

    print('Customer successfully created.');
    return data['customerId'];
  }
}
