import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../domain/providers/theme_provider.dart';
import '../../domain/providers/locale_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('⚙️ Sozlamalar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Theme Section
          Text('Mavzu', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _SettingCard(
            children: [
              _ThemeOption(
                icon: Icons.light_mode_rounded,
                label: 'Kunduzgi',
                selected: themeMode == ThemeMode.light,
                onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light),
              ),
              const Divider(height: 1),
              _ThemeOption(
                icon: Icons.dark_mode_rounded,
                label: 'Tungi',
                selected: themeMode == ThemeMode.dark,
                onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark),
              ),
              const Divider(height: 1),
              _ThemeOption(
                icon: Icons.brightness_auto_rounded,
                label: 'Tizim',
                selected: themeMode == ThemeMode.system,
                onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Language Section
          Text('Til', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _SettingCard(
            children: LocaleNotifier.supportedLanguages.entries.map((entry) {
              final isSelected = _matchesLocale(locale, entry.key);
              return Column(
                children: [
                  ListTile(
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

          // About
          Text("Ilova haqida", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _SettingCard(
            children: [
              ListTile(
                leading: const Text('📖', style: TextStyle(fontSize: 24)),
                title: const Text('Muallimi Soniy'),
                subtitle: const Text('v1.0.0'),
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.code_rounded, size: 20),
                title: const Text('CodingTech.uz'),
                subtitle: const Text('Dasturchilar'),
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: selected ? AppColors.primary : AppColors.textMuted),
      title: Text(label),
      trailing: selected
          ? const Icon(Icons.check_rounded, color: AppColors.primary)
          : null,
      onTap: onTap,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
    );
  }
}
