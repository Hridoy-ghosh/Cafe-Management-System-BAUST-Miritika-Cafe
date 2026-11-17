import 'package:baust_nexus/main.dart';
import 'package:baust_nexus/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://cafe-theme-test.supabase.co',
      anonKey: 'cafe-theme-test-key',
    );
  });

  testWidgets('login theme toggle does not produce framework errors',
      (tester) async {
    await tester.pumpWidget(const BAUSTNexusApp(supabaseConfigured: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Switch to dark mode'));
    await tester.pumpAndSettle();

    final darkTheme = Theme.of(tester.element(find.byType(LoginScreen)));
    expect(darkTheme.brightness, Brightness.dark);
    expect(
      darkTheme.elevatedButtonTheme.style?.textStyle?.resolve({})?.fontSize,
      16,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Switch to light mode'));
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.byType(LoginScreen))).brightness,
      Brightness.light,
    );
    expect(tester.takeException(), isNull);
  });
}
