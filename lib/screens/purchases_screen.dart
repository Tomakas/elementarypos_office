// lib/screens/purchases_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/purchase_provider.dart';
import '../models/purchase_model.dart';
import '../services/utility_services.dart';
import 'add_purchase_screen.dart'; // Tento import bude klíčový pro úpravu

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  // Metoda pro zobrazení potvrzovacího dialogu smazání
  Future<void> _confirmDeletePurchase(
      BuildContext dialogContext, // Kontext dialogu s detailem
      Purchase purchase,
      AppLocalizations localizations,
      PurchaseProvider purchaseProvider) async {
    final bool? confirmed = await showDialog<bool>(
      context: dialogContext, // Používáme kontext dialogu, aby se zobrazil nad ním
      builder: (BuildContext confirmDialogContext) {
        return AlertDialog(
          title: Text(localizations.translate('confirmDelete')),
          content: Text(localizations.translate('confirmDeletePurchase')),
          actions: <Widget>[
            TextButton(
              child: Text(localizations.translate('cancel')),
              onPressed: () => Navigator.of(confirmDialogContext).pop(false),
            ),
            TextButton(
              child: Text(localizations.translate('delete')),
              onPressed: () => Navigator.of(confirmDialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await purchaseProvider.deletePurchase(purchase.id);
        // Není potřeba volat Navigator.pop(dialogContext) zde,
        // protože zavřeme původní dialog až po úspěšném smazání z dialogu s detailem.
        ScaffoldMessenger.of(dialogContext).showSnackBar( // Můžeme použít i context, pokud je dialog již zavřený
          SnackBar(content: Text(localizations.translate('purchaseDeletedSuccess'))), // Přidej si tento klíč do lokalizace
        );
        Navigator.of(dialogContext).pop(); // Zavřeme dialog s detailem nákupu
      } catch (e) {
        print("Chyba při mazání nákupu: $e");
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          SnackBar(content: Text(localizations.translate('errorDeletingPurchase'))), // Přidej si tento klíč
        );
      }
    }
  }

  void _showPurchaseDetailDialog(
      BuildContext context, // Kontext obrazovky PurchasesScreen
      Purchase purchase,
      AppLocalizations localizations,
      PurchaseProvider purchaseProvider) { // Přidán purchaseProvider
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) { // Kontext specifický pro tento dialog
        return AlertDialog(
          title: Text(
              '${localizations.translate('purchaseNumber')}: ${purchase.purchaseNumber ?? localizations.translate('notAvailable')}'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                    '${localizations.translate('supplier')}: ${purchase.supplier ?? localizations.translate('notAvailable')}'),
                Text(
                    '${localizations.translate('purchaseDate')}: ${DateFormat('dd.MM.yyyy').format(purchase.purchaseDate)}'),
                Text(
                    '${localizations.translate('totalPurchasePrice')}: ${Utility.formatCurrency(purchase.overallTotalPrice, currencySymbol: localizations.translate('currency'))}'),
                if (purchase.notes != null && purchase.notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                        '${localizations.translate('notes')}: ${purchase.notes}'),
                  ),
                const SizedBox(height: 16),
                Text(localizations.translate('purchaseItems'),
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Divider(),
                if (purchase.items.isEmpty)
                  Text(localizations.translate('noItemsAddedYet')),
                ...purchase.items.map((item) {
                  if (item.unitPrice == null &&
                      item.totalItemPrice != null &&
                      item.quantity > 0) {
                    item.calculatePrices();
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${item.productName} (${item.quantity}x)',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        Text(
                            '  ${localizations.translate('totalItemPrice')}: ${Utility.formatCurrency(item.totalItemPrice ?? 0, currencySymbol: '', decimals: 2)} (${localizations.translate('unitPrice')}: ${Utility.formatCurrency(item.unitPrice ?? 0, currencySymbol: '', decimals: 2)})'),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(localizations.translate('edit')),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Zavřít detail dialog
                Navigator.push(
                  context, // Použít kontext z PurchasesScreen pro navigaci
                  MaterialPageRoute(
                    builder: (context) => AddPurchaseScreen(purchaseToEdit: purchase), // Předání nákupu k úpravě
                  ),
                );
              },
            ),
            TextButton(
              child: Text(localizations.translate('delete'), style: TextStyle(color: Colors.red)),
              onPressed: () {
                // Zavoláme potvrzovací dialog
                _confirmDeletePurchase(dialogContext, purchase, localizations, purchaseProvider);
                // Původní dialog s detailem se zavře až po potvrzení a úspěšném smazání
              },
            ),
            TextButton(
              child: Text(localizations.translate('close')),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    // Získání PurchaseProvider zde, abychom ho mohli předat do _showPurchaseDetailDialog
    final purchaseProvider = Provider.of<PurchaseProvider>(context);


    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.translate('purchasesTitle'),
          style: const TextStyle(color: Colors.white, fontSize: 20.0),
        ),
        backgroundColor: Colors.grey[850],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Consumer<PurchaseProvider>( // Consumer zůstává pro rebuild UI
        builder: (ctx, consumerPurchaseProvider, child) { // consumerPurchaseProvider je instance z Consumeru
          return Container(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            child: consumerPurchaseProvider.isLoading && consumerPurchaseProvider.purchases.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : consumerPurchaseProvider.purchases.isEmpty
                ? Center(
              child: Text(
                localizations.translate('noPurchasesAvailable'),
                style: const TextStyle(
                    fontSize: 18.0, color: Colors.black54),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: consumerPurchaseProvider.purchases.length,
              itemBuilder: (listViewCtx, i) {
                final purchase = consumerPurchaseProvider.purchases[i];
                return Card(
                  margin: const EdgeInsets.symmetric(
                      vertical: 6.0, horizontal: 5.0),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12.0),
                    leading: CircleAvatar(
                      child: Text((i + 1).toString()),
                    ),
                    title: Text(
                      '${localizations.translate('supplier')}: ${purchase.supplier ?? localizations.translate('notAvailable')}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${localizations.translate('purchaseDate')}: ${DateFormat('dd.MM.yyyy').format(purchase.purchaseDate)}'),
                        Text(
                            '${localizations.translate('purchaseNumber')}: ${purchase.purchaseNumber?.isNotEmpty == true ? purchase.purchaseNumber : localizations.translate('notAvailable')}'),
                        Text(
                            '${localizations.translate('itemsCount')}: ${purchase.items.length}'),
                      ],
                    ),
                    trailing: Column( // ODSTRANĚNO TLAČÍTKO SMAZAT Z TRAILING
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          Utility.formatCurrency(
                              purchase.overallTotalPrice,
                              currencySymbol: localizations
                                  .translate('currency')),
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green[700]),
                        ),
                        // Prázdný SizedBox pro zachování layoutu, pokud bylo tlačítko jediné v Row
                        // Pokud by text byl jediný, toto není nutné.
                        // const SizedBox(height: 24), // Výška původního IconButtonu
                      ],
                    ),
                    onTap: () {
                      // Předáváme instanci providera získanou výše (mimo Consumer buildera)
                      _showPurchaseDetailDialog(ctx, purchase, localizations, purchaseProvider);
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'purchasesScreenFAB', // Přidán Hero Tag
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPurchaseScreen()),
          );
        },
        backgroundColor: Colors.grey[850],
        tooltip: localizations.translate('newPurchaseTitle'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}