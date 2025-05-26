// lib/services/csv_import_service.dart
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/purchase_model.dart';
import '../models/ui_purchase_item_model.dart';
import '../models/product_model.dart';
import '../providers/product_provider.dart';

class CsvImportService {
  final Uuid _uuid = const Uuid();

  Future<({List<Purchase> purchasesToImport, Map<String, double> latestPurchasePricesByProductId})>
  processCsvData(String csvRawData, ProductProvider productProvider) async {
    List<Purchase> purchasesToImport = [];
    Map<String, double> latestPurchasePricesByProductId = {};
    Map<String, DateTime> lastDateByProductId = {};

    // <<== OPRAVA: Deklarace proměnné itemsGroupedByDate ZDE
    Map<DateTime, List<UIPurchaseItem>> itemsGroupedByDate = {};

    final lines = csvRawData.split('\n');

    // Kontrola pro prázdný soubor nebo soubor pouze s hlavičkou
    if (lines.isEmpty || lines.length <= 1) {
      // OPRAVA: Explicitní typování prázdných kolekcí
      return (
      purchasesToImport: <Purchase>[],
      latestPurchasePricesByProductId: <String, double>{}
      );
    }

    // Přeskočení hlavičky CSV (index 0)
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final columns = line.split(';');

      if (columns.length < 5) {
        print('Přeskakuji řádek CSV (nedostatek sloupců): $line');
        continue;
      }

      final String itemName = columns[0].trim();
      final String dateString = columns[1].trim();
      final String ncString = columns[3].trim();
      final String mKodString = columns[4].trim();

      DateTime? purchaseDate;
      try {
        purchaseDate = DateFormat('d.M.yyyy').parse(dateString);
      } catch (e) {
        print('Chyba parsování data "$dateString" na řádku: $line. Řádek bude přeskočen.');
        continue;
      }

      double? purchasePrice;
      try {
        String cleanedNcString = ncString.replaceAll('Kč', '').replaceAll(',', '.').trim();
        if (cleanedNcString.isNotEmpty) {
          purchasePrice = double.parse(cleanedNcString);
        }
      } catch (e) {
        print('Chyba parsování nákupní ceny "$ncString" pro produkt "$itemName". Cena bude null.');
        purchasePrice = null;
      }

      if (purchasePrice == null) {
        print('Produkt "$itemName" na řádku "$line" nemá platnou nákupní cenu. Řádek bude přeskočen pro tvorbu nákupu.');
        continue;
      }

      Product? foundProduct;
      if (mKodString.isNotEmpty) {
        final mKodInt = int.tryParse(mKodString);
        if (mKodInt != null) {
          try {
            foundProduct = productProvider.products.firstWhere(
                  (p) => p.code == mKodInt,
            );
          } catch (e) {
            // Produkt s tímto kódem nebyl nalezen
          }
        }
      }

      foundProduct ??= productProvider.getProductByName(itemName);

      if (foundProduct == null) {
        print('Produkt "$itemName" (mKod: "$mKodString") nebyl nalezen v ProductProvider. Položka bude přeskočena.');
        continue;
      }

      final String productIdValue = foundProduct.itemId;

      // Vytvoření UIPurchaseItem - nyní s productId
      final purchaseItem = UIPurchaseItem(
        id: _uuid.v4(),
        productId: productIdValue, // <<== PŘIDÁNO productId
        productName: foundProduct.itemName,
        quantity: 1.0,
        unitPrice: purchasePrice,
        totalItemPrice: purchasePrice,
      );

      // Seskupení položek podle data
      if (!itemsGroupedByDate.containsKey(purchaseDate)) {
        itemsGroupedByDate[purchaseDate] = [];
      }
      itemsGroupedByDate[purchaseDate]!.add(purchaseItem);

      // Aktualizace nejnovější nákupní ceny pro produkt
      if (!lastDateByProductId.containsKey(productIdValue) || purchaseDate.isAfter(lastDateByProductId[productIdValue]!)) {
        latestPurchasePricesByProductId[productIdValue] = purchasePrice;
        lastDateByProductId[productIdValue] = purchaseDate;
      } else if (purchaseDate.isAtSameMomentAs(lastDateByProductId[productIdValue]!) && purchasePrice > (latestPurchasePricesByProductId[productIdValue] ?? 0.0)) {
        latestPurchasePricesByProductId[productIdValue] = purchasePrice;
      }
        }

    int purchaseNumberCounter = 1;
    itemsGroupedByDate.forEach((date, items) {
      double overallTotalPrice = items.fold(0.0, (sum, item) => sum + (item.totalItemPrice ?? 0.0));

      final purchase = Purchase(
        id: _uuid.v4(),
        supplier: "Import z CSV",
        purchaseDate: date,
        purchaseNumber: "CSV-IMP-${purchaseNumberCounter.toString().padLeft(3, '0')}",
        notes: "Automaticky importováno z CSV.",
        items: items,
        overallTotalPrice: overallTotalPrice,
      );
      purchasesToImport.add(purchase);
      purchaseNumberCounter++;
    });

    purchasesToImport.sort((a, b) => a.purchaseDate.compareTo(b.purchaseDate));

    return (
    purchasesToImport: purchasesToImport,
    latestPurchasePricesByProductId: latestPurchasePricesByProductId
    );
  }
}