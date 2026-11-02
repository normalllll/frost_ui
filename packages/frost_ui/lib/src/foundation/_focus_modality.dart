import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show EditableTextState, FocusManager;

/// The library's one record of what the user is doing with their hands: whether
/// focus rings may show, the latest pointer kind, and which kinds have appeared.
/// It only listens: focus ownership and the framework's highlight policy stay
/// with the app. Subscriptions exist while `FrostApp` or a shared interactive
/// surface is mounted.
class FrostInputModality extends ChangeNotifier {
  static final instance = FrostInputModality._();
  FrostInputModality._();
  var _clients = 0;
  bool _keyboard = true, _mouseSeen = false;
  PointerDeviceKind? _pointerKind;

  /// Whether a focus ring may show. A pointer press hides it and a key that
  /// navigates brings it back; typing, Escape, Enter, shortcuts, modifiers and
  /// moving the mouse change nothing.
  bool get keyboard => _keyboard;

  /// Whether the latest pointer was a finger on the screen.
  bool get touch => _pointerKind == PointerDeviceKind.touch;

  /// Whether no pointer has been recorded yet.
  bool get noPointerYet => _pointerKind == null;

  /// Whether a mouse has moved or pressed since the app started.
  bool get mouseSeen => _mouseSeen;

  // Layout can synthesize mouse enter events while a stationary mouse remains
  // over content. Only real pointer movement may restore hover after touch.
  bool acceptsHover(PointerEvent event) => event.kind != PointerDeviceKind.touch && (!touch || event is PointerHoverEvent);
  void attach() {
    if (_clients++ != 0) return;
    _reset();
    GestureBinding.instance.pointerRouter.addGlobalRoute(_pointer);
    HardwareKeyboard.instance.addHandler(_key);
  }

  void detach() {
    assert(_clients > 0);
    if (--_clients != 0) return;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_pointer);
    HardwareKeyboard.instance.removeHandler(_key);
    _reset();
  }

  void _reset() {
    _keyboard = true;
    _mouseSeen = false;
    _pointerKind = null;
  }

  void _pointer(PointerEvent event) {
    final press = event is PointerDownEvent;
    if (!press && (event is! PointerHoverEvent || event.kind == PointerDeviceKind.touch)) return;
    final keyboard = press ? false : _keyboard;
    final mouseSeen = _mouseSeen || event.kind == PointerDeviceKind.mouse;
    if (keyboard == _keyboard && event.kind == _pointerKind && mouseSeen == _mouseSeen) return;
    _keyboard = keyboard;
    _pointerKind = event.kind;
    _mouseSeen = mouseSeen;
    notifyListeners();
  }

  bool _key(KeyEvent event) {
    if ((event is KeyDownEvent || event is KeyRepeatEvent) && !_keyboard && _navigates(event.logicalKey)) {
      _keyboard = true;
      notifyListeners();
    }
    return false;
  }

  static final _caretKeys = {
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.home,
    LogicalKeyboardKey.end,
    LogicalKeyboardKey.pageUp,
    LogicalKeyboardKey.pageDown,
  };

  // Alt+Tab and Ctrl+Tab belong to the system and the App, not to focus.
  // Arrows and the like move the caret while an editor has focus.
  bool _navigates(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.tab) {
      final keys = HardwareKeyboard.instance;
      return !keys.isAltPressed && !keys.isControlPressed && !keys.isMetaPressed;
    }
    return _caretKeys.contains(key) && FocusManager.instance.primaryFocus?.context?.findAncestorStateOfType<EditableTextState>() == null;
  }
}
