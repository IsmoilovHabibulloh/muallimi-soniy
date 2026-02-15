import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

class CopyrightFooter extends StatelessWidget {
  const CopyrightFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Divider
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 0.5,
                color: AppColors.primary.withOpacity(0.2),
              ),
              const SizedBox(width: 8),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.25),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 0.5,
                color: AppColors.primary.withOpacity(0.2),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "O'zbekiston Musulmonlar Idorasi",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? Colors.white.withOpacity(0.4)
                  : AppColors.primary.withOpacity(0.45),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '© 2014 — Barcha huquqlar himoyalangan',
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? Colors.white.withOpacity(0.25)
                  : AppColors.primary.withOpacity(0.3),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
