import 'package:flutter_test/flutter_test.dart';
import 'package:note_google_drive/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const NotesApp());
  });
}
