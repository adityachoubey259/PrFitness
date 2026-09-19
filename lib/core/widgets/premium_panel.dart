import 'package:flutter/material.dart';

import '../theme/pr_theme.dart';

class PremiumPanel extends StatelessWidget {
  const PremiumPanel({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 28,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final bool dark = PrTheme.isBlackGold(context);
    final Color accent = PrTheme.accent(context);

    final Color surface = dark
        ? const Color(0xEC141416)
        : const Color(0xF7FFFFFF);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            accent.withAlpha(dark ? 120 : 70),
            accent.withAlpha(8),
            Colors.transparent,
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: dark
                ? Colors.black.withAlpha(110)
                : const Color(0xFFFF3F83).withAlpha(18),
            blurRadius: dark ? 34 : 30,
            spreadRadius: -8,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: const EdgeInsets.all(1),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(borderRadius - 1),
        ),
        child: child,
      ),
    );
  }
}
