import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show AdaptiveTextSelectionToolbar, MaterialTextSelectionControls, desktopTextSelectionControls;

import '../controls/buttons.dart';
import '../foundation/input_feedback.dart';
import '../foundation/sizes.dart';
import '../foundation/tokens.dart';
import '_on_media_chrome_scope.dart';
import 'surface.dart';

final frostTextSelectionControls = _FrostSelectionControls();

/// Text editors start with desktop selection chrome until a direct pointer
/// actually interacts with this editor. Tracking is local: touching another
/// field must not put handles on an autofocused or programmatically focused one.
class FrostTextSelectionInput extends StatefulWidget {
  const FrostTextSelectionInput({required this.builder, super.key});
  final Widget Function(BuildContext, TextSelectionControls) builder;
  @override
  State<FrostTextSelectionInput> createState() => _TextSelectionInputState();
}

class _TextSelectionInputState extends State<FrostTextSelectionInput> {
  bool _direct = false;
  final _focus = FocusNode(canRequestFocus: false, skipTraversal: true);
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_key);
  }

  bool _key(KeyEvent event) {
    if (_focus.hasFocus && (event is KeyDownEvent || event is KeyRepeatEvent)) _setDirect(false);
    return false;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_key);
    _focus.dispose();
    super.dispose();
  }

  void _setDirect(bool direct) {
    if (_direct != direct) setState(() => _direct = direct);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) => _setDirect(switch (event.kind) {
        PointerDeviceKind.touch || PointerDeviceKind.stylus || PointerDeviceKind.invertedStylus => true,
        _ => false,
      }),
      child: Focus(
        focusNode: _focus,
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (focused) {
          if (!focused) _setDirect(false);
        },
        child: FrostInputBuilder(
          builder: (context, input) => widget.builder(context, input.mouseAvailable && !_direct ? desktopTextSelectionControls : frostTextSelectionControls),
        ),
      ),
    );
  }
}

class _FrostSelectionControls extends MaterialTextSelectionControls with TextSelectionHandleControls {
  @override
  Size getHandleSize(double textLineHeight) => const Size(18, 22);
  @override
  Offset getHandleAnchor(TextSelectionHandleType type, double textLineHeight) => const Offset(9, 0);
  @override
  Widget buildHandle(BuildContext context, TextSelectionHandleType type, double textHeight, [VoidCallback? onTap]) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: SizedBox(width: 18, height: 22, child: CustomPaint(painter: _SelectionHandlePainter(FrostThemeTokens.of(context).accentInk))),
  );
}

class _SelectionHandlePainter extends CustomPainter {
  const _SelectionHandlePainter(this.ink);
  final Color ink;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = ink;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(8, 0, 2, 15), const Radius.circular(1)), paint);
    canvas.drawCircle(const Offset(9, 16), 4, paint);
  }

  @override
  bool shouldRepaint(_SelectionHandlePainter old) => ink != old.ink;
}

Widget frostTextSelectionMenu(BuildContext context, EditableTextState editable) =>
    frostSelectionMenu(context, editable.contextMenuAnchors, editable.contextMenuButtonItems);

Widget frostSelectionMenu(BuildContext context, TextSelectionToolbarAnchors anchors, List<ContextMenuButtonItem> items) => frostWithoutOnMediaChrome(
  Padding(
    padding: const EdgeInsets.all(8),
    child: CustomSingleChildLayout(
      delegate: TextSelectionToolbarLayoutDelegate(
        anchorAbove: anchors.primaryAnchor - const Offset(8, 8),
        anchorBelow: (anchors.secondaryAnchor ?? anchors.primaryAnchor) - const Offset(8, 8),
      ),
      child: FrostSurface(
        role: FrostSurfaceRole.overlay,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Wrap(
            children: [
              for (final item in items)
                FrostButton.quiet(label: AdaptiveTextSelectionToolbar.getButtonLabel(context, item), onPressed: item.onPressed, size: FrostControlSize.compact),
            ],
          ),
        ),
      ),
    ),
  ),
);
