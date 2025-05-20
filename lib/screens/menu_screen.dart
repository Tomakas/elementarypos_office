// lib/screens/menu_screen.dart
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'settings_screen.dart';
import 'purchases_screen.dart'; // Ujistěte se, že tento import je správný

class MenuScreen extends StatelessWidget {
  final Future<void> Function(String) updateApiKey;
  final Function(Locale) onLanguageChange;

  const MenuScreen({
    super.key,
    required this.updateApiKey,
    required this.onLanguageChange,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    // ThemeData pro přístup k výchozím stylům, pokud bychom je chtěli použít
    // final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.translate('menuTitle'), // Ujistěte se, že máte tento klíč v .json souborech
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20.0, // Explicitní velikost pro sjednocení
          ),
        ),
        backgroundColor: Colors.grey[850],
        automaticallyImplyLeading: false, // Menu je hlavní záložka, nepotřebuje šipku zpět
        iconTheme: const IconThemeData(color: Colors.white), // Pro případné budoucí ikony v AppBar
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor, // Barva pozadí stejná jako jinde
        child: ListView(
          children: <Widget>[
            ListTile(
              leading: const Icon(
                Icons.shopping_cart,
                color: Colors.black54, // Barva pro ikony v seznamu (můžete upravit)
                size: 24.0, // Standardní velikost ikony
              ),
              title: Text(
                localizations.translate('menuPurchases'),
                style: const TextStyle(
                  fontSize: 16.0, // Standardní velikost textu pro položky seznamu
                  color: Colors.black87, // Barva textu (můžete upravit)
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PurchasesScreen()),
                );
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(
                Icons.settings,
                color: Colors.black54,
                size: 24.0,
              ),
              title: Text(
                localizations.translate('settingsTitle'),
                style: const TextStyle(
                  fontSize: 16.0,
                  color: Colors.black87,
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsScreen(
                      updateApiKey: updateApiKey,
                      onLanguageChange: onLanguageChange,
                    ),
                  ),
                );
              },
            ),
            // Zde můžete přidat další položky menu se stejným stylem
          ],
        ),
      ),
    );
  }
}