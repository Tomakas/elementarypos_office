// lib/screens/purchases_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/purchase_provider.dart';
import '../models/purchase_model.dart';
import '../services/utility_services.dart';
import 'add_purchase_screen.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {

  // initState může zůstat prázdný, protože provider se načítá ve svém konstruktoru
  // a Consumer by měl reagovat na následné změny.

  void _showPurchaseDetailDialog(BuildContext context, Purchase purchase, AppLocalizations localizations) {
    // ... (kód pro dialog zůstává stejný)
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('${localizations.translate('purchaseNumber')}: ${purchase.purchaseNumber ?? localizations.translate('notAvailable')}'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('${localizations.translate('supplier')}: ${purchase.supplier ?? localizations.translate('notAvailable')}'),
                Text('${localizations.translate('purchaseDate')}: ${DateFormat('dd.MM.yyyy').format(purchase.purchaseDate)}'),
                Text('${localizations.translate('totalPurchasePrice')}: ${Utility.formatCurrency(purchase.overallTotalPrice, currencySymbol: localizations.translate('currency'))}'),
                if (purchase.notes != null && purchase.notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('${localizations.translate('notes')}: ${purchase.notes}'),
                  ),
                const SizedBox(height: 16),
                Text(localizations.translate('purchaseItems'), style: TextStyle(fontWeight: FontWeight.bold)),
                const Divider(),
                if (purchase.items.isEmpty)
                  Text(localizations.translate('noItemsAddedYet')),
                ...purchase.items.map((item) {
                  if (item.unitPrice == null && item.totalItemPrice != null && item.quantity > 0) {
                    item.calculatePrices();
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${item.productName} (${item.quantity}x)', style: TextStyle(fontWeight: FontWeight.w500)),
                        Text('  ${localizations.translate('totalItemPrice')}: ${Utility.formatCurrency(item.totalItemPrice ?? 0, currencySymbol: '', decimals: 2)} (${localizations.translate('unitPrice')}: ${Utility.formatCurrency(item.unitPrice ?? 0, currencySymbol: '', decimals: 2)})'),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          actions: <Widget>[
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
    // Místo přímého volání Provider.of zde, použijeme Consumer níže

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.translate('purchasesTitle'),
          style: const TextStyle(color: Colors.white, fontSize: 20.0),
        ),
        backgroundColor: Colors.grey[850],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // Použijeme Consumer widget pro naslouchání změnám v PurchaseProvider
      body: Consumer<PurchaseProvider>(
        builder: (ctx, purchaseProvider, child) { // ctx je nový kontext z Consumeru
          return Container(
            color: Theme.of(ctx).scaffoldBackgroundColor, // Použij ctx pro Theme
            child: purchaseProvider.isLoading && purchaseProvider.purchases.isEmpty // Zobrazit loader jen pokud se načítá a nejsou žádná data
                ? const Center(child: CircularProgressIndicator())
                : purchaseProvider.purchases.isEmpty
                ? Center(
              child: Text(
                localizations.translate('noPurchasesAvailable'),
                style: const TextStyle(fontSize: 18.0, color: Colors.black54),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: purchaseProvider.purchases.length,
              itemBuilder: (listViewCtx, i) { // listViewCtx je kontext pro itemBuilder
                final purchase = purchaseProvider.purchases[i];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 5.0),
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
                        Text('${localizations.translate('purchaseDate')}: ${DateFormat('dd.MM.yyyy').format(purchase.purchaseDate)}'),
                        Text('${localizations.translate('purchaseNumber')}: ${purchase.purchaseNumber?.isNotEmpty == true ? purchase.purchaseNumber : localizations.translate('notAvailable')}'),
                        Text('${localizations.translate('itemsCount')}: ${purchase.items.length}'),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          Utility.formatCurrency(purchase.overallTotalPrice, currencySymbol: localizations.translate('currency')),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green[700]),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.delete, size: 20, color: Colors.red),
                              tooltip: localizations.translate('delete'),
                              onPressed: () {
                                showDialog(
                                  context: ctx, // Použij ctx z Consumeru
                                  builder: (ctxDel) => AlertDialog(
                                    title: Text(localizations.translate('confirmDelete')),
                                    content: Text(localizations.translate('confirmDeletePurchase')),
                                    actions: <Widget>[
                                      TextButton(
                                        child: Text(localizations.translate('cancel')),
                                        onPressed: () => Navigator.of(ctxDel).pop(false),
                                      ),
                                      TextButton(
                                        child: Text(localizations.translate('delete')),
                                        onPressed: () => Navigator.of(ctxDel).pop(true),
                                      ),
                                    ],
                                  ),
                                ).then((confirmed) {
                                  if (confirmed == true) {
                                    // Není potřeba listen: false, protože jsme mimo build metodu Consumeru
                                    // ale pro jistotu a konzistenci s AddPurchaseScreen to můžeme přidat
                                    Provider.of<PurchaseProvider>(ctx, listen: false).deletePurchase(purchase.id);
                                  }
                                });
                              },
                            ),
                          ],
                        )
                      ],
                    ),
                    onTap: () {
                      _showPurchaseDetailDialog(ctx, purchase, localizations); // Použij ctx z Consumeru
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context, // Zde je context z build metody PurchasesScreen v pořádku
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