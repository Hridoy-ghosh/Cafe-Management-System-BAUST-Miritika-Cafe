import 'package:flutter_test/flutter_test.dart';
import 'package:baust_nexus/main.dart';

void main() {
  testWidgets('Cafe app explains when Supabase is not configured',
      (WidgetTester tester) async {
    await tester.pumpWidget(const BAUSTNexusApp(supabaseConfigured: false));
    expect(find.byType(BAUSTNexusApp), findsOneWidget);
    expect(
      find.text('Dedicated cafe database is not configured'),
      findsOneWidget,
    );
  });
}
