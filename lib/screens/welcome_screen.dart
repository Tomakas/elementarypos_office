// lib/screens/welcome_screen.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:elementarypos_office/l10n/app_localizations.dart';
import 'package:elementarypos_office/services/utility_services.dart';
import 'package:url_launcher/url_launcher.dart';

class WelcomeScreen extends StatefulWidget {
  final Function(String) onApiKeySaved;

  const WelcomeScreen({super.key, required this.onApiKeySaved});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiKeyController = TextEditingController();
  bool _isLoading = false;

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
    });

    final apiKey = _apiKeyController.text.trim();
    await StorageService.saveApiKey(apiKey);
    widget.onApiKeySaved(apiKey);
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.translate('couldNotLaunchUrlError'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    String fullExplanationText = localizations.translate('apiKeyExplanation');
    String urlToLaunch = "https://app.elementarypos.com/#/api";

    String textBeforeUrl = fullExplanationText;
    String linkText = "";
    String textAfterUrl = "";

    int urlStartIndex = fullExplanationText.indexOf(urlToLaunch);
    if (urlStartIndex != -1) {
      textBeforeUrl = fullExplanationText.substring(0, urlStartIndex);
      linkText = urlToLaunch;
      textAfterUrl = fullExplanationText.substring(urlStartIndex + urlToLaunch.length);
    } else {
      textBeforeUrl = fullExplanationText;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.translate('welcomeTitle')),
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
                  localizations.translate('appTitle'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey[850]),
                ),
                const SizedBox(height: 8.0),
                Text(
                  localizations.translate('appSubtitle'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24.0),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: theme.textTheme.titleSmall?.copyWith(color: Colors.grey[700], fontSize: 15),
                    children: <TextSpan>[
                      TextSpan(text: textBeforeUrl),
                      if (linkText.isNotEmpty)
                        TextSpan(
                          text: linkText,
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            decoration: TextDecoration.underline,
                            fontSize: 15,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              _launchURL(linkText);
                            },
                        ),
                      TextSpan(text: textAfterUrl),
                    ],
                  ),
                ),
                const SizedBox(height: 24.0),
                TextFormField(
                  controller: _apiKeyController,
                  decoration: InputDecoration(
                    labelText: localizations.translate('apiKeyLabel'),
                    hintText: localizations.translate('pasteApiKeyHint'),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return localizations.translate('apiKeyRequiredError');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32.0),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: Text(localizations.translate('saveAndContinueButton')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
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