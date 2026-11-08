// Problem 1: with the stock IntegrationTestWidgetsFlutterBinding, a
// WindowController is flutter_test's stand-in view (the engine never hears of
// it), but text input is NOT faked (registerTestTextInput is false). So a
// TextField in that window talks to the real platform text input plugin with
// a viewId the engine does not know.
//
// Windows: fails with
//   PlatformException(Internal Consistency Error, Text input is not available
//   because view with view_id=1 cannot be found, null, null)
// Linux: passes (its plugin does not look the view up).
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:windowing_integration_repro/main.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('type into a TextField in a second window', (tester) async {
    await tester.pumpWidget(const ReproApp());
    await tester.tap(find.byKey(const Key('open-second-window')));
    await tester.pumpAndSettle();

    final views = binding.platformDispatcher.views.map((v) => v.viewId);
    debugPrint('platformDispatcher.views: ${views.toList()}');
    debugPrint(
      'engine views: '
      '${PlatformDispatcher.instance.views.map((v) => v.viewId).toList()}',
    );

    final field = find.byKey(const Key('second-window-field'));
    expect(field, findsOneWidget);

    // Focusing the field opens a text input connection; on Windows the
    // plugin's setEditableSizeAndTransform / setMarkedTextRect / clearClient
    // calls fail because the view id is a test-only view.
    await tester.showKeyboard(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, 'hello');
    await tester.pumpAndSettle();
    expect(find.text('hello'), findsOneWidget);

    // Unfocus -> clearClient.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  });
}
