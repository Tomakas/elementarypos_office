//lib/providers/customer_provider.dart

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/utility_services.dart';
import '../models/customer.dart';

class CustomerProvider extends ChangeNotifier {
  String? apiKey;
  List<Customer> customers = [];
  Map<String, dynamic>? selectedCustomer;
  bool isLoading = false;

  CustomerProvider(this.apiKey);

  /// Načtení seznamu zákazníků z API
  Future<void> fetchCustomers() async {
    isLoading = true;
    notifyListeners();

    try {
      apiKey = await StorageService.getApiKey();
      if (apiKey == null || apiKey!.isEmpty) {
        print('Chyba: API klíč není zadán.');
        return;
      }

      // Načtení dat z API
      final List<Map<String, dynamic>> response =
      await ApiService.fetchCustomers(apiKey!);

      // Převod z List<Map<String, dynamic>> na List<Customer>
      customers = response.map<Customer>((json) => Customer.fromJson(json)).toList();

      print('Načteno zákazníků: ${customers.length}');
    } catch (e) {
      print('Chyba při načítání zákazníků: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }


  /// Načtení detailu konkrétního zákazníka
  Future<void> fetchCustomerDetail(String customerId) async {
    isLoading = true;
    notifyListeners();

    try {
      apiKey = await StorageService.getApiKey();
      if (apiKey == null || apiKey!.isEmpty) {
        print('Chyba: API klíč není zadán.');
        return;
      }

      print('Načítání detailu zákazníka s ID: $customerId');
      selectedCustomer =
          await ApiService.fetchCustomerDetail(apiKey!, customerId);

      print('Detail zákazníka: $selectedCustomer');
    } catch (e) {
      print('Chyba při načítání detailu zákazníka: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Vytvoření nového zákazníka
  Future<void> createCustomer(Map<String, dynamic> customerData) async {
    try {
      apiKey = await StorageService.getApiKey();
      if (apiKey == null || apiKey!.isEmpty) {
        print('Chyba: API klíč není zadán.');
        return;
      }

      print('Vytváření nového zákazníka');
      String customerId =
          await ApiService.createCustomer(apiKey!, customerData);
      print('Nový zákazník vytvořen s ID: $customerId');

      await fetchCustomers(); // Aktualizace seznamu zákazníků
    } catch (e) {
      print('Chyba při vytváření zákazníka: $e');
    }
  }

  /// Úprava existujícího zákazníka
  Future<void> editCustomer(Map<String, dynamic> customerData) async {
    try {
      apiKey = await StorageService.getApiKey();
      if (apiKey == null || apiKey!.isEmpty) {
        print('Chyba: API klíč není zadán.');
        return;
      }

      print('Úprava zákazníka s ID: ${customerData['customerId']}');
      await ApiService.editCustomer(apiKey!, customerData);

      await fetchCustomers(); // Aktualizace seznamu zákazníků
    } catch (e) {
      print('Chyba při úpravě zákazníka: $e');
    }
  }

  /// Nastavení API klíče a načtení zákazníků
  void setApiKey(String newApiKey) {
    apiKey = newApiKey;
    notifyListeners();
    fetchCustomers();
  }
}
