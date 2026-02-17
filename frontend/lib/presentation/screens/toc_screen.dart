import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/l10n/app_localizations.dart';
import '../../domain/providers/book_provider.dart';

class TocScreen extends ConsumerWidget {
  const TocScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chaptersAsync = ref.watch(chaptersProvider);
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text('📋 ${l.tableOfContents}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: chaptersAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text('${l.error}: $err'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(chaptersProvider),
                child: Text(l.retry),
              ),
            ],
          ),
        ),
        data: (chapters) {
          if (chapters.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.list_rounded, size: 64, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  Text(l.noToc,
                      style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: chapters.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final ch = chapters[index];
              return Material(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    if (ch.startPage != null) {
                      context.push('/reader/${ch.startPage}');
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).dividerTheme.color ?? AppColors.borderLight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              '${ch.sortOrder + 1}',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (ch.titleAr != null) ...[
                                Text(
                                  ch.titleAr!,
                                  style: TextStyle(
                                    fontFamily: 'Amiri',
                                    fontSize: 16,
                                    color: AppColors.gold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                              ],
                              Text(
                                ch.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                        if (ch.startPage != null)
                          Text(
                            '${ch.startPage}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        const SizedBox(width: 8),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 14, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
              ).animate().fadeIn(
                delay: Duration(milliseconds: 50 * index),
                duration: 300.ms,
              );
            },
          );
        },
      ),
    );
  }
}
