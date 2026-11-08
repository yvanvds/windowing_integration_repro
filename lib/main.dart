// The windowing API is experimental and @internal on master.
// ignore_for_file: invalid_use_of_internal_member, implementation_imports
import 'package:flutter/src/widgets/_window.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  runApp(const ReproApp());
}

/// The implicit (main) view has one button. Pressing it opens a second
/// top-level window, through Flutter's windowing API, that holds a TextField.
class ReproApp extends StatefulWidget {
  const ReproApp({super.key});

  @override
  State<ReproApp> createState() => _ReproAppState();
}

class _ReproAppState extends State<ReproApp> {
  WindowController? _second;

  void _openSecondWindow() {
    if (_second != null) return;
    setState(() {
      _second = WindowController(
        size: const Size(400, 300),
        title: 'Second window',
      );
    });
  }

  @override
  void dispose() {
    _second?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final second = _second;
    return ViewAnchor(
      view: second == null
          ? null
          : Window(
              controller: second,
              child: const MaterialApp(
                home: Scaffold(
                  body: Padding(
                    padding: EdgeInsets.all(16),
                    child: TextField(key: Key('second-window-field')),
                  ),
                ),
              ),
            ),
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const Key('open-second-window'),
              onPressed: _openSecondWindow,
              child: const Text('Open second window'),
            ),
          ),
        ),
      ),
    );
  }
}
