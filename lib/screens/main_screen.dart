// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'customers_screen.dart';
import '../l10n/app_localizations.dart';
import '../screens/product_list_screen.dart';
import '../screens/receipt_list_screen.dart';
import 'menu_screen.dart';

class MainScreen extends StatefulWidget {
  final Future<void> Function(String) updateApiKey;
  final Function(Locale) onLanguageChange;
  final VoidCallback onApiKeyCleared;

  const MainScreen({
    super.key,
    required this.updateApiKey,
    required this.onLanguageChange,
    required this.onApiKeyCleared,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    // Seznam obrazovek vytváříme zde, aby se parametr 'isSelected' správně
    // předával při každém překreslení (změně _selectedIndex)
    final List<Widget> screens = [
      DashboardScreen(isSelected: _selectedIndex == 0),
      ReceiptListScreen(isSelected: _selectedIndex == 1),
      ProductListScreen(isSelected: _selectedIndex == 2),
      CustomersScreen(isSelected: _selectedIndex == 3),
      MenuScreen(
        updateApiKey: widget.updateApiKey,
        onLanguageChange: widget.onLanguageChange,
        onApiKeyCleared: widget.onApiKeyCleared,
        // Pro MenuScreen pravděpodobně nepotřebujeme isSelected pro znovunačítání dat,
        // ale pokud bys chtěl konzistenci, mohl bys ho přidat i sem:
        // isSelected: _selectedIndex == 4,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.grey[850],
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard),
            label: localizations?.translate('dashboardTitle'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.receipt),
            label: localizations?.translate('salesTitle'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.shopping_bag),
            label: localizations?.translate('productsTitle'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.people),
            label: localizations?.translate('customersTitle'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.menu),
            label: localizations?.translate('menuMore'),
          ),
        ],
      ),
    );
  }
}