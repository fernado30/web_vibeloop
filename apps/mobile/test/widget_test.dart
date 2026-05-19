import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:vibeloop_mobile/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Vibeloop app smoke test', (WidgetTester tester) async {
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'example-anon-key',
    );

    await tester.pumpWidget(const ProviderScope(child: VibeloopApp()));
    await tester.pumpAndSettle();

    expect(find.text('VIBELOOP'), findsWidgets);
  });
}
