// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle; // Pro načtení assetu
import 'package:provider/provider.dart'; // Pro přístup k providerům

import '../l10n/app_localizations.dart';
import '../services/utility_services.dart';
import '../services/csv_import_service.dart'; // Naše nová služba
import '../providers/product_provider.dart';
import '../providers/purchase_provider.dart';

class SettingsScreen extends StatefulWidget {
  final Future<void> Function(String) updateApiKey;
  final Function(Locale) onLanguageChange;

  const SettingsScreen({
    super.key,
    required this.updateApiKey,
    required this.onLanguageChange,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  String? _savedApiKey;
  final Map<String, String> _languageOptions = {
    'cs': 'Čeština',
    'en': 'English',
  };
  String? _currentLanguageCode;
  bool _isImporting = false; // Stav pro sledování průběhu importu

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final savedApiKey = await StorageService.getApiKey();
    final savedLanguageCode = await StorageService.getLanguageCode();
    if (mounted) {
      setState(() {
        _savedApiKey = savedApiKey;
        _currentLanguageCode = savedLanguageCode ?? 'cs'; // Výchozí 'cs'
      });
      _apiKeyController.text = savedApiKey ?? '';
    }
  }

  Future<void> _saveApiKey() async {
    final newApiKey = _apiKeyController.text.trim();
    await StorageService.saveApiKey(newApiKey);
    await widget.updateApiKey(newApiKey); // Volání callbacku
    if (mounted) {
      setState(() {
        _savedApiKey = newApiKey;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!.translate('saveApiKey'))),
      );
    }
  }

  void _changeLanguage(String? languageCode) {
    if (languageCode != null) {
      if (mounted) {
        setState(() {
          _currentLanguageCode = languageCode;
        });
      }
      widget.onLanguageChange(Locale(languageCode)); // Volání callbacku
      StorageService.saveLanguageCode(languageCode);
    }
  }

  Future<void> _importPurchasesFromCsv() async {
    final localizations = AppLocalizations.of(context)!;
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
    final csvImportService = CsvImportService();

    // Zobrazit potvrzovací dialog
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(localizations.translate('confirmCsvImportTitle')), // Přidat do lokalizace
          content: Text(localizations.translate('confirmCsvImportMessage')), // Přidat do lokalizace
          actions: <Widget>[
            TextButton(
              child: Text(localizations.translate('cancel')),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: Text(localizations.translate('import')), // Přidat do lokalizace
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return; // Uživatel nepotvrdil import
    }

    setState(() {
      _isImporting = true;
    });

    try {
      // 1. Ujistit se, že produkty jsou načtené v ProductProvider
      // (CsvImportService je potřebuje pro mapování mKodu na productId)
      if (productProvider.products.isEmpty) {
        print("Nahrávám produkty před CSV importem...");
        await productProvider.fetchAllProductData(); // Načte produkty, kategorie, NC i sklad
        if (productProvider.products.isEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localizations.translate('errorLoadingProductsForImport'))), // Přidat do lokalizace
          );
          setState(() => _isImporting = false);
          return;
        }
      }

      // 2. Načíst CSV data z assets
      final String csvRawData = await rootBundle.loadString('lib/assets/m.csv');

      // 3. Zpracovat CSV data
      final importResult = await csvImportService.processCsvData(csvRawData, productProvider);

      // 4. Aktualizovat referenční nákupní ceny produktů
      if (importResult.latestPurchasePricesByProductId.isNotEmpty) {
        for (final entry in importResult.latestPurchasePricesByProductId.entries) {
          await productProvider.updateStoredProductPurchasePrice(entry.key, entry.value);
        }
        print("Referenční nákupní ceny produktů byly aktualizovány z CSV.");
      }

      // 5. Přidat naimportované nákupy
      if (importResult.purchasesToImport.isNotEmpty) {
        for (final purchase in importResult.purchasesToImport) {
          await purchaseProvider.addPurchase(purchase);
        }
        print("${importResult.purchasesToImport.length} nákupů bylo importováno z CSV.");
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.translate('csvImportSuccess'))), // Přidat do lokalizace
        );
      }

    } catch (e, stacktrace) {
      print('Chyba během CSV importu: $e');
      print(stacktrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${localizations.translate('csvImportError')}: $e')), // Přidat do lokalizace
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.translate('settingsTitle'),
          style: const TextStyle(color: Colors.white, fontSize: 20.0),
        ),
        backgroundColor: Colors.grey[850],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        color: theme.scaffoldBackgroundColor,
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text(
              localizations.translate('apiKeyLabel'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8.0),
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: const OutlineInputBorder(),
                hintText: localizations.translate('apiKeyLabel'),
              ),
              style: const TextStyle(color: Colors.black),
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
                foregroundColor: Colors.white,
              ),
              onPressed: _saveApiKey,
              child: Text(localizations.translate('saveApiKey')),
            ),
            const Divider(height: 32.0, thickness: 1.0, color: Colors.grey),
            Text(
              localizations.translate('changeLanguage'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8.0),
            DropdownButtonFormField<String>(
              value: _currentLanguageCode,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
              ),
              items: _languageOptions.entries
                  .map(
                    (entry) => DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value),
                ),
              )
                  .toList(),
              onChanged: _changeLanguage,
              style: const TextStyle(color: Colors.black87),
            ),
            const Divider(height: 32.0, thickness: 1.0, color: Colors.grey),
            Text(
              localizations.translate('dataImportSectionTitle'), // Přidat do lokalizace: "Import dat"
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8.0),
            _isImporting
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: Text(localizations.translate('importPurchasesFromCsvButton')), // Přidat do lokalizace: "Načti nákupy z CSV"
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12.0)
              ),
              onPressed: _importPurchasesFromCsv,
            ),
            const SizedBox(height: 8.0),
            Text(
              localizations.translate('csvImportDescription'), // Přidat do lokalizace: "Importuje historii nákupů a aktualizuje referenční nákupní ceny produktů z přiloženého souboru m.csv."
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }
}