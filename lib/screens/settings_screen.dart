// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/utility_services.dart';

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
  String? _savedApiKey; // Není aktuálně zobrazen, ale ponecháno pro logiku
  final Map<String, String> _languageOptions = {
    'cs': 'Čeština',
    'en': 'English',
    'es': 'Español', // Tento jazyk není v supportedLocales v main.dart
  };
  String? _currentLanguageCode;

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
        iconTheme: const IconThemeData(color: Colors.white), // Pro šipku zpět
      ),
      body: Container( // Obalení pro nastavení barvy pozadí
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
                fillColor: Colors.white, // Pozadí textového pole
                border: const OutlineInputBorder(),
                hintText: localizations.translate('apiKeyLabel'),
              ),
              style: const TextStyle(color: Colors.black), // Barva textu v poli
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700], // Příklad barvy tlačítka
                foregroundColor: Colors.white, // Barva textu tlačítka
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
              style: const TextStyle(color: Colors.black87), // Styl pro text v dropdownu
            ),
          ],
        ),
      ),
    );
  }
}