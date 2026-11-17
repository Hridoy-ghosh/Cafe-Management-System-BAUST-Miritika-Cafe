import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/theme_controller.dart';

class ThemeModeButton extends StatelessWidget {
  const ThemeModeButton({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    final isDarkMode = themeController.isDarkMode;

    return IconButton(
      tooltip: isDarkMode ? 'Switch to light mode' : 'Switch to dark mode',
      onPressed: () async {
        try {
          await themeController.toggleTheme();
        } catch (error) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save theme preference: $error')),
          );
        }
      },
      icon: Icon(
        isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        color: color,
      ),
    );
  }
}
