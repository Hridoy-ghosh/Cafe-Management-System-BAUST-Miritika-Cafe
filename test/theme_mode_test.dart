import 'package:baust_nexus/config/app_theme.dart';
import 'package:baust_nexus/services/theme_controller.dart';
import 'package:baust_nexus/widgets/theme_mode_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('theme button toggles and persists the selected mode',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = ThemeController(isDarkMode: false);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: Consumer<ThemeController>(
          builder: (context, themeController, _) => MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeController.themeMode,
            home: Scaffold(
              appBar: AppBar(actions: const [ThemeModeButton()]),
              body: const Text('Cafe home'),
            ),
          ),
        ),
      ),
    );

    expect(Theme.of(tester.element(find.text('Cafe home'))).brightness,
        Brightness.light);

    await tester.tap(find.byTooltip('Switch to dark mode'));
    await tester.pumpAndSettle();

    expect(Theme.of(tester.element(find.text('Cafe home'))).brightness,
        Brightness.dark);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('cafe_dark_mode'), isTrue);

    await tester.tap(find.byTooltip('Switch to light mode'));
    await tester.pumpAndSettle();

    expect(Theme.of(tester.element(find.text('Cafe home'))).brightness,
        Brightness.light);
    expect(preferences.getBool('cafe_dark_mode'), isFalse);
  });
}
