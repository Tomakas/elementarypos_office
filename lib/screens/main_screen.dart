// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
// SettingsScreen se nyní bude volat z MenuScreen
// import 'settings_screen.dart';
import 'customers_screen.dart';
import '../l10n/app_localizations.dart';
import '../screens/product_list_screen.dart';
import '../screens/receipt_list_screen.dart';
import 'menu_screen.dart'; // <-- Import nové MenuScreen

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
      // Pátá obrazovka bude nyní MenuScreen
      MenuScreen(
        updateApiKey: widget.updateApiKey, // Předání parametrů
        onLanguageChange: widget.onLanguageChange,
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
      // AppBar se již nebude definovat zde, ale v každé jednotlivé obrazovce (Dashboard, Receipts, atd.)
      // Drawer také nebude zde, protože jej nahrazuje MenuScreen
      body: IndexedStack( // IndexedStack zachovává stav jednotlivých obrazovek
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
          // Změna páté položky
          BottomNavigationBarItem(
            icon: const Icon(Icons.menu), // Ikona pro Menu
            label: localizations?.translate('menuMore'), // Nový lokalizační klíč pro "Více" nebo "Menu"
          ),
        ],
      ),
    );
  }
}