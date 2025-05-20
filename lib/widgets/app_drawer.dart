// lib/widgets/app_drawer.dart
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../screens/purchases_screen.dart'; // Import nové obrazovky

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.grey[850], // Stejná barva jako AppBar
            ),
            child: Text(
              localizations.translate('appTitle'), // Můžete změnit na jiný název menu
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.shopping_cart), // Příklad ikony
            title: Text(localizations.translate('menuPurchases')),
            onTap: () {
              Navigator.pop(context); // Zavře Drawer
              // Navigace na PurchasesScreen
              // Je lepší se ujistit, že nepushujeme stejnou obrazovku vícekrát,
              // ale pro jednoduchost zatím takto:
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PurchasesScreen()),
              );
            },
          ),
          // Zde můžete přidat další položky menu v budoucnu
          // Např. Divider(), ListTile(...),
        ],
      ),
    );
  }
}