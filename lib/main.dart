// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/main_screen.dart';
import 'providers/receipt_provider.dart';
import 'providers/product_provider.dart';
import 'providers/customer_provider.dart';
import 'services/utility_services.dart'; // Importováno pro StorageService [cite: 1576]
import 'l10n/app_localizations.dart'; //
import 'providers/purchase_provider.dart'; //
import 'screens/welcome_screen.dart'; // Nový import pro WelcomeScreen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final String? apiKey = await StorageService.getApiKey(); // [cite: 1577]

  // Nový způsob získání initialLocale přímo pomocí StorageService
  final String? savedLanguageCode = await StorageService.getLanguageCode(); // [cite: 1579]
  // Získání výchozího jazyka platformy pro případ, že žádný není uložen
  final String defaultPlatformLanguageCode = WidgetsBinding.instance.platformDispatcher.locale.languageCode; // [cite: 1579]
  final Locale initialLocale = Locale(savedLanguageCode ?? defaultPlatformLanguageCode); // [cite: 1580]

  runApp(MyApp(initialApiKey: apiKey, initialLocale: initialLocale));
}

class MyApp extends StatefulWidget {
  final String? initialApiKey; // [cite: 1581]
  final Locale initialLocale; // [cite: 1581]

  const MyApp({super.key, this.initialApiKey, required this.initialLocale}); // [cite: 1581]

  @override
  State<MyApp> createState() => _MyAppState(); // [cite: 1582]
}

class _MyAppState extends State<MyApp> {
  late Locale _locale;
  late bool _apiKeyIsSet; // Stavová proměnná pro API klíč
  String? _currentApiKey; // Uložený aktuální API klíč

  @override
  void initState() {
    super.initState();
    _locale = widget.initialLocale; // [cite: 1583]
    _currentApiKey = widget.initialApiKey;
    _apiKeyIsSet = _currentApiKey != null && _currentApiKey!.isNotEmpty;
  }

  void _updateLocale(Locale newLocale) {
    setState(() {
      _locale = newLocale;
    }); // [cite: 1584]
  }

  // Voláno z WelcomeScreen po uložení nového klíče
  void _handleApiKeySaved(String apiKey) {
    setState(() {
      _currentApiKey = apiKey;
      _apiKeyIsSet = true;
    });
    // Providery si nový klíč načtou z StorageService při dalším volání API.
  }

  // Voláno ze SettingsScreen, pokud je API klíč aktualizován
  Future<void> _handleApiKeyUpdatedInSettings(String newApiKey) async {
    // StorageService.saveApiKey je již voláno v SettingsScreen
    setState(() {
      _currentApiKey = newApiKey;
      // Pokud uživatel uloží prázdný klíč, _apiKeyIsSet bude false
      // a aplikace se automaticky přepne na WelcomeScreen
      _apiKeyIsSet = newApiKey.isNotEmpty;
    });
  }

  // Voláno ze SettingsScreen, pokud je API klíč vymazán (uložením prázdného řetězce)
  void _handleApiKeyCleared() {
    setState(() {
      _currentApiKey = null;
      _apiKeyIsSet = false;
    });
    // StorageService.saveApiKey("") by bylo zavoláno v SettingsScreen (skrze _handleApiKeyUpdatedInSettings)
    // nebo StorageService.clearApiKey() pokud by existovala taková explicitní akce.
  }


  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ReceiptProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => PurchaseProvider()), //
      ],
      child: MaterialApp(
        title: 'EPOS Office', // Můžete později nahradit lokalizovaným klíčem, pokud bude potřeba
        locale: _locale,
        localizationsDelegates: const [ // [cite: 1585]
          AppLocalizations.delegate, // [cite: 1585]
          GlobalMaterialLocalizations.delegate, // [cite: 1585]
          GlobalWidgetsLocalizations.delegate, // [cite: 1585]
          GlobalCupertinoLocalizations.delegate, // [cite: 1585]
        ],
        supportedLocales: const [
          Locale('cs', 'CZ'),
          Locale('en', 'US'),
          // Locale('es', 'ES'), // Příklad dalšího jazyka [cite: 1586]
        ],
        theme: ThemeData(
          scaffoldBackgroundColor: Colors.grey[400], // [cite: 1586]
          // Můžete zde definovat další globální styly
          primarySwatch: Colors.blueGrey,
          // Příklad primární barvy
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.grey[850],
            foregroundColor: Colors.white, // Barva ikon a textu v AppBar
            titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20.0),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  textStyle: const TextStyle(fontSize: 15)
              )
          ),
          textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blueGrey[700],
              )
          ),
          inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16)
          ),
          // ... další globální nastavení motivu
        ),
        home: _apiKeyIsSet
            ? MainScreen(
          updateApiKey: _handleApiKeyUpdatedInSettings,
          onLanguageChange: _updateLocale,
          onApiKeyCleared: _handleApiKeyCleared, // Předání nového callbacku
        )
            : WelcomeScreen(onApiKeySaved: _handleApiKeySaved),
      ),
    );
  }
}