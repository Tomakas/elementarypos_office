// lib/screens/menu_screen.dart
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'settings_screen.dart';
import 'purchases_screen.dart'; // Ujistěte se, že tento import je správný

class MenuScreen extends StatelessWidget {
  final Future<void> Function(String) updateApiKey;
  final Function(Locale) onLanguageChange;
  final VoidCallback onApiKeyCleared; // NOVĚ PŘIDANÝ POVINNÝ PARAMETR

  const MenuScreen({
    super.key,
    required this.updateApiKey,
    required this.onLanguageChange,
    required this.onApiKeyCleared, // NOVĚ PŘIDANÝ POVINNÝ PARAMETR
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.translate('menuTitle'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20.0,
          ),
        ),
        backgroundColor: Colors.grey[850],
        automaticallyImplyLeading: false, // Důležité, pokud nechceme zpětnou šipku
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: ListView(
          children: <Widget>[
            ListTile(
              leading: const Icon(
                Icons.shopping_cart,
                color: Colors.black54,
                size: 24.0,
              ),
              title: Text(
                localizations.translate('menuPurchases'),
                style: const TextStyle(
                  fontSize: 16.0,
                  color: Colors.black87,
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
              onTap: () { // Toto je přibližně řádek 47, na který ukazuje druhá chyba
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsScreen(
                      updateApiKey: updateApiKey, // Přistupuje k 'this.updateApiKey'
                      onLanguageChange: onLanguageChange, // Přistupuje k 'this.onLanguageChange'
                      onApiKeyCleared: onApiKeyCleared, // Přistupuje k 'this.onApiKeyCleared'
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}