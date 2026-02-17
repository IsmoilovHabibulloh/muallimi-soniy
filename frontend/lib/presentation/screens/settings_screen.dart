import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/l10n/app_localizations.dart';
import '../../domain/providers/theme_provider.dart';
import '../../domain/providers/locale_provider.dart';

const Map<String, String> _langFlags = {
  'uz': '🇺🇿',
  'uz_Cyrl': '🇺🇿',
  'ru': '🇷🇺',
  'en': '🇬🇧',
  'ar': '🇸🇦',
};

class SettingsScreen extends ConsumerStatefulWidget {
  final String? section;
  const SettingsScreen({super.key, this.section});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _themeKey = GlobalKey();
  final GlobalKey _languageKey = GlobalKey();
  final GlobalKey _aboutKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.section != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSection(widget.section!);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSection(String section) {
    GlobalKey? targetKey;
    switch (section) {
      case 'theme':
        targetKey = _themeKey;
        break;
      case 'language':
        targetKey = _languageKey;
        break;
      case 'about':
        targetKey = _aboutKey;
        break;
    }
    if (targetKey?.currentContext != null) {
      Scrollable.ensureVisible(
        targetKey!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text('⚙️ ${l.settings}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        children: [
          // Theme Section
          Text(l.theme, key: _themeKey, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _SettingCard(
            children: [
              ListTile(
                leading: const _PremiumIcon(emoji: '☀️'),
                title: Text(l.light),
                trailing: themeMode == ThemeMode.light
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light),
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const _PremiumIcon(emoji: '🌙'),
                title: Text(l.dark),
                trailing: themeMode == ThemeMode.dark
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark),
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const _PremiumIcon(emoji: '🔄'),
                title: Text(l.system),
                trailing: themeMode == ThemeMode.system
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system),
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Language Section
          Text(l.language, key: _languageKey, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _SettingCard(
            children: LocaleNotifier.supportedLanguages.entries.map((entry) {
              final isSelected = _matchesLocale(locale, entry.key);
              return Column(
                children: [
                  ListTile(
                    leading: _PremiumIcon(emoji: _langFlags[entry.key] ?? '🏳️'),
                    title: Text(entry.value),
                    trailing: isSelected
                        ? const Icon(Icons.check_rounded, color: AppColors.primary)
                        : null,
                    onTap: () {
                      Locale newLocale;
                      if (entry.key == 'uz_Cyrl') {
                        newLocale = const Locale('uz', 'Cyrl');
                      } else {
                        newLocale = Locale(entry.key);
                      }
                      ref.read(localeProvider.notifier).setLocale(newLocale);
                    },
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  ),
                  if (entry.key != LocaleNotifier.supportedLanguages.keys.last)
                    const Divider(height: 1),
                ],
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // About & Legal
          Text(l.aboutApp, key: _aboutKey, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _SettingCard(
            children: [
              ListTile(
                leading: const _PremiumIcon(emoji: '📖'),
                title: const Text('Muallimi Soniy'),
                subtitle: const Text('v1.0.0 • MYSTAR MChJ'),
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                onTap: () => context.push('/legal/about'),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const _PremiumIcon(emoji: '🔒'),
                title: Text(l.privacyPolicy),
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                onTap: () => context.push('/legal/privacy'),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const _PremiumIcon(emoji: '📋'),
                title: Text(l.termsOfUse),
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                onTap: () => context.push('/legal/terms'),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const _PremiumIcon(emoji: 'ℹ️'),
                title: Text(l.about),
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                onTap: () => context.push('/legal/about'),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              ),
            ],
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  bool _matchesLocale(Locale current, String key) {
    if (key == 'uz_Cyrl') {
      return current.languageCode == 'uz' && current.countryCode == 'Cyrl';
    }
    return current.languageCode == key && current.countryCode == null;
  }
}

class _SettingCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerTheme.color ?? AppColors.borderLight,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

class _PremiumIcon extends StatelessWidget {
  final String emoji;
  const _PremiumIcon({required this.emoji});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [Colors.white.withOpacity(0.10), Colors.white.withOpacity(0.04)]
              : [Colors.white, Colors.grey.shade50],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.14)
              : Colors.black.withOpacity(0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? AppColors.primary.withOpacity(0.10)
                : Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          if (!isDark)
            BoxShadow(
              color: Colors.white.withOpacity(0.8),
              blurRadius: 2,
              offset: const Offset(0, -1),
            ),
        ],
      ),
      child: Center(
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
