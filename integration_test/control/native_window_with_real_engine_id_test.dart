// Control for native_owner_test.dart: same app, same steps, but the binding
// (see flutter_test_config.dart) reports PlatformDispatcher.instance.engineId.
// The second window opens as a real native window and the test passes, on
// Linux and on Windows.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:windowing_integration_repro/main.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.instance;

  testWidgets('open a native second window with the real engine id', (
    tester,
  ) async {
    debugPrint(
      'binding: ${binding.runtimeType}, '
      'engineId: ${binding.platformDispatcher.engineId}',
    );

    await tester.pumpWidget(const ReproApp());
    await tester.tap(find.byKey(const Key('open-second-window')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('second-window-field')), findsOneWidget);
    // The engine itself now knows the second view.
    expect(PlatformDispatcher.instance.views, hasLength(2));
  });
}
