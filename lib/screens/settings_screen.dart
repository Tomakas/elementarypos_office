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
  String? _savedApiKey;

  final Map<String, String> _languageOptions = {
    'cs': 'Čeština',
    'en': 'English',
    'es': 'Español',
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
    setState(() {
      _savedApiKey = savedApiKey;
      _currentLanguageCode = savedLanguageCode ?? 'cs';
    });
    _apiKeyController.text = savedApiKey ?? '';
  }

  Future<void> _saveApiKey() async {
    final newApiKey = _apiKeyController.text.trim();
    await StorageService.saveApiKey(newApiKey);
    await widget.updateApiKey(newApiKey);
    setState(() {
      _savedApiKey = newApiKey;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(AppLocalizations.of(context)!.translate('saveApiKey'))),
    );
  }

  void _changeLanguage(String? languageCode) {
    if (languageCode != null) {
      setState(() {
        _currentLanguageCode = languageCode;
      });
      widget.onLanguageChange(Locale(languageCode));
      StorageService.saveLanguageCode(languageCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.translate('settingsTitle'),
            style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[850],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text(
              localizations.translate('apiKeyLabel'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _saveApiKey,
              child: Text(localizations.translate('saveApiKey')),
            ),
            const Divider(height: 32.0, thickness: 1.0),
            Text(
              localizations.translate('changeLanguage'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16.0),
            DropdownButtonFormField<String>(
              value: _currentLanguageCode,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: const OutlineInputBorder(),
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
            ),
          ],
        ),
      ),
    );
  }
}
