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

**Windows** fails even earlier. The `WindowingOwnerWin32` constructor passes
`platformDispatcher.engineId` to `initializeWindowing` straight away, so the
app dies on the owner swap itself, before the test body runs (no `engineId`
lines are printed). `flutter test -d windows` reports:

```
Failed to load ".../integration_test/native_owner_test.dart": Connection closed before test suite loaded.
```

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
flutter test integration_test/control/native_window_with_real_engine_id_test.dart -d linux
```

It passes on Windows, and on Linux under Wayland.

## Running on Linux without a desktop

Every Linux result here was checked on Wayland, in a headless compositor, so
no windows open on the desktop. For example, with KWin:

```
kwin_wayland --virtual --width 1920 --height 1080 --socket wayland-repro \
  --exit-with-session "env -u DISPLAY WAYLAND_DISPLAY=wayland-repro GDK_BACKEND=wayland \
  flutter test integration_test/<file>.dart -d linux"
```

or with Weston (`weston --backend=headless --socket=wayland-repro &`, then the
same `env ... flutter test` line), which is what CI does.

Avoid Xvfb for this repro. The two bug tests behave the same under Xvfb, but a
second native window fails with a GLX `BadAccess` (`request_code 150 (GLX)
minor_code 26`) there, even in the plain app outside any test, so the control
cannot pass.

## CI

[`.github/workflows/repro.yaml`](.github/workflows/repro.yaml) runs each test
as its own job on `windows-latest` and on `ubuntu-latest` (headless Weston) at
the pinned revision.

| Test | Windows | Linux (Wayland) |
| --- | --- | --- |
| `text_input_test.dart` | fails: 3x `PlatformException`, view_id=1 | passes |
| `native_owner_test.dart` | fails: app dies at the owner swap | fails: segfault |
| `control/native_window_with_real_engine_id_test.dart` | passes | passes |

## Expected

A live test binding (`integration_test`) should either

- forward `engineId` to the real dispatcher and let tests opt into the platform
  windowing owner, or
- keep test windows and test text input consistent, so text input from a
  test-only view never reaches a platform plugin that cannot know that view.
