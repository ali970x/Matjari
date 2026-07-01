import 'package:flutter_test/flutter_test.dart';
import 'package:matjari/main.dart';

void main() {
  testWidgets('Matjari uses English store branding', (tester) async {
    await tester.pumpWidget(const MatjariApp());

    expect(find.text('Matjari'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
    expect(find.text('Forget password'), findsOneWidget);
  });
}
