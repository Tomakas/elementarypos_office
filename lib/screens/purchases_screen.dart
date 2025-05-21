// lib/screens/purchases_screen.dart
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'add_purchase_screen.dart'; // Import obrazovky pro přidání nákupu

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  // Zde bude později logika pro načítání a zobrazení seznamu nákupů

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
        iconTheme: const IconThemeData(color: Colors.white),
        // Pokud je tato obrazovka volána z MenuScreen (která je v BottomNav),
        // a chceme konzistentní chování (žádná šipka zpět, pokud je to "hlavní" pohled sekce Nákupy),
        // můžeme zvážit automaticallyImplyLeading: false.
        // Ale protože se na ni navigujeme přes Navigator.push() z MenuScreen,
        // šipka zpět je zde očekávaná a korektní.
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        // Zatím jednoduchý placeholder, později zde bude ListView s nákupy
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                localizations.translate('purchasesListWillAppearHere'), // Ujistěte se, že tento klíč máte
                style: const TextStyle(fontSize: 18.0, color: Colors.black54),
              ),
              // Původní ElevatedButton můžeme odstranit, pokud FAB je preferovaný
              /*
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_shopping_cart),
                label: Text(localizations.translate('newPurchaseTitle')),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddPurchaseScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              )
              */
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPurchaseScreen()),
          );
        },
        backgroundColor: Colors.grey[850], // Stejná barva jako v Product/Customer screens
        tooltip: localizations.translate('newPurchaseTitle'), // Použijeme existující klíč
        child: const Icon(Icons.add, color: Colors.white), // Ikona a její barva
      ),
    );
  }
}