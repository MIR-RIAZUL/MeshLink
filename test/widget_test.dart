import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/main.dart';
import 'device_discovery_controller_test.dart';

void main() {
  testWidgets('shows the MeshLink home screen with Bluetooth state', (tester) async {
    final fakeService = FakeDeviceDiscoveryService();
    await tester.pumpWidget(MeshLinkApp(service: fakeService));
    await tester.pumpAndSettle();

    expect(find.text('MeshLink'), findsWidgets);
    expect(find.text('Bluetooth Required'), findsOneWidget);
    expect(find.text('Turn On Bluetooth'), findsOneWidget);
  });
}

