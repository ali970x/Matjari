import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:matjari/main.dart';

void main() {
  testWidgets('Matjari uses English store branding', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('matjari/native'),
          (call) async => switch (call.method) {
            'loadSession' => null,
            'packageAliases' => <String, String>{},
            _ => null,
          },
        );
    await tester.pumpWidget(const MatjariApp());
    await tester.pump();
    await tester.pump();

    expect(find.text('Matjari'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
    expect(find.text('Forget password'), findsOneWidget);
  });
}
