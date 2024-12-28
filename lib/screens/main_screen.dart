import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';
import 'customers_screen.dart';
import '../providers/receipt_provider.dart';
import '../providers/product_provider.dart';
import '../l10n/app_localizations.dart';
import '../screens/product_list_screen.dart';
import '../screens/receipt_list_screen.dart';

class MainScreen extends StatefulWidget {
  final Future<void> Function(String) updateApiKey;
  final Function(Locale) onLanguageChange;

  const MainScreen({
    super.key,
    required this.updateApiKey,
    required this.onLanguageChange,
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
      SettingsScreen(
        updateApiKey: widget.updateApiKey,
        onLanguageChange: widget.onLanguageChange,
      ),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Refresh data when switching to specific tabs
    if (index == 1) {
      context.read<ReceiptProvider>().fetchReceipts();
    } else if (index == 2) {
      context.read<ProductProvider>().fetchProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      body: _screens[_selectedIndex],
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
            icon: const Icon(Icons.settings),
            label: localizations?.translate('settingsTitle'),
          ),
        ],
      ),
    );
  }
}