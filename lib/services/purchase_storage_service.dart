// lib/services/purchase_storage_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/purchase_model.dart';

class PurchaseStorageService {
  static const String _fileName = 'purchases_data.json'; // Změna názvu pro testování, aby se nemíchal se starými daty

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    print('PurchaseStorageService: Cesta k dokumentům: ${directory.path}');
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/$_fileName');
  }

  Future<List<Purchase>> loadPurchases() async {
    try {
      final file = await _localFile;
      print('PurchaseStorageService: Pokus o načtení souboru: ${file.path}');
      if (!await file.exists()) {
        print('PurchaseStorageService: Soubor ($_fileName) neexistuje, vracím prázdný seznam.');
        return [];
      }

      final contents = await file.readAsString();
      print('PurchaseStorageService: Obsah souboru: $contents');
      if (contents.isEmpty) {
        print('PurchaseStorageService: Soubor ($_fileName) je prázdný, vracím prázdný seznam.');
        return [];
      }

      final List<dynamic> jsonData = json.decode(contents);
      print('PurchaseStorageService: JSON data dekódována, počet záznamů: ${jsonData.length}');
      List<Purchase> purchases = jsonData.map((jsonItem) => Purchase.fromJson(jsonItem as Map<String, dynamic>)).toList();
      print('PurchaseStorageService: Nákupy úspěšně načteny a deserializovány.');
      return purchases;
    } catch (e, stacktrace) { // Přidáno stacktrace pro více detailů
      print('PurchaseStorageService: Chyba při načítání nákupů: $e');
      print('PurchaseStorageService: Stacktrace: $stacktrace');
      return [];
    }
  }

  Future<File> savePurchases(List<Purchase> purchases) async {
    final file = await _localFile;
    final List<Map<String, dynamic>> jsonData =
    purchases.map((purchase) => purchase.toJson()).toList();

    String jsonStringToWrite = json.encode(jsonData);
    print('PurchaseStorageService: Ukládání ${purchases.length} nákupů do souboru: ${file.path}');
    print('PurchaseStorageService: Data k zápisu: $jsonStringToWrite');

    File writtenFile = await file.writeAsString(jsonStringToWrite);
    print('PurchaseStorageService: Data úspěšně zapsána.');
    return writtenFile;
  }

  Future<void> clearPurchases() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        await file.delete();
        print('PurchaseStorageService: Soubor ($_fileName) byl smazán.');
      } else {
        print('PurchaseStorageService: Soubor ($_fileName) pro smazání neexistuje.');
      }
    } catch (e) {
      print('PurchaseStorageService: Chyba při mazání souboru s nákupy: $e');
    }
  }
}