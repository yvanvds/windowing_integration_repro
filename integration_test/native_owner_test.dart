// Problem 2: the integration binding cannot be subclassed before the
// integration entry point creates it, so the obvious way to get real native
// windows is to swap the windowing owner after ensureInitialized(). That
// owner reads binding.platformDispatcher.engineId, which TestPlatformDispatcher
// hard-codes to 1 (packages/flutter_test/lib/src/window.dart). On Linux the
// engine id is the FlEngine* address, so the first WindowController
// dereferences address 0x1:
//
//   #0 g_type_check_instance_is_fundamentally_a (libgobject-2.0.so.0)
//   #1 g_object_ref (libgobject-2.0.so.0)
//   #2 fl_view_new_for_engine (libflutter_linux_gtk.so)
//
// The test app crashes; `flutter test` reports the device connection lost.
// ignore_for_file: invalid_use_of_internal_member, implementation_imports
import 'dart:ui';

import 'package:flutter/src/widgets/_window.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:windowing_integration_repro/main.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.windowingOwner = createDefaultWindowingOwner();

  testWidgets('open a native second window under the integration binding', (
    tester,
  ) async {
    debugPrint(
      'TestPlatformDispatcher.engineId: '
      '${binding.platformDispatcher.engineId}',
    );
    debugPrint(
      'PlatformDispatcher.instance.engineId: '
      '${PlatformDispatcher.instance.engineId}',
    );

    await tester.pumpWidget(const ReproApp());
    // WindowController(...) is created here -> crash on Linux.
    await tester.tap(find.byKey(const Key('open-second-window')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('second-window-field')), findsOneWidget);
  });
}
