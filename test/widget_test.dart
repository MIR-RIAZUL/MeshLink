import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/main.dart';

void main() {
  testWidgets('shows the MeshLink home screen', (tester) async {
    await tester.pumpWidget(const MeshLinkApp());

    expect(find.text('MeshLink'), findsOneWidget);
    expect(find.text('Discover Devices'), findsOneWidget);
  });
}
