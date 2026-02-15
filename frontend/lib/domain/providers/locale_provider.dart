import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>(
  (ref) => LocaleNotifier(),
);

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('uz')) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(AppConstants.keyLocale);
    if (code != null) {
      if (code == 'uz_Cyrl') {
        state = const Locale('uz', 'Cyrl');
      } else {
        state = Locale(code);
      }
    }
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    final code = locale.countryCode != null
        ? '${locale.languageCode}_${locale.countryCode}'
        : locale.languageCode;
    await prefs.setString(AppConstants.keyLocale, code);
  }

  static const Map<String, String> supportedLanguages = {
    'uz': "O'zbekcha",
    'uz_Cyrl': 'Ўзбекча',
    'ru': 'Русский',
    'en': 'English',
    'ar': 'العربية',
  };
}
