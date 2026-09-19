import 'package:flutter/material.dart';

import '../../core/theme/pr_theme.dart';
import '../../core/widgets/premium_panel.dart';

class ModuleScreen extends StatelessWidget {
  const ModuleScreen({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.features,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> features;

  @override
  Widget build(BuildContext context) {
    final Color accent = PrTheme.accent(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: accent.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: accent, size: 29),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1),
          ),
          const SizedBox(height: 7),
          Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 26),
          PremiumPanel(
            child: Column(
              children: features
                  .map(
                    (String feature) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: accent.withAlpha(90),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Text(
                              feature,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: accent),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
