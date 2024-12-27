//lib/providers/customer_provider.dart

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/customer.dart';

class CustomerProvider extends ChangeNotifier {
  List<Customer> customers = [];
  Map<String, dynamic>? selectedCustomer;
  bool isLoading = false;

  CustomerProvider();

  /// Načtení seznamu zákazníků
  Future<void> fetchCustomers() async {
    isLoading = true;
    notifyListeners();

    try {
      final List<Map<String, dynamic>> response =
      await ApiService.fetchCustomers();

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

      print('Načítání detailu zákazníka s ID: $customerId');
      selectedCustomer =
          await ApiService.fetchCustomerDetail(customerId);

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
      print('Vytváření nového zákazníka');
      String customerId =
          await ApiService.createCustomer(customerData);
      print('Nový zákazník vytvořen s ID: $customerId');

      await fetchCustomers(); // Aktualizace seznamu zákazníků
    } catch (e) {
      print('Chyba při vytváření zákazníka: $e');
    }
  }

  /// Úprava existujícího zákazníka
  Future<void> editCustomer(Map<String, dynamic> customerData) async {
    try {
      print('Úprava zákazníka s ID: ${customerData['customerId']}');
      await ApiService.editCustomer(customerData);

      await fetchCustomers(); // Aktualizace seznamu zákazníků
    } catch (e) {
      print('Chyba při úpravě zákazníka: $e');
    }
  }
}