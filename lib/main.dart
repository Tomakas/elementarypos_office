//lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/main_screen.dart';
import 'providers/receipt_provider.dart';
import 'providers/product_provider.dart';
import 'providers/customer_provider.dart';
import 'services/utility_services.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final String? apiKey = await StorageService.getApiKey();
  final Locale initialLocale = await LocalizationService.getLocale();

  runApp(MyApp(initialApiKey: apiKey, initialLocale: initialLocale));
}

class MyApp extends StatefulWidget {
  final String? initialApiKey;
  final Locale initialLocale;

  const MyApp({super.key, this.initialApiKey, required this.initialLocale});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Locale _locale;

  @override
  void initState() {
    super.initState();
    _locale = widget.initialLocale;
  }

  void _updateLocale(Locale newLocale) {
    setState(() {
      _locale = newLocale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ReceiptProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
      ],
      child: MaterialApp(
        title: 'EPOS Office',
        locale: _locale,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('cs', 'CZ'),
          Locale('en', 'US'),
          Locale('es', 'ES'),

        ],
        theme: ThemeData(
        scaffoldBackgroundColor: Colors.grey[400],
        ),
        home: MainScreen(
          updateApiKey: (String apiKey) async {},
          onLanguageChange: _updateLocale,
        ),
      ),
    );
  }
}
