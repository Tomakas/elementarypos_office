// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle; // Pro načtení assetu [cite: 2398]
import 'package:provider/provider.dart'; // Pro přístup k providerům [cite: 2398]

import '../l10n/app_localizations.dart';
import '../services/utility_services.dart'; // [cite: 2398]
import '../services/csv_import_service.dart'; // Naše nová služba [cite: 2398]
import '../providers/product_provider.dart'; // [cite: 2398]
import '../providers/purchase_provider.dart'; // [cite: 2399]

class SettingsScreen extends StatefulWidget {
  final Future<void> Function(String) updateApiKey;
  final Function(Locale) onLanguageChange;

  const SettingsScreen({
    super.key,
    required this.updateApiKey,
    required this.onLanguageChange,
  }); // [cite: 2400]

  @override
  State<SettingsScreen> createState() => _SettingsScreenState(); // [cite: 2401]
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  String? _savedApiKey;
  // Odstraněna původní definice _languageOptions
  String? _currentLanguageCode;
  bool _isImporting = false; // Stav pro sledování průběhu importu [cite: 2403]

  @override
  void initState() {
    super.initState();
    _loadSettings(); // [cite: 2404]
  }

  Future<void> _loadSettings() async {
    final savedApiKey = await StorageService.getApiKey(); // [cite: 2405]
    final savedLanguageCode = await StorageService.getLanguageCode(); // [cite: 2405]
    if (mounted) {
      setState(() {
        _savedApiKey = savedApiKey;
        _currentLanguageCode = savedLanguageCode ?? 'cs'; // Výchozí 'cs' [cite: 2406]
      });
      _apiKeyController.text = savedApiKey ?? ''; // [cite: 2406]
    }
  }

  Future<void> _saveApiKey() async {
    final newApiKey = _apiKeyController.text.trim();
    await StorageService.saveApiKey(newApiKey); // [cite: 2407]
    await widget.updateApiKey(newApiKey); // Volání callbacku [cite: 2408]
    if (mounted) {
      setState(() {
        _savedApiKey = newApiKey;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!.translate('saveApiKey'))),
      ); // [cite: 2409]
    }
  }

  void _changeLanguage(String? languageCode) {
    if (languageCode != null) {
      if (mounted) {
        setState(() {
          _currentLanguageCode = languageCode;
        });
      }
      widget.onLanguageChange(Locale(languageCode)); // Volání callbacku [cite: 2411]
      StorageService.saveLanguageCode(languageCode); // [cite: 2411]
    }
  }

  Future<void> _importPurchasesFromCsv() async {
    final localizations = AppLocalizations.of(context)!;
    final productProvider = Provider.of<ProductProvider>(context, listen: false); // [cite: 2412]
    final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false); // [cite: 2412]
    final csvImportService = CsvImportService(); // [cite: 2412]

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(localizations.translate('confirmCsvImportTitle')), // [cite: 2414]
          content: Text(localizations.translate('confirmCsvImportMessage')), // [cite: 2414]
          actions: <Widget>[
            TextButton(
              child: Text(localizations.translate('cancel')), // [cite: 2415]
              onPressed: () => Navigator.of(dialogContext).pop(false), // [cite: 2415]
            ),
            TextButton(
              child: Text(localizations.translate('import')), // [cite: 2415]
              onPressed: () => Navigator.of(dialogContext).pop(true), // [cite: 2415]
            ),
          ],
        );
      },
    ); // [cite: 2416]

    if (confirmed != true) {
      return; // [cite: 2417]
    }

    setState(() {
      _isImporting = true;
    }); // [cite: 2418]

    try {
      if (productProvider.products.isEmpty) {
        print("Nahrávám produkty před CSV importem..."); // Tento log ponecháváme dle zadání
        await productProvider.fetchAllProductData(); // [cite: 2419]
        if (productProvider.products.isEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localizations.translate('errorLoadingProductsForImport'))), // [cite: 2420]
          );
          setState(() => _isImporting = false); // [cite: 2421]
          return;
        }
      }

      final String csvRawData = await rootBundle.loadString('lib/assets/m.csv'); // [cite: 2421]
      final importResult = await csvImportService.processCsvData(csvRawData, productProvider); // [cite: 2422]

      if (importResult.latestPurchasePricesByProductId.isNotEmpty) {
        for (final entry in importResult.latestPurchasePricesByProductId.entries) {
          await productProvider.updateStoredProductPurchasePrice(entry.key, entry.value); // [cite: 2423]
        }
        print("Referenční nákupní ceny produktů byly aktualizovány z CSV."); // [cite: 2424]
      }

      if (importResult.purchasesToImport.isNotEmpty) {
        for (final purchase in importResult.purchasesToImport) {
          await purchaseProvider.addPurchase(purchase); // [cite: 2425]
        }
        print("${importResult.purchasesToImport.length} nákupů bylo importováno z CSV."); // [cite: 2426]
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.translate('csvImportSuccess'))), // [cite: 2427]
        );
      }

    } catch (e, stacktrace) {
      print('Chyba během CSV importu: $e'); // [cite: 2428]
      print(stacktrace); // [cite: 2428]
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${localizations.translate('csvImportError')}: $e')), // [cite: 2429]
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        }); // [cite: 2430]
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context)!; // [cite: 2431]
    final ThemeData theme = Theme.of(context); // [cite: 2432]

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
        color: theme.scaffoldBackgroundColor, // [cite: 2432]
        padding: const EdgeInsets.all(16.0), // [cite: 2433]
        child: ListView(
          children: [
            Text(
              localizations.translate('apiKeyLabel'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ), // [cite: 2433]
            const SizedBox(height: 8.0), // [cite: 2434]
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: const OutlineInputBorder(),
                hintText: localizations.translate('apiKeyLabel'), // [cite: 2435]
              ),
              style: const TextStyle(color: Colors.black),
            ), // [cite: 2435]
            const SizedBox(height: 16.0),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700], // [cite: 2436]
                foregroundColor: Colors.white, // [cite: 2436]
              ),
              onPressed: _saveApiKey,
              child: Text(localizations.translate('saveApiKey')),
            ), // [cite: 2436]
            const Divider(height: 32.0, thickness: 1.0, color: Colors.grey), // [cite: 2437]
            Text(
              localizations.translate('changeLanguage'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ), // [cite: 2437]
            const SizedBox(height: 8.0),
            DropdownButtonFormField<String>(
              value: _currentLanguageCode, // [cite: 2438]
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0), // [cite: 2438]
              ),
              items: [ // Přímo definované položky s použitím localizations
                DropdownMenuItem<String>(
                  value: 'cs',
                  child: Text(localizations.translate('languageNameCs')),
                ),
                DropdownMenuItem<String>(
                  value: 'en',
                  child: Text(localizations.translate('languageNameEn')),
                ),
              ], // [cite: 2440]
              onChanged: _changeLanguage,
              style: const TextStyle(color: Colors.black87),
            ), // [cite: 2440]
            const Divider(height: 32.0, thickness: 1.0, color: Colors.grey), // [cite: 2441]
            Text(
              localizations.translate('dataImportSectionTitle'), // [cite: 2441]
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8.0),
            _isImporting
                ? const Center(child: CircularProgressIndicator()) // [cite: 2442, 2443]
                : ElevatedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: Text(localizations.translate('importPurchasesFromCsvButton')), // [cite: 2443]
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white, // [cite: 2444]
                  padding: const EdgeInsets.symmetric(vertical: 12.0) // [cite: 2444]
              ),
              onPressed: _importPurchasesFromCsv,
            ), // [cite: 2444]
            const SizedBox(height: 8.0),
            Text(
              localizations.translate('csvImportDescription'), // [cite: 2445]
              style: TextStyle(fontSize: 13, color: Colors.grey[700]), // [cite: 2445]
            ),
          ],
        ),
      ),
    );
  }
}