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
    if (labelOnWide && MediaQuery.sizeOf(context).width >= 860) {
      return Tooltip(
        message: label,
        child: TextButton.icon(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            minimumSize: const Size(0, 44),
            textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600),
          ),
          icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 18),
          label: Text(
            isDark
                ? (french ? 'Clair' : 'Light')
                : (french ? 'Sombre' : 'Dark'),
          ),
        ),
      );
    }
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
