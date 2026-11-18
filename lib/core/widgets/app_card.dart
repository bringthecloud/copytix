import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_tokens.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSizes.cardPadding,
    this.backgroundColor = AppColors.surface,
    this.borderColor = AppColors.border,
    this.showShadow = true,
  });

  final Widget child;
  final double padding;
  final Color backgroundColor;
  final Color borderColor;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: borderColor),
        boxShadow: showShadow
            ? [
                const BoxShadow(
                  color: Color(0x0A29283B),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: child,
    );
  }
}
