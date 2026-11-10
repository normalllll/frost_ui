import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// [key] pressed or held, whatever modifiers are down. Releases never match.
class FrostKeyPress extends ShortcutActivator {
  const FrostKeyPress(this.key, {this.press = true, this.repeat = true});
  final LogicalKeyboardKey key;

  /// Whether the first press and the auto-repeats while held match.
  final bool press, repeat;

  @override
  Iterable<LogicalKeyboardKey> get triggers => [key];

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) => event.logicalKey == key && (press && event is KeyDownEvent || repeat && event is KeyRepeatEvent);

  @override
  String debugDescribeKeys() => key.debugName ?? key.keyLabel;
}

/// A component's own keys, through Flutter's [Shortcuts] and [Actions], active
/// while focus is inside [child]. A handler returns whether it took the key;
/// one that did not lets the key go on to the enclosing widgets, as if it were
/// not bound here.
class FrostKeyBindings extends StatelessWidget {
  const FrostKeyBindings({required this.bindings, required this.child, super.key});
  final Map<ShortcutActivator, bool Function()> bindings;
  final Widget child;

  @override
  Widget build(BuildContext context) => Shortcuts(
    shortcuts: {for (final MapEntry(:key, :value) in bindings.entries) key: _KeyIntent(value)},
    child: Actions(actions: {_KeyIntent: _KeyAction()}, child: child),
  );
}

/// Escape bound to [DismissIntent] at a component that dismisses something
/// inside a page (a selection, a grab, a text selection). Binding it here puts
/// the component ahead of an Escape the app binds around its pages; while no
/// enabled dismiss action is in reach, the key goes on to the app.
///
/// [active] narrows the binding to while the component has something to
/// dismiss, for a child that consumes [DismissIntent] itself even then.
class FrostDismissKey extends StatefulWidget {
  const FrostDismissKey({required this.child, this.active, super.key});
  final Widget child;
  final bool Function()? active;

  @override
  State<FrostDismissKey> createState() => _FrostDismissKeyState();
}

class _FrostDismissKeyState extends State<FrostDismissKey> {
  late final _manager = _WhenShortcutManager(() => widget.active?.call() ?? true);

  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Shortcuts.manager(manager: _manager, child: widget.child);
}

class _WhenShortcutManager extends ShortcutManager {
  _WhenShortcutManager(this.active) : super(shortcuts: const {SingleActivator(LogicalKeyboardKey.escape): DismissIntent()});
  final bool Function() active;

  @override
  KeyEventResult handleKeypress(BuildContext context, KeyEvent event) => active() ? super.handleKeypress(context, event) : KeyEventResult.ignored;
}

class _KeyIntent extends Intent {
  const _KeyIntent(this.handle);
  final bool Function() handle;
}

class _KeyAction extends Action<_KeyIntent> {
  @override
  Object? invoke(_KeyIntent intent) => intent.handle();

  @override
  KeyEventResult toKeyEventResult(_KeyIntent intent, covariant Object? invokeResult) => invokeResult == true ? KeyEventResult.handled : KeyEventResult.ignored;
}
