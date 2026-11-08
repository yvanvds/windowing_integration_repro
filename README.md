# windowing_integration_repro

Minimal reproduction for [flutter/flutter#195919](https://github.com/flutter/flutter/issues/195919):
`integration_test` cannot test secondary windows made with the experimental
windowing API.

- **Flutter:** master `934720261be051307da25be7911628d61ccb8b72` (pinned in `.fvmrc`)
- **Setup:** `flutter config --enable-windowing`
- **Platforms:** Windows, Linux (x64)

## The app

[`lib/main.dart`](lib/main.dart): the main view shows one button. Pressing it
creates a `WindowController` and shows a `Window` (through a `ViewAnchor`) that
holds a `TextField`. Run normally (`flutter run -d linux` / `-d windows`), the
second window opens and accepts typing.

## Problem 1: stand-in view reaches the real text input plugin (Windows)

[`integration_test/text_input_test.dart`](integration_test/text_input_test.dart)
uses the stock `IntegrationTestWidgetsFlutterBinding`, opens the second window
and types into its `TextField`.

```
flutter test integration_test/text_input_test.dart -d windows
```

`TestWidgetsFlutterBinding.createWindowingOwner` installs `_TestWindowingOwner`,
so the second window is a test-only view that the engine never sees
(`binding.platformDispatcher.views` is `[0, 1]`, `PlatformDispatcher.instance.views`
is `[0]`). The integration binding does not register `TestTextInput`, though, so
the field's text input connection goes to the real platform plugin with
`viewId` 1.

- **Windows:** fails. `setEditableSizeAndTransform`, `setMarkedTextRect` and
  `clearClient` each throw:
  ```
  PlatformException(Internal Consistency Error, Text input is not available because view with view_id=1 cannot be found, null, null)
  #2 _PlatformTextInputControl.setEditableSizeAndTransform.<anonymous closure> (package:flutter/src/services/text_input.dart)
  ```
- **Linux:** passes, because the GTK plugin does not look the view up.

## Problem 2: a native windowing owner segfaults (Linux)

[`integration_test/native_owner_test.dart`](integration_test/native_owner_test.dart)
tries to get real native windows instead. The integration entry point creates the
binding before `main`, so the test cannot subclass it; it swaps the owner after
`ensureInitialized()`:

```dart
final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
binding.windowingOwner = createDefaultWindowingOwner();
```

```
flutter test integration_test/native_owner_test.dart -d linux
```

The test prints

```
TestPlatformDispatcher.engineId: 1
PlatformDispatcher.instance.engineId: 7789232
```

and the app crashes on the first `WindowController(...)`. `flutter test` only
reports `did not complete`. The native stack, from a profile build of the same
entry point under gdb:

```
Thread 1 "windowing_integ" received signal SIGSEGV, Segmentation fault.
#0 g_type_check_instance_is_fundamentally_a () at /lib64/libgobject-2.0.so.0
#1 g_object_ref () at /lib64/libgobject-2.0.so.0
#2 fl_view_new_for_engine () at .../bundle/lib/libflutter_linux_gtk.so
#3 <Dart frames>
```

`TestPlatformDispatcher.engineId` is hard-coded to `1`
(`packages/flutter_test/lib/src/window.dart`). On Linux the engine id is the
`FlEngine*` address, so the Linux owner calls `fl_view_new_for_engine` on address `0x1`.

## Control: forwarding the real engine id

[`integration_test/control/`](integration_test/control/) runs the same scenario,
but its `flutter_test_config.dart` installs a subclass of
`IntegrationTestWidgetsFlutterBinding` before the entry point creates the stock
one. That subclass changes two things:

- `registerTestWindowingOwner => false`, so the platform's owner is used
- a `TestPlatformDispatcher` whose `engineId` returns `PlatformDispatcher.instance.engineId`

With those two changes the second window is a real native window (the engine
reports two views) and the test passes.

```
flutter test integration_test/control/native_window_with_real_engine_id_test.dart -d windows
```

On Linux the control needs a real display. Under Xvfb a second native Flutter
window fails with a GLX `BadAccess` even in the plain app outside any test, which
is a headless GL limit and not related to this issue.

## CI

[`.github/workflows/repro.yaml`](.github/workflows/repro.yaml) runs each test
as its own job on `windows-latest` and `ubuntu-latest` at the pinned revision.

## Expected

A live test binding (`integration_test`) should either

- forward `engineId` to the real dispatcher and let tests opt into the platform
  windowing owner, or
- keep test windows and test text input consistent, so text input from a
  test-only view never reaches a platform plugin that cannot know that view.
