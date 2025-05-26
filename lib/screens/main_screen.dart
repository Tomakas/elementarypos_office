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
  final VoidCallback onApiKeyCleared; // <--- TENTO PARAMETR MUSÍ BÝT DEFINOVÁN

  const MainScreen({
    super.key,
    required this.updateApiKey,
    required this.onLanguageChange,
    required this.onApiKeyCleared, // <--- A ZDE V KONSTRUKTORU
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const DashboardScreen(),
      const ReceiptListScreen(),
      const ProductListScreen(),
      const CustomersScreen(),
      MenuScreen( // Při vytváření MenuScreen
        updateApiKey: widget.updateApiKey,
        onLanguageChange: widget.onLanguageChange,
        onApiKeyCleared: widget.onApiKeyCleared, // <--- PŘEDÁNÍ PARAMETRU ZDE (cca řádek 40)
      ),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
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