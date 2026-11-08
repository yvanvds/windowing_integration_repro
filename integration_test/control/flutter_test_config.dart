// Control: installs a binding before the integration entry point creates the
// stock one. It differs from IntegrationTestWidgetsFlutterBinding only in
// (a) not installing flutter_test's test windowing owner and (b) reporting
// the real engine id. With that, the native-owner scenario works.
import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

class _RealEngineIdDispatcher extends TestPlatformDispatcher {
  _RealEngineIdDispatcher()
    : super(platformDispatcher: PlatformDispatcher.instance);

  @override
  int? get engineId => PlatformDispatcher.instance.engineId;
}

class _NativeWindowsBinding extends IntegrationTestWidgetsFlutterBinding {
  @override
  bool get registerTestWindowingOwner => false;

  @override
  TestPlatformDispatcher get platformDispatcher => _dispatcher;
  late final TestPlatformDispatcher _dispatcher = _RealEngineIdDispatcher();
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  _NativeWindowsBinding();
  await testMain();
}
