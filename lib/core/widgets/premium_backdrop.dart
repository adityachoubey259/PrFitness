import 'package:flutter/material.dart';

import '../theme/pr_theme.dart';

class PremiumBackdrop extends StatelessWidget {
  const PremiumBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool dark = PrTheme.isBlackGold(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: dark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFF050506),
                  Color(0xFF0D0C09),
                  Color(0xFF11100C),
                  Color(0xFF070708),
                ],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFFFFFBFD),
                  Color(0xFFFFF4F8),
                  Color(0xFFFFFAFC),
                  Color(0xFFFFEEF5),
                ],
              ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -120,
            right: -90,
            child: _GlowOrb(
              size: 330,
              color: dark ? const Color(0xFFDDBB58) : const Color(0xFFFF4F91),
            ),
          ),
          Positioned(
            bottom: -170,
            left: -120,
            child: _GlowOrb(
              size: 380,
              color: dark ? const Color(0xFF725313) : const Color(0xFFFF9FC0),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              color.withAlpha(50),
              color.withAlpha(15),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}
