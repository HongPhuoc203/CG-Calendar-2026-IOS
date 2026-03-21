import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Reusable stat card for dashboard
class StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? iconColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final Widget? badge;

  const StatCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.iconColor,
    this.backgroundColor,
    this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderDark,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor ?? AppColors.primary,
                  size: 24,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                badge!,
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textDarkSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: card,
      );
    }

    return card;
  }
}
