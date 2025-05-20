// lib/screens/purchases_screen.dart
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class PurchasesScreen extends StatelessWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.translate('purchasesTitle'),
          style: const TextStyle(color: Colors.white, fontSize: 20.0),
        ),
        backgroundColor: Colors.grey[850],
        iconTheme: const IconThemeData(color: Colors.white), // Pro bílou šipku zpět
        // titleTextStyle je redundantní, pokud stylujeme přímo Text widget
      ),
      body: Container( // Přidán Container pro nastavení barvy pozadí
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: Text(
            localizations.translate('purchasesTitle'),
            style: const TextStyle(fontSize: 18.0, color: Colors.black87), // Příklad stylu pro obsah
          ),
        ),
      ),
    );
  }
}