// lib/services/csv_import_service.dart
import 'package:flutter/services.dart'; // Pro rootBundle, pokud bychom načítali zde
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
    Map<String, DateTime> lastDateByProductId = {}; // Pro sledování data poslední ceny

    // Dočasná mapa pro seskupení položek podle data a následně podle dodavatele (pro jednoduchost CSV importu teď jen podle data)
    Map<DateTime, List<UIPurchaseItem>> itemsGroupedByDate = {};

    final lines = csvRawData.split('\n');
    if (lines.isEmpty) {
      return (purchasesToImport: [], latestPurchasePricesByProductId: {});
    }

    // Přeskočení hlavičky CSV
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final columns = line.split('\t'); // Předpokládáme oddělovač tabulátor

      if (columns.length < 5) {
        print('Přeskakuji řádek CSV (nedostatek sloupců): $line');
        continue;
      }

      final String itemName = columns[0].trim();
      final String dateString = columns[1].trim();
      // PC (sloupec 2) ignorujeme
      final String ncString = columns[3].trim(); // Nákupní cena
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
        // Můžeme pokračovat s cenou null, nebo řádek přeskočit, podle preferencí.
        // Prozatím pokračujeme s cenou null, pokud ji nelze naparsovat.
        // Pokud je NC povinná, měli bychom zde `continue;`
      }

      if (purchasePrice == null) {
        print('Produkt "$itemName" na řádku "$line" nemá platnou nákupní cenu. Řádek bude přeskočen pro tvorbu nákupu.');
        continue;
      }

      // Najít produkt pomocí mKodu (předpokládáme, že mKod je Product.code)
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

      // Pokud se nenajde podle mKodu, zkusíme podle názvu (méně spolehlivé)
      if (foundProduct == null) {
        foundProduct = productProvider.getProductByName(itemName);
      }

      if (foundProduct == null) {
        print('Produkt "$itemName" (mKod: "$mKodString") nebyl nalezen v ProductProvider. Položka bude přeskočena.');
        continue;
      }

      final String productId = foundProduct.itemId;

      // Vytvoření UIPurchaseItem
      final purchaseItem = UIPurchaseItem(
        id: _uuid.v4(),
        productId: productId,
        productName: itemName, // Můžeme použít itemName z foundProduct pro konzistenci
        quantity: 1.0, // Předpokládáme množství 1 pro každou položku v CSV
        unitPrice: purchasePrice,
        totalItemPrice: purchasePrice, // Protože množství je 1
      );

      // Seskupení položek podle data
      if (!itemsGroupedByDate.containsKey(purchaseDate)) {
        itemsGroupedByDate[purchaseDate] = [];
      }
      itemsGroupedByDate[purchaseDate]!.add(purchaseItem);

      // Aktualizace nejnovější nákupní ceny pro produkt
      if (!lastDateByProductId.containsKey(productId) || purchaseDate.isAfter(lastDateByProductId[productId]!)) {
        latestPurchasePricesByProductId[productId] = purchasePrice;
        lastDateByProductId[productId] = purchaseDate;
      } else if (purchaseDate.isAtSameMomentAs(lastDateByProductId[productId]!) && purchasePrice > (latestPurchasePricesByProductId[productId] ?? 0)) {
        // Pokud je datum stejné, vezmeme vyšší cenu (nebo podle jiné logiky, např. poslední v souboru)
        latestPurchasePricesByProductId[productId] = purchasePrice;
      }
    }

    // Vytvoření Purchase objektů ze seskupených položek
    int purchaseNumberCounter = 1;
    itemsGroupedByDate.forEach((date, items) {
      double overallTotalPrice = items.fold(0.0, (sum, item) => sum + (item.totalItemPrice ?? 0.0));

      final purchase = Purchase(
        id: _uuid.v4(),
        supplier: "Import z CSV", // Mock dodavatel
        purchaseDate: date,
        purchaseNumber: "CSV-IMP-${purchaseNumberCounter.toString().padLeft(3, '0')}",
        notes: "Automaticky importováno z CSV.",
        items: items,
        overallTotalPrice: overallTotalPrice,
      );
      purchasesToImport.add(purchase);
      purchaseNumberCounter++;
    });

    // Seřadíme nákupy podle data pro konzistenci
    purchasesToImport.sort((a, b) => a.purchaseDate.compareTo(b.purchaseDate));

    return (
    purchasesToImport: purchasesToImport,
    latestPurchasePricesByProductId: latestPurchasePricesByProductId
    );
  }
}