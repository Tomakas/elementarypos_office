// lib/services/api_service.dart

import 'dart:convert';
import 'dart:async';
import 'dart:io'; // Potřeba pro SocketException a HttpException [cite: 966]
import 'package:http/http.dart' as http;
import '../models/product_model.dart'; // [cite: 966]
import '../services/utility_services.dart'; // Pro StorageService [cite: 966]

class ApiService {
  static const String baseUrl = 'https://api.elementarypos.com/v1'; // [cite: 966]
  static const Duration requestTimeout = Duration(seconds: 20); // Mírně navýšený timeout pro případ delšího načítání stránek

  /// Generická metoda pro HTTP požadavky
  static Future<dynamic> _makeRequest(
      Uri url, {
        String method = 'GET',
        Map<String, String>? headers,
        dynamic body,
      }) async {
    final storedApiKey = await StorageService.getApiKey(); // [cite: 967]
    if (storedApiKey == null || storedApiKey.isEmpty) { // [cite: 968]
      print('Error: API key not available.'); // [cite: 968]
      // V reálné aplikaci by zde měla být robustnější chybová logika, např. vyhození specifické výjimky
      throw Exception('API key is missing. Please configure it in settings.');
    }

    final defaultHeaders = {
      'accept': 'application/json', // [cite: 970]
      'Content-Type': 'application/json', // [cite: 970]
    };
    final combinedHeaders = { // [cite: 971]
      ...defaultHeaders,
      if (headers != null) ...headers,
      'X-Api-Key': storedApiKey, // [cite: 971]
    };

    http.Response response;

    try {
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http
              .get(url, headers: combinedHeaders)
              .timeout(requestTimeout); // [cite: 972]
          break;
        case 'POST':
          response = await http
              .post(url, headers: combinedHeaders, body: json.encode(body))
              .timeout(requestTimeout); // [cite: 973]
          break;
        default:
          throw UnsupportedError('HTTP method $method is not supported.'); // [cite: 974]
      }

      print('API Call: ${method.toUpperCase()} $url'); // Logování URL a metody
      print('API Status: ${response.statusCode}'); // [cite: 975]
      // Pro debugování může být užitečné logovat i tělo odpovědi, ale pro produkci zvažte jeho odstranění nebo omezení.
      // print('API Response Body: ${response.body}'); [cite: 976]

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Použití utf8.decode pro správné zpracování českých znaků
        return json.decode(utf8.decode(response.bodyBytes)); // [cite: 977]
      } else {
        // Zkusíme dekódovat chybovou zprávu, pokud existuje
        String errorMessage = response.body;
        try {
          final errorJson = json.decode(utf8.decode(response.bodyBytes));
          if (errorJson['message'] != null) {
            errorMessage = errorJson['message'];
          }
        } catch (_) {
          // Pokud tělo není validní JSON nebo neobsahuje 'message', použijeme celé tělo
        }
        throw HttpException(
            'Request error on $url: ${response.statusCode} - $errorMessage'); // [cite: 978]
      }
    } on SocketException {
      print('Error: Server is unavailable for $url');
      throw const SocketException('Server is unavailable or no internet connection.'); // [cite: 979]
    } on HttpException catch (e) {
      print('HttpException for $url: ${e.message}');
      throw HttpException(e.message); // [cite: 980]
    } on FormatException {
      print('Error: Wrong response format for $url');
      throw const FormatException('Wrong response format from server.'); // [cite: 981]
    } on TimeoutException {
      print('Error: Request timeout for $url');
      throw TimeoutException('The request to the server timed out.'); // [cite: 982]
    } catch (e) {
      print('Unknown error for $url: $e');
      throw Exception('An unknown error occurred: $e'); // [cite: 983]
    }
  }

  /// Načtení VŠECH účtenek s využitím paginace
  static Future<List<dynamic>> fetchReceipts(
      String dateFrom, String dateTo, {int initialLimit = 500}) async {
    List<dynamic> allReceipts = [];
    int currentPage = 0;
    bool hasMorePages = true;
    // API dokumentace uvádí default limit 100, maximum může být 500.
    // Pro co nejméně requestů použijeme 500.
    int requestLimit = 500;


    print('API call for ALL Receipts: dateFrom=$dateFrom, dateTo=$dateTo, limitPerRequest=$requestLimit');

    while (hasMorePages) {
      final url = Uri.parse(
          '$baseUrl/receipt/receipts?dateFrom=$dateFrom&dateTo=$dateTo&limit=$requestLimit&page=$currentPage');
      // Logování URL pro každou stránku není v _makeRequest, tak ho přidáme sem
      // print('Fetching page: $currentPage with limit: $requestLimit, URL: $url');

      try {
        final data = await _makeRequest(
          url,
          method: 'GET',
        );
        List<dynamic> fetchedReceipts = data['receipts'] ?? []; // [cite: 986]

        if (fetchedReceipts.isNotEmpty) {
          allReceipts.addAll(fetchedReceipts);
          print('Page $currentPage fetched successfully, ${fetchedReceipts.length} receipts. Total so far: ${allReceipts.length}');
          // Pokud API vrátilo méně účtenek než byl limit, pravděpodobně jsme na poslední stránce
          if (fetchedReceipts.length < requestLimit) {
            hasMorePages = false;
            print('Last page likely fetched (received ${fetchedReceipts.length} items, limit was $requestLimit).');
          } else {
            currentPage++; // Připravit se na další stránku
          }
        } else {
          hasMorePages = false; // Žádné další účtenky, konec paginace
          print('No more receipts found on page $currentPage (empty list returned).');
        }
      } catch (e) {
        print('Error fetching receipts on page $currentPage: $e');
        // Zde můžete implementovat logiku pro opakování pokusu nebo přerušení
        hasMorePages = false; // Přerušení v případě chyby na aktuální stránce
        // Můžete zvážit rethrow e; pokud chcete chybu zpracovat výše a informovat uživatele
        throw e; // Nebo jednoduše vyhodit chybu dál, aby ji zachytil provider
      }

      // Bezpečnostní pojistka proti nekonečné smyčce, pokud by API mělo neočekávané chování.
      // Např. pokud by API při chybě vracelo stále stejná data místo prázdného seznamu.
      if (currentPage > 1000) { // Limit 1000 stránek (tj. 500 000 účtenek při limitu 500)
        print("WARN: Reached page limit (1000), stopping pagination to prevent potential infinite loop.");
        hasMorePages = false;
      }
    }
    print('Finished fetching all receipts. Total count: ${allReceipts.length}');
    return allReceipts;
  }


  /// Načtení kategorií
  static Future<List<Map<String, dynamic>>> fetchCategories() async {
    final url = Uri.parse('$baseUrl/category/get-categories'); // [cite: 987]
    final data = await _makeRequest(
      url,
      method: 'POST', // [cite: 987]
    );
    return List<Map<String, dynamic>>.from(data['categories'] ?? []); // [cite: 988]
  }

  /// Načtení produktů
  static Future<List<Product>> fetchProducts({
    String? filterCategoryId,
    String? filterCategoryName,
    int? filterColor,
  }) async {
    final url = Uri.parse('$baseUrl/item/get-sales-items'); // [cite: 989]
    final body = { // [cite: 989]
      'filterCategoryId': filterCategoryId,
      'filterCategoryName': filterCategoryName,
      'filterColor': filterColor,
    };
    final data = await _makeRequest(
      url,
      method: 'POST', // [cite: 990]
      body: body, // [cite: 990]
    );
    return (data['items'] as List) // [cite: 991]
        .map((item) => Product.fromJson(item)) // [cite: 991]
        .toList(); // [cite: 991]
  }

  /// Načtení stavu skladu
  static Future<List<Map<String, dynamic>>> fetchActualStockData() async {
    final url = Uri.parse('$baseUrl/stock/get-actual-stock-data'); // [cite: 993]
    final data = await _makeRequest(
      url,
      method: 'POST', // [cite: 993]
    );
    return List<Map<String, dynamic>>.from(data['list'] ?? []); // [cite: 994]
  }

  /// Přidání produktu
  /// Vrací ID nově vytvořeného produktu z odpovědi API.
  static Future<String> addProduct(Product product) async {
    final url = Uri.parse('$baseUrl/item/add-sale-item'); // [cite: 995]
    final productJson = product.toJson(); // [cite: 995]
    // Logování JSON těla může být užitečné, ale pozor na citlivá data v produkci
    // print('Adding product - JSON request body: $productJson'); [cite: 995]
    final responseData = await _makeRequest(
      url,
      method: 'POST', // [cite: 996]
      body: productJson, // [cite: 996]
    );
    print('Product successfully added.'); // [cite: 997]
    // Očekáváme, že API vrátí 'itemId' nově vytvořeného produktu
    if (responseData != null && responseData['itemId'] != null) {
      return responseData['itemId'] as String;
    } else {
      print('Warning: addProduct API did not return itemId.');
      // Pokud API nevrátí ID, můžeme vrátit prázdný string nebo vyhodit výjimku,
      // v závislosti na tom, jak to chceme zpracovat dál.
      // Prozatím vrátíme prázdný řetězec, ale provider by měl být připraven na to,
      // že ID nemusí být ihned k dispozici a produkt bude nutné znovu načíst pro získání ID.
      return '';
    }
  }


  /// Úprava produktu
  static Future<void> editProduct(Product product) async {
    final url = Uri.parse('$baseUrl/item/edit-sale-item'); // [cite: 998]
    final productJson = product.toJson(); // [cite: 998]
    // print('Editing product - JSON request body: $productJson'); [cite: 998]
    await _makeRequest(
      url,
      method: 'POST', // [cite: 999]
      body: productJson, // [cite: 999]
    );
    print('Product successfully edited.'); // [cite: 1000]
  }

  /// Smazání produktu
  static Future<void> deleteProduct(String itemId) async {
    final url = Uri.parse('$baseUrl/item/delete-sale-item'); // [cite: 1001]
    final body = {'itemId': itemId}; // [cite: 1001]

    await _makeRequest(
      url,
      method: 'POST', // [cite: 1001]
      body: body,
    );
    print('Product successfully deleted.'); // [cite: 1002]
  }

  /// Načtení daňových sazeb
  static Future<List<Map<String, dynamic>>> fetchTaxSettings() async {
    final url = Uri.parse('$baseUrl/tax/get-tax-settings'); // [cite: 1003]
    final data = await _makeRequest(
      url,
      method: 'POST', // [cite: 1003]
    );
    final taxes = List<Map<String, dynamic>>.from(data['taxes'] ?? []); // [cite: 1004]
    return taxes.where((tax) => tax['deleted'] == false).toList(); // [cite: 1004]
  }

  /// Načtení zákazníků
  static Future<List<Map<String, dynamic>>> fetchCustomers() async {
    final url = Uri.parse('$baseUrl/customer/get-customers'); // [cite: 1006]
    final data = await _makeRequest(
      url,
      method: 'POST', // [cite: 1006]
    );
    return List<Map<String, dynamic>>.from(data['customers'] ?? []); // [cite: 1007]
  }

  /// Načtení detailu zákazníka
  static Future<Map<String, dynamic>> fetchCustomerDetail(
      String customerId) async {
    final url = Uri.parse('$baseUrl/customer/get-customer'); // [cite: 1008]
    final body = {'customerId': customerId}; // [cite: 1008]
    final data = await _makeRequest(
      url,
      method: 'POST', // [cite: 1009]
      body: body, // [cite: 1009]
    );
    return data; // [cite: 1010]
  }

  /// Úprava zákazníka
  static Future<void> editCustomer(Map<String, dynamic> customerData) async {
    final url = Uri.parse('$baseUrl/customer/edit-customer'); // [cite: 1011]
    await _makeRequest(
      url,
      method: 'POST', // [cite: 1011]
      body: customerData, // [cite: 1011]
    );
    print('Customer successfully edited.'); // [cite: 1012]
  }

  /// Vytvoření zákazníka
  static Future<String> createCustomer(
      Map<String, dynamic> customerData) async {
    final url = Uri.parse('$baseUrl/customer/create-customer'); // [cite: 1013]
    final data = await _makeRequest(
      url,
      method: 'POST', // [cite: 1013]
      body: customerData, // [cite: 1013]
    );
    print('Customer successfully created.'); // [cite: 1014]
    return data['customerId']; // [cite: 1014]
  }
}