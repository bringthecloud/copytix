import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_copytix/app/copytix_app.dart';

void main() {
  testWidgets('Copytix app displays correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const CopytixApp());

    // Memastikan halaman preview muncul.
    expect(find.text('Welcome to Copytix'), findsOneWidget);
    expect(find.text('Design System Preview'), findsOneWidget);

    // Memastikan counter dimulai dari 0.
    expect(find.text('0'), findsOneWidget);

    // Menguji tombol.
    await tester.tap(find.text('Test Button'));
    await tester.pump();

    // Memastikan counter berubah menjadi 1.
    expect(find.text('1'), findsOneWidget);
  });
}
