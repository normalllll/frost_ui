import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controls/_button_control.dart';
import '../controls/_button_types.dart';
import '../controls/_form_submit.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/typography.dart';
import '../primitives/text.dart';
import '_modal_frame.dart';
import '_modal_route.dart';
import 'adaptive_panel.dart';
import 'sheet.dart';

// Regular public text-button padding, also used by full-width modal actions.
const _actionTextInset = 16.0;

/// The sole dialog route entry. Local Frost preferences and the originating
/// focus cross the route boundary; keyboard/window metrics remain live.
Future<T?> showFrostDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  bool useRootNavigator = true,
}) => pushFrostModal<T>(
  context: context,
  builder: builder,
  barrierDismissible: barrierDismissible,
  barrierColor: barrierColor,
  useRootNavigator: useRootNavigator,
);

@immutable
class FrostDialogAction<T> {
  const FrostDialogAction({required this.label, this.value, this.role = FrostButtonRole.normal, this.isDefault = false, this.enabled = true, this.onPressed});
  final String label;
  final T? value;
  final FrostButtonRole role;
  final bool isDefault, enabled;

  /// Return false to keep the modal open, for example after validation fails.
  final FutureOr<bool> Function()? onPressed;
}

bool _validActions(List<FrostDialogAction<Object?>> actions) =>
    actions.where((action) => action.isDefault).length <= 1 && actions.where((action) => action.role == FrostButtonRole.cancel).length <= 1;

class FrostAlert extends StatelessWidget {
  FrostAlert({required this.title, this.message, required this.actions, super.key}) : assert(_validActions(actions));
  final String title;
  final String? message;
  final List<FrostDialogAction<Object?>> actions;

  @override
  Widget build(BuildContext context) => _ModalActionHost(
    actions: actions,
    builder: (context, buttons, contentFocus) => FrostModalSurface(
      width: frostAlertWidth,
      child: FrostModalFrame(
        header: FrostText(title, role: FrostTextRole.headline, tone: FrostTextTone.primary),
        headerGap: FrostGap.related,
        content: FocusScope(
          node: contentFocus,
          child: message == null ? const SizedBox.shrink() : FrostText(message!, role: FrostTextRole.callout, tone: FrostTextTone.secondary),
        ),
        footer: buttons,
      ),
    ),
  );
}

Future<T?> showFrostAlert<T>({
  required BuildContext context,
  required String title,
  String? message,
  required List<FrostDialogAction<T>> actions,
  bool barrierDismissible = true,
}) => showFrostDialog<T>(
  context: context,
  barrierDismissible: barrierDismissible,
  builder: (context) => FrostAlert(title: title, message: message, actions: actions),
);

enum FrostDialogSize { regular, wide }

class FrostDialog extends StatelessWidget {
  FrostDialog({
    required this.title,
    required this.content,
    this.actions = const [],
    this.size = FrostDialogSize.regular,
    this.showsCloseButton = false,
    this.scrollable = true,
    this.leadingAction,
    super.key,
  }) : assert(_validActions([?leadingAction, ...actions])),
       assert(leadingAction == null || !leadingAction.isDefault && leadingAction.role != FrostButtonRole.cancel);
  final String title;
  final Widget content;
  final List<FrostDialogAction<Object?>> actions;
  final FrostDialogSize size;
  final bool showsCloseButton;

  /// False gives a finite viewport and PrimaryScrollController to lazy content.
  final bool scrollable;

  /// An optional plain action at the logical start, separated from the main
  /// action group by flexible space. Use role: destructive for dangerous ink.
  /// Compact dialogs stack it above the main actions. The caller decides
  /// whether to ask for confirmation; async/loading/disabled behavior is shared.
  final FrostDialogAction<Object?>? leadingAction;

  @override
  Widget build(BuildContext context) => _ModalActionHost(
    actions: [?leadingAction, ...actions],
    leadingIndex: leadingAction == null ? null : 0,
    forceVertical: FrostAdaptiveDialogSheet.of(context) || leadingAction != null && frostPanelUsesSheet(context),
    builder: (context, buttons, contentFocus) {
      final sheet = FrostAdaptiveDialogSheet.of(context);
      final frame = FrostModalFrame(
        header: FrostModalHeader(title: title, showsCloseButton: showsCloseButton),
        content: FocusScope(node: contentFocus, child: content),
        scrollable: scrollable,
        scrollController: sheet ? PrimaryScrollController.maybeOf(context) : null,
        horizontalInset: sheet ? 0 : frostModalInset,
        topInset: sheet ? 0 : frostModalInset,
        bottomInset: sheet ? 0 : frostModalInset,
        footer: buttons,
      );
      return sheet ? frame : FrostModalSurface(width: size == FrostDialogSize.regular ? frostDialogWidth : frostWideDialogWidth, child: frame);
    },
  );
}

Future<bool> showFrostConfirm({
  required BuildContext context,
  required String title,
  String? message,
  required String confirmLabel,
  String? cancelLabel,
  bool destructive = true,
}) async {
  final actions = [
    FrostDialogAction<bool>(label: cancelLabel ?? FrostScope.labelsOf(context).cancel, value: false, role: FrostButtonRole.cancel),
    FrostDialogAction<bool>(label: confirmLabel, value: true, isDefault: true, role: destructive ? FrostButtonRole.destructive : FrostButtonRole.normal),
  ];
  if (!frostPanelUsesSheet(context)) {
    return await showFrostAlert<bool>(context: context, title: title, message: message, actions: actions) ?? false;
  }
  return await showFrostSheet<bool>(
        context: context,
        detents: const [FrostSheetDetent.fitted],
        showsCloseButton: false,
        builder: (context) => _ModalActionHost(
          actions: actions,
          forceVertical: true,
          builder: (context, buttons, contentFocus) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FrostText(title, role: FrostTextRole.headline, textAlign: TextAlign.center),
              if (message != null) ...[
                const SizedBox(height: FrostGap.related),
                FocusScope(
                  node: contentFocus,
                  child: FrostText(message, role: FrostTextRole.callout, tone: FrostTextTone.secondary, textAlign: TextAlign.center),
                ),
              ],
              const SizedBox(height: frostModalActionGap),
              buttons!,
            ],
          ),
        ),
      ) ??
      false;
}

typedef _ActionHostBuilder = Widget Function(BuildContext context, Widget? buttons, FocusScopeNode contentFocus);

class _ModalActionHost extends StatefulWidget {
  const _ModalActionHost({required this.actions, required this.builder, this.forceVertical = false, this.leadingIndex});
  final List<FrostDialogAction<Object?>> actions;
  final _ActionHostBuilder builder;
  final bool forceVertical;
  final int? leadingIndex;

  @override
  State<_ModalActionHost> createState() => _ModalActionHostState();
}

class _ModalActionHostState extends State<_ModalActionHost> {
  final _hostFocus = FocusScopeNode();
  final _contentFocus = FocusScopeNode();
  final _actionFocus = <FocusNode>[];
  int? _busy;
  int _operation = 0;

  @override
  void initState() {
    super.initState();
    _syncFocusNodes();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusInitially());
  }

  /// The button Enter would press on opening: the default action, or Cancel
  /// when the default is destructive. A caller's autofocus keeps its focus.
  void _focusInitially() {
    if (!mounted || _contentFocus.focusedChild != null) return;
    final actions = widget.actions;
    var index = actions.indexWhere((action) => action.isDefault);
    if (index >= 0 && actions[index].role == FrostButtonRole.destructive) index = actions.indexWhere((action) => action.role == FrostButtonRole.cancel);
    (index >= 0 && actions[index].enabled ? _actionFocus[index] : _hostFocus).requestFocus();
  }

  void _syncFocusNodes() {
    while (_actionFocus.length < widget.actions.length) {
      _actionFocus.add(FocusNode());
    }
    while (_actionFocus.length > widget.actions.length) {
      _actionFocus.removeLast().dispose();
    }
  }

  @override
  void didUpdateWidget(_ModalActionHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFocusNodes();
  }

  /// Closes for an action that has already decided. An open menu's history
  /// entry would swallow the pop and leave the dialog busy, so it goes first.
  void _close(ModalRoute<Object?> route, Object? value) {
    final navigator = Navigator.of(context);
    while (route.willHandlePopInternally) {
      navigator.pop();
    }
    navigator.pop(value);
  }

  Future<void> _run(int index) async {
    final action = widget.actions[index];
    if (!action.enabled || (_busy != null && action.role != FrostButtonRole.cancel)) return;
    final route = ModalRoute.of(context)!;
    if (action.onPressed == null) {
      _operation++;
      _close(route, action.value);
      return;
    }
    final operation = ++_operation;
    setState(() => _busy = index);
    var closes = false;
    try {
      closes = await action.onPressed!();
    } catch (error, stack) {
      if (mounted && operation == _operation && route.isActive) {
        FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'frost_ui'));
      }
    }
    if (!mounted || operation != _operation || !route.isActive) return;
    if (closes && route.isCurrent) {
      _close(route, action.value);
    } else {
      setState(() => _busy = null);
      // A loading button gives up focus; hand it back if nothing else took it.
      // The action may have changed the list: with its slot gone or disabled,
      // focus stays on the dialog.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _hostFocus.hasPrimaryFocus && index < widget.actions.length && widget.actions[index].enabled) _actionFocus[index].requestFocus();
      });
    }
  }

  /// Keys arrive here only after the focused control and its ancestors passed
  /// on them. Enter belongs to the focused button, so only Escape stops here.
  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.escape) return KeyEventResult.ignored;
    final index = widget.actions.indexWhere((action) => action.role == FrostButtonRole.cancel);
    if (index < 0) return KeyEventResult.ignored;
    // A disabled cancel consumes Escape, including the route's scrim fallback.
    if (!widget.actions[index].enabled) return KeyEventResult.handled;
    if (frostModalCanDismiss(context)) {
      unawaited(_run(index));
    } else {
      unawaited(frostDismissModal(context));
    }
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _operation++;
    _hostFocus.dispose();
    _contentFocus.dispose();
    for (final node in _actionFocus) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final indices = List.generate(widget.actions.length, (index) => index);
    final cancel = indices.where((index) => widget.actions[index].role == FrostButtonRole.cancel).toList();
    final defaults = indices.where((index) => widget.actions[index].isDefault && widget.actions[index].role != FrostButtonRole.cancel).toList();
    final other = indices.where((index) => index != widget.leadingIndex && !cancel.contains(index) && !defaults.contains(index)).toList();
    final buttons = widget.actions.isEmpty
        ? null
        : FrostModalActionBar(
            forceVertical: widget.forceVertical,
            leadingIndex: widget.leadingIndex,
            horizontalOrder: [?widget.leadingIndex, ...cancel, ...other, ...defaults],
            verticalOrder: [?widget.leadingIndex, ...defaults, ...other, ...cancel],
            children: [
              for (final (index, action) in widget.actions.indexed)
                LayoutBuilder(
                  builder: (context, constraints) => FrostButtonControl(
                    label: action.label,
                    variant: index == widget.leadingIndex
                        ? FrostButtonVariant.plain
                        : action.isDefault
                        ? FrostButtonVariant.prominent
                        : FrostButtonVariant.standard,
                    role: action.role,
                    size: FrostControlSize.regular,
                    focusNode: _actionFocus[index],
                    wrapsLabel: true,
                    truncates: false,
                    activity: FrostButtonActivity(loading: _busy == index),
                    geometry: FrostButtonGeometry(
                      horizontalInset: _actionTextInset,
                      verticalInset: 0,
                      minimumWidth: constraints.hasTightWidth ? constraints.maxWidth : 0,
                      alignment: MainAxisAlignment.center,
                    ),
                    onPressed: action.enabled && (_busy == null || action.role == FrostButtonRole.cancel) ? () => _run(index) : null,
                  ),
                ),
            ],
          );
    return FocusScope(
      node: _hostFocus,
      onKeyEvent: _key,
      child: FrostDialogSubmitScope(
        // Finishing a field runs the default action, unless that is destructive:
        // those take a press on the button itself.
        submit: () async {
          final index = widget.actions.indexWhere((action) => action.isDefault);
          if (index >= 0 && widget.actions[index].role != FrostButtonRole.destructive) await _run(index);
        },
        child: widget.builder(context, buttons, _contentFocus),
      ),
    );
  }
}
