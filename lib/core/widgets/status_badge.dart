import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_tokens.dart';

enum BadgeVariant { primary, success, warning, danger, info, neutral }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.variant = BadgeVariant.neutral,
    this.icon,
  });

  final String label;
  final BadgeVariant variant;
  final IconData? icon;

  Color get backgroundColor {
    switch (variant) {
      case BadgeVariant.primary:
        return AppColors.lavender;
      case BadgeVariant.success:
        return AppColors.successBg;
      case BadgeVariant.warning:
        return AppColors.warningBg;
      case BadgeVariant.danger:
        return AppColors.dangerBg;
      case BadgeVariant.info:
        return AppColors.infoBg;
      case BadgeVariant.neutral:
        return AppColors.surfaceAlt;
    }
  }

  Color get foregroundColor {
    switch (variant) {
      case BadgeVariant.primary:
        return AppColors.primaryDark;
      case BadgeVariant.success:
        return AppColors.success;
      case BadgeVariant.warning:
        return AppColors.warning;
      case BadgeVariant.danger:
        return AppColors.danger;
      case BadgeVariant.info:
        return AppColors.info;
      case BadgeVariant.neutral:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foregroundColor),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
