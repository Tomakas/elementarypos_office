//lib/providers/customer_provider.dart

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/customer_model.dart';

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
      customers =
          response.map<Customer>((json) => Customer.fromJson(json)).toList();

      print('Loaded Customers: ${customers.length}');
    } catch (e) {
      print('Error while loading (customers): $e');
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
      print('Loading details of Customer with ID: $customerId');
      selectedCustomer = await ApiService.fetchCustomerDetail(customerId);

      print('Details of Customer: $selectedCustomer');
    } catch (e) {
      print('Error while loading customer details: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Vytvoření nového zákazníka
  Future<void> createCustomer(Map<String, dynamic> customerData) async {
    try {
      print('Creating of new Customer');
      String customerId = await ApiService.createCustomer(customerData);
      print('New customer created with ID: $customerId');

      await fetchCustomers(); // Aktualizace seznamu zákazníků
    } catch (e) {
      print('Error while creating Customer: $e');
    }
  }

  /// Úprava existujícího zákazníka
  Future<void> editCustomer(Map<String, dynamic> customerData) async {
    try {
      print('Úprava zákazníka s ID: ${customerData['customerId']}');
      await ApiService.editCustomer(customerData);

      await fetchCustomers(); // Aktualizace seznamu zákazníků
    } catch (e) {
      print('Error while editing Customer: $e');
    }
  }
}
