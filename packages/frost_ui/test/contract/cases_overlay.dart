// Dialogs, sheets, confirmations, form dialogs, menus and popovers. Every case
// opens an overlay that shows `overlayMarker`; cases whose content cannot hold
// a caller's PopScope skip the PopScope checks.
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'harness.dart';

const _noContentSlot = 'the content is built by the component, so a caller cannot place a PopScope in it';
const _data = {'popscope-esc': _noContentSlot, 'popscope-close': _noContentSlot, 'popscope-drag': _noContentSlot, 'popscope-back': _noContentSlot};
const _noCloseButton = {'popscope-close': 'a popover has no close button'};
const _noBarrierFlag = {'barrier': 'it has no barrierDismissible parameter'};

final _closeButton = find.byWidgetPredicate((widget) => widget is FrostTooltip && widget.message == 'L.close');
Widget _open(String label, VoidCallback toggle) => FrostButton(label: label, onPressed: toggle);
const _phone = Size(400, 800);

final overlayCases = <OverlayCase>[
  OverlayCase(
    'showFrostDialog',
    open: (context, o) => showFrostDialog<void>(
      context: context,
      barrierDismissible: o.barrierDismissible,
      builder: (_) => FrostDialog(title: 'Dialog', content: o.content(), showsCloseButton: true),
    ),
    closeButton: _closeButton,
  ),
  OverlayCase(
    'FrostAlert.new',
    open: (context, o) => showFrostDialog<void>(
      context: context,
      barrierDismissible: o.barrierDismissible,
      builder: (_) => PopScope(
        canPop: o.canPop,
        child: FrostAlert(
          title: overlayMarker,
          actions: [FrostDialogAction<void>(label: 'OK')],
        ),
      ),
    ),
    skip: {'popscope-close': 'an alert has no close button'},
  ),
  OverlayCase(
    'showFrostAlert',
    open: (context, o) => showFrostAlert<void>(
      context: context,
      title: overlayMarker,
      actions: [FrostDialogAction<void>(label: 'OK')],
      barrierDismissible: o.barrierDismissible,
    ),
    skip: _data,
  ),
  OverlayCase(
    'showFrostConfirm',
    open: (context, o) => showFrostConfirm(context: context, title: overlayMarker, confirmLabel: 'Delete'),
    skip: {..._data, ..._noBarrierFlag},
  ),
  OverlayCase(
    'showFrostConfirm.compact',
    open: (context, o) => showFrostConfirm(context: context, title: overlayMarker, confirmLabel: 'Delete'),
    platform: TargetPlatform.android,
    size: _phone,
    dragTarget: find.text(overlayMarker),
    skip: {..._data, ..._noBarrierFlag},
  ),
  OverlayCase(
    'showFrostSheet.dialog',
    open: (context, o) => showFrostSheet<void>(context: context, builder: (_) => o.content(), barrierDismissible: o.barrierDismissible, title: 'Sheet'),
    closeButton: _closeButton,
  ),
  OverlayCase(
    'showFrostSheet.sheet',
    open: (context, o) => showFrostSheet<void>(context: context, builder: (_) => o.content(), barrierDismissible: o.barrierDismissible, title: 'Sheet'),
    closeButton: _closeButton,
    dragTarget: find.text(overlayMarker),
    platform: TargetPlatform.android,
    size: _phone,
  ),
  OverlayCase(
    'showFrostAdaptiveDialog',
    open: (context, o) => showFrostAdaptiveDialog<void>(
      context: context,
      barrierDismissible: o.barrierDismissible,
      builder: (_) => FrostDialog(title: 'Dialog', content: o.content(), showsCloseButton: true),
    ),
    closeButton: _closeButton,
  ),
  OverlayCase(
    'showFrostAdaptiveDialog.compact',
    open: (context, o) => showFrostAdaptiveDialog<void>(
      context: context,
      barrierDismissible: o.barrierDismissible,
      builder: (_) => FrostDialog(title: 'Dialog', content: o.content(), showsCloseButton: true),
    ),
    closeButton: _closeButton,
    dragTarget: find.text(overlayMarker),
    platform: TargetPlatform.android,
    size: _phone,
  ),
  OverlayCase(
    'showFrostFormDialog',
    open: (context, o) =>
        showFrostFormDialog(context: context, title: overlayMarker, sections: [o.content()], onSubmit: () => true, submitLabel: 'Save', showsCloseButton: true),
    closeButton: _closeButton,
    skip: _noBarrierFlag,
  ),
  OverlayCase(
    'FrostMenuAnchor.new',
    anchor: (o) => FrostMenuAnchor(
      entries: [FrostMenuAction(overlayMarker, onSelected: () {})],
      builder: (context, focus, toggle) => _open('Open', toggle),
    ),
    opener: find.text('Open'),
    skip: {..._data, ..._noBarrierFlag},
  ),
  OverlayCase(
    'FrostPopover.new',
    anchor: (o) => FrostPopover(builder: (context, focus, toggle) => _open('Open', toggle), contentBuilder: (context, close) => o.content(), title: 'Popover'),
    opener: find.text('Open'),
    skip: {..._noBarrierFlag, ..._noCloseButton},
  ),
  OverlayCase(
    'FrostPopover.compact',
    anchor: (o) => FrostPopover(builder: (context, focus, toggle) => _open('Open', toggle), contentBuilder: (context, close) => o.content(), title: 'Popover'),
    opener: find.text('Open'),
    platform: TargetPlatform.android,
    size: _phone,
    dragTarget: find.text(overlayMarker),
    closeButton: _closeButton,
    skip: _noBarrierFlag,
  ),
  OverlayCase(
    'showFrostContextMenu',
    open: (context, o) => showFrostContextMenu(
      context: context,
      globalPosition: const Offset(200, 200),
      entries: [FrostMenuAction(overlayMarker, onSelected: () {})],
    ),
    skip: {..._data, ..._noBarrierFlag},
  ),
];
