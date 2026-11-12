import 'package:flutter/material.dart';

class AppThemeButton extends StatelessWidget {
  const AppThemeButton({
    super.key,
    required this.onPressed,
    this.onDarkBackground = false,
    this.labelOnWide = false,
  });

  final VoidCallback onPressed;
  final bool onDarkBackground;

  /// Shows the web's labelled control on desktop widths.
  final bool labelOnWide;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final french = Localizations.localeOf(context).languageCode == 'fr';
    final label = isDark
        ? (french ? 'Thème clair' : 'Light theme')
        : (french ? 'Thème sombre' : 'Dark theme');
    // Icon only on every width: the name stays in the tooltip and the accessible label.
    return IconButton(
      tooltip: label,
      onPressed: onPressed,
      icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      color: onDarkBackground
          ? Colors.white
          : Theme.of(context).colorScheme.primary,
    );
  }
}
