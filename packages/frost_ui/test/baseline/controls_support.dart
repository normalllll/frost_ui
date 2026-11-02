// Helpers shared by the controls baseline files: owned controllers and focus
// nodes, so a case builder can stay a plain expression.
import 'package:flutter/material.dart';

/// Builds [builder] with a [TextEditingController] (starting at [text]) and a
/// [FocusNode] that live and are disposed with this widget.
class BaselineField extends StatefulWidget {
  const BaselineField({required this.builder, this.text = '', super.key});

  final String text;
  final Widget Function(BuildContext context, TextEditingController controller, FocusNode focusNode) builder;

  @override
  State<BaselineField> createState() => _BaselineFieldState();
}

class _BaselineFieldState extends State<BaselineField> {
  late final _controller = TextEditingController(text: widget.text);
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controller, _focus);
}

/// Builds [builder] with a [FocusNode] that is disposed with this widget.
class BaselineFocus extends StatefulWidget {
  const BaselineFocus({required this.builder, super.key});

  final Widget Function(BuildContext context, FocusNode focusNode) builder;

  @override
  State<BaselineFocus> createState() => _BaselineFocusState();
}

class _BaselineFocusState extends State<BaselineFocus> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _focus);
}

/// Creates a [ChangeNotifier] (a token or form controller, for example) once
/// and disposes it with this widget.
class BaselineOwned<T extends ChangeNotifier> extends StatefulWidget {
  const BaselineOwned({required this.create, required this.builder, super.key});

  final T Function() create;
  final Widget Function(BuildContext context, T owned) builder;

  @override
  State<BaselineOwned<T>> createState() => _BaselineOwnedState<T>();
}

class _BaselineOwnedState<T extends ChangeNotifier> extends State<BaselineOwned<T>> {
  late final T _owned = widget.create();

  @override
  void dispose() {
    _owned.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _owned);
}
