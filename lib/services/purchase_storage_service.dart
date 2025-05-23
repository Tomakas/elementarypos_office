// lib/services/purchase_storage_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/purchase_model.dart';

class PurchaseStorageService {
  static const String _fileName = 'purchases.json';

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/$_fileName');
  }

  Future<List<Purchase>> loadPurchases() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) {
        print('Soubor s nákupy ($_fileName) neexistuje, vracím prázdný seznam.');
        return [];
      }

      final contents = await file.readAsString();
      if (contents.isEmpty) {
        print('Soubor s nákupy ($_fileName) je prázdný, vracím prázdný seznam.');
        return [];
      }

      final List<dynamic> jsonData = json.decode(contents);
      return jsonData.map((jsonItem) => Purchase.fromJson(jsonItem as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Chyba při načítání nákupů: $e');
      return []; // V případě chyby vrátíme prázdný seznam
    }
  }

  Future<File> savePurchases(List<Purchase> purchases) async {
    final file = await _localFile;
    final List<Map<String, dynamic>> jsonData =
    purchases.map((purchase) => purchase.toJson()).toList();

    print('Ukládání ${purchases.length} nákupů do souboru: ${file.path}');
    return file.writeAsString(json.encode(jsonData));
  }

  // Volitelně: Metoda pro smazání všech nákupů (pro testování apod.)
  Future<void> clearPurchases() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        await file.delete();
        print('Soubor s nákupy ($_fileName) byl smazán.');
      }
    } catch (e) {
      print('Chyba při mazání souboru s nákupy: $e');
    }
  }
}