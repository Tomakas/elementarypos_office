// lib/screens/welcome_screen.dart
import 'package:flutter/material.dart';
import 'package:elementarypos_office/l10n/app_localizations.dart';
import 'package:elementarypos_office/services/utility_services.dart';
// Pro otevření odkazu v prohlížeči, pokud budete přidávat odkaz na backend:
// import 'package:url_launcher/url_launcher.dart';

class WelcomeScreen extends StatefulWidget {
  final Function(String) onApiKeySaved; // Callback po úspěšném uložení klíče

  const WelcomeScreen({super.key, required this.onApiKeySaved});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiKeyController = TextEditingController();
  bool _isLoading = false;
  // Volitelné: Pro testování validity API klíče před uložením
  // bool _isTestingKey = false;
  // String? _testKeyError;

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveAndProceed() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      // _testKeyError = null; // Pokud byste implementovali testování klíče
    });

    final apiKey = _apiKeyController.text.trim();

    // Zde byste mohli přidat volitelnou logiku pro otestování API klíče
    // např. zavoláním nějakého jednoduchého endpointu. Prozatím přeskočíme.
    // bool isKeyValid = await _testApiKey(apiKey);
    // if (!isKeyValid) {
    //   if (mounted) {
    //     setState(() {
    //       _isLoading = false;
    //       _testKeyError = AppLocalizations.of(context)!.translate('invalidApiKeyError'); // Přidat do lokalizace
    //     });
    //   }
    //   return;
    // }

    await StorageService.saveApiKey(apiKey);
    widget.onApiKeySaved(apiKey); // Informuje MyApp, že klíč byl uložen

    // Navigace na MainScreen bude řešena v MyApp na základě změny stavu.
    // Není tedy nutné volat Navigator.pushReplacement zde, pokud MyApp
    // dynamicky mění zobrazovanou úvodní obrazovku.
  }

  // Volitelná metoda pro otevření odkazu na backend
  // Future<void> _launchBackendUrl() async {
  //   final Uri url = Uri.parse('https://vas-backend.cz/kde-najit-api-klic'); // Nahraďte skutečnou URL
  //   if (!await launchUrl(url)) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text(AppLocalizations.of(context)!.translate('couldNotLaunchUrlError'))), // Přidat do lokalizace
  //       );
  //     }
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.translate('welcomeTitle')), // Přidat "welcomeTitle" do lokalizace
        backgroundColor: Colors.grey[850],
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20.0),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  localizations.translate('appTitle'), // Použijte existující klíč
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey[800]),
                ),
                const SizedBox(height: 24.0),
                Text(
                  localizations.translate('apiKeyExplanation'), // Přidat "apiKeyExplanation" do lokalizace
                  // Např.: "Pro plné využití aplikace je potřeba zadat API klíč. Najdete ho ve svém uživatelském profilu na našem webu."
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
                ),
                const SizedBox(height: 8.0),
                // Volitelný odkaz
                // TextButton(
                //   onPressed: _launchBackendUrl,
                //   child: Text(localizations.translate('findApiKeyLinkText')), // Přidat "findApiKeyLinkText", např. "Kde najdu API klíč?"
                // ),
                const SizedBox(height: 24.0),
                TextFormField(
                  controller: _apiKeyController,
                  decoration: InputDecoration(
                    labelText: localizations.translate('apiKeyLabel'),
                    hintText: localizations.translate('pasteApiKeyHint'), // Přidat "pasteApiKeyHint", např. "Vložte API klíč"
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return localizations.translate('apiKeyRequiredError'); // Přidat "apiKeyRequiredError"
                    }
                    return null;
                  },
                ),
                // Volitelné: Zobrazení chyby při testování klíče
                // if (_testKeyError != null)
                //   Padding(
                //     padding: const EdgeInsets.only(top: 8.0),
                //     child: Text(
                //       _testKeyError!,
                //       style: TextStyle(color: theme.colorScheme.error, fontSize: 14),
                //       textAlign: TextAlign.center,
                //     ),
                //   ),
                const SizedBox(height: 32.0),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: Text(localizations.translate('saveAndContinueButton')), // Přidat "saveAndContinueButton", např. "Uložit a pokračovat"
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  onPressed: _saveAndProceed,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}