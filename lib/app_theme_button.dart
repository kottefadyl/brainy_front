import 'package:flutter/material.dart';

class AppThemeButton extends StatelessWidget {
  const AppThemeButton({
    super.key,
    required this.onPressed,
    this.onDarkBackground = false,
  });

  final VoidCallback onPressed;
  final bool onDarkBackground;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final french = Localizations.localeOf(context).languageCode == 'fr';
    final label = isDark
        ? (french ? 'Thème clair' : 'Light theme')
        : (french ? 'Thème sombre' : 'Dark theme');
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
