// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle; // Pro načtení assetu [cite: 934]
import 'package:provider/provider.dart'; // Pro přístup k providerům [cite: 934]

import '../l10n/app_localizations.dart';
import '../services/utility_services.dart'; // [cite: 934]
import '../services/csv_import_service.dart'; // Naše nová služba [cite: 935]
import '../providers/product_provider.dart'; // [cite: 935]
import '../providers/purchase_provider.dart'; // [cite: 935]

class SettingsScreen extends StatefulWidget {
  final Future<void> Function(String) updateApiKey;
  final Function(Locale) onLanguageChange;
  final VoidCallback onApiKeyCleared; // Nový callback pro signalizaci vymazání API klíče [cite: 937]

  const SettingsScreen({
    super.key,
    required this.updateApiKey,
    required this.onLanguageChange,
    required this.onApiKeyCleared, // Přidáno do konstruktoru [cite: 937]
  }); // [cite: 937]

  @override
  State<SettingsScreen> createState() => _SettingsScreenState(); // [cite: 939]
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  String? _savedApiKey; // [cite: 940]
  String? _currentLanguageCode; // [cite: 940]
  bool _isImporting = false; // Stav pro sledování průběhu importu [cite: 940, 941]

  @override
  void initState() {
    super.initState();
    _loadSettings(); // [cite: 942]
  }

  Future<void> _loadSettings() async {
    final localizations = AppLocalizations.of(context);
    final savedApiKey = await StorageService.getApiKey(); // [cite: 943]
    final savedLanguageCode = await StorageService.getLanguageCode(); // [cite: 944]
    if (mounted) {
      setState(() {
        _savedApiKey = savedApiKey;
        // Pokud není uložen žádný jazyk, použijeme jazyk zařízení, nebo 'cs' jako výchozí
        _currentLanguageCode = savedLanguageCode ?? localizations?.locale.languageCode ?? 'cs'; // [cite: 944]
      });
      _apiKeyController.text = savedApiKey ?? ''; // [cite: 945]
    }
  }

  Future<void> _saveApiKey() async {
    final newApiKey = _apiKeyController.text.trim();
    await StorageService.saveApiKey(newApiKey); // [cite: 946]
    await widget.updateApiKey(newApiKey); // Volání callbacku do MyApp pro aktualizaci stavu [cite: 947]

    if (newApiKey.isEmpty) {
      widget.onApiKeyCleared(); // Signalizujeme MyApp, že klíč byl "vymazán" (uložen jako prázdný)
    }

    if (mounted) {
      setState(() {
        _savedApiKey = newApiKey;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!.translate('saveApiKey'))),
      ); // [cite: 948, 949]
    }
  }

  void _changeLanguage(String? languageCode) {
    if (languageCode != null) {
      if (mounted) {
        setState(() {
          _currentLanguageCode = languageCode;
        }); // [cite: 949]
      }
      widget.onLanguageChange(Locale(languageCode)); // Volání callbacku [cite: 950]
      StorageService.saveLanguageCode(languageCode); // [cite: 951]
    }
  }

  Future<void> _importPurchasesFromCsv() async {
    final localizations = AppLocalizations.of(context)!; // [cite: 952]
    final productProvider = Provider.of<ProductProvider>(context, listen: false); // [cite: 952]
    final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false); // [cite: 952, 953]
    final csvImportService = CsvImportService(); // [cite: 953]

    final bool? confirmed = await showDialog<bool>( // [cite: 954]
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(localizations.translate('confirmCsvImportTitle')), // [cite: 954]
          content: Text(localizations.translate('confirmCsvImportMessage')), // [cite: 954]
          actions: <Widget>[
            TextButton(
              child: Text(localizations.translate('cancel')), // [cite: 954]
              onPressed: () => Navigator.of(dialogContext).pop(false), // [cite: 955]
            ),
            TextButton(
              child: Text(localizations.translate('import')), // [cite: 955]
              onPressed: () => Navigator.of(dialogContext).pop(true), // [cite: 955]
            ),
          ],
        );
      },
    ); // [cite: 956]

    if (confirmed != true) {
      return; // [cite: 958]
    }

    setState(() {
      _isImporting = true;
    }); // [cite: 959]

    try {
      if (productProvider.products.isEmpty) {
        print("Nahrávám produkty před CSV importem..."); // [cite: 959]
        await productProvider.fetchAllProductData(); // [cite: 961]
        if (productProvider.products.isEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localizations.translate('errorLoadingProductsForImport'))), // [cite: 961]
          );
          setState(() => _isImporting = false); // [cite: 962]
          return; // [cite: 963]
        }
      }

      final String csvRawData = await rootBundle.loadString('lib/assets/m.csv'); // [cite: 963, 964]
      final importResult = await csvImportService.processCsvData(csvRawData, productProvider); // [cite: 965]

      if (importResult.latestPurchasePricesByProductId.isNotEmpty) {
        for (final entry in importResult.latestPurchasePricesByProductId.entries) {
          await productProvider.updateStoredProductPurchasePrice(entry.key, entry.value); // [cite: 965]
        }
        print("Referenční nákupní ceny produktů byly aktualizovány z CSV."); // [cite: 967]
      }

      if (importResult.purchasesToImport.isNotEmpty) {
        for (final purchase in importResult.purchasesToImport) {
          await purchaseProvider.addPurchase(purchase); // [cite: 968]
        }
        print("${importResult.purchasesToImport.length} nákupů bylo importováno z CSV."); // [cite: 969]
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.translate('csvImportSuccess'))), // [cite: 969]
        );
      }

    } catch (e, stacktrace) {
      print('Chyba během CSV importu: $e'); // [cite: 971]
      print(stacktrace); // [cite: 971]
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${localizations.translate('csvImportError')}: $e')), // [cite: 971]
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        }); // [cite: 973]
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context)!; // [cite: 973, 974]
    final ThemeData theme = Theme.of(context); // [cite: 975]

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.translate('settingsTitle'),
          // style: const TextStyle(color: Colors.white, fontSize: 20.0), // Již definováno v globálním motivu
        ),
        // backgroundColor: Colors.grey[850], // Již definováno v globálním motivu
        // iconTheme: const IconThemeData(color: Colors.white), // Již definováno v globálním motivu
      ),
      body: Container(
        color: theme.scaffoldBackgroundColor, // Použití barvy z globálního motivu [cite: 975, 976]
        padding: const EdgeInsets.all(16.0), // [cite: 976]
        child: ListView(
          children: [
            Text(
              localizations.translate('apiKeyLabel'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ), // [cite: 976]
            const SizedBox(height: 8.0), // [cite: 977]
            TextFormField( // Použití TextFormField pro případnou validaci v budoucnu
              controller: _apiKeyController,
              decoration: InputDecoration(
                // filled: true, // Již definováno v globálním motivu
                // fillColor: Colors.white, // Již definováno v globálním motivu
                // border: const OutlineInputBorder(), // Již definováno v globálním motivu
                hintText: localizations.translate('apiKeyLabel'), // [cite: 978]
              ),
              style: const TextStyle(color: Colors.black), // Explicitní barva textu v poli
            ), // [cite: 978]
            const SizedBox(height: 16.0),
            ElevatedButton(
              // style: ElevatedButton.styleFrom( // Již definováno v globálním motivu
              //   backgroundColor: Colors.grey[700],
              //   foregroundColor: Colors.white,
              // ),
              onPressed: _saveApiKey,
              child: Text(localizations.translate('saveApiKey')),
            ), // [cite: 980]
            if (_savedApiKey != null && _savedApiKey!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Builder( // Použití Builder pro přístup k AppLocalizations v tomto kontextu
                    builder: (context) {
                      final localizations = AppLocalizations.of(context)!;
                      String baseString = localizations.translate('currentApiKey');
                      String maskedApiKey = '********${_savedApiKey!.length > 8 ? _savedApiKey!.substring(_savedApiKey!.length - 4) : (_savedApiKey!.length > 4 ? _savedApiKey!.substring(_savedApiKey!.length - (_savedApiKey!.length ~/ 2)) : '')}';
                      String fullApiKeyText = baseString.replaceFirst('{apiKey}', maskedApiKey);
                      return Text(
                        fullApiKeyText,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      );
                    }
                ),
              ),
            const Divider(height: 32.0, thickness: 1.0, color: Colors.grey), //

            Text(
              localizations.translate('changeLanguage'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ), // [cite: 980]
            const SizedBox(height: 8.0), // [cite: 981]
            DropdownButtonFormField<String>(
              value: _currentLanguageCode, // [cite: 981]
              decoration: const InputDecoration(
                // filled: true, // Již definováno v globálním motivu
                // fillColor: Colors.white, // Již definováno v globálním motivu
                // border: const OutlineInputBorder(), // Již definováno v globálním motivu
                // contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0), // Již definováno v globálním motivu
              ),
              items: [ // Přímo definované položky s použitím localizations [cite: 982]
                DropdownMenuItem<String>(
                  value: 'cs',
                  child: Text(localizations.translate('languageNameCs')), // [cite: 983]
                ),
                DropdownMenuItem<String>(
                  value: 'en',
                  child: Text(localizations.translate('languageNameEn')), // [cite: 983]
                ),
              ], // [cite: 984]
              onChanged: _changeLanguage,
              style: const TextStyle(color: Colors.black87, fontSize: 16), // Explicitní styl pro Dropdown
            ), // [cite: 984]
            const Divider(height: 32.0, thickness: 1.0, color: Colors.grey), // [cite: 984]
            Text(
              localizations.translate('dataImportSectionTitle'), // [cite: 985]
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8.0),
            _isImporting
                ? const Center(child: Padding( // [cite: 986]
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: CircularProgressIndicator(),
            )) // [cite: 986]
                : ElevatedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: Text(localizations.translate('importPurchasesFromCsvButton')), // [cite: 986]
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent, // Výraznější barva pro import
                foregroundColor: Colors.white, // [cite: 987]
                // padding: const EdgeInsets.symmetric(vertical: 12.0) // Použije se globální styl
              ),
              onPressed: _importPurchasesFromCsv,
            ), // [cite: 987]
            const SizedBox(height: 8.0),
            Text(
              localizations.translate('csvImportDescription'), // [cite: 988]
              style: TextStyle(fontSize: 13, color: Colors.grey[700]), // [cite: 988]
            ),
          ],
        ),
      ),
    );
  }
}