import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/desktop.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_control.dart';

import 'baseline.dart';
import 'nav_overlay_support.dart';

const _h = 600.0;

// The owner of `open`: the main content holds a button that toggles it.
class _Host extends StatefulWidget {
  const _Host({this.open = false, this.title, this.sheetBelow, this.sheetDetents, this.showsSheetCloseButton});
  final bool open;
  final String? title;
  final FrostSizeClass? sheetBelow;
  final List<FrostSheetDetent>? sheetDetents;
  final bool? showsSheetCloseButton;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late bool _open = widget.open;

  @override
  Widget build(BuildContext context) => FrostInspector(
    open: _open,
    onOpenChanged: (value) => setState(() => _open = value),
    title: widget.title,
    sheetBelow: widget.sheetBelow ?? FrostSizeClass.expanded,
    sheetDetents: widget.sheetDetents ?? const [FrostSheetDetent.medium, FrostSheetDetent.large],
    showsSheetCloseButton: widget.showsSheetCloseButton ?? true,
    inspector: const Padding(padding: EdgeInsets.all(16), child: Text('Inspector body')),
    child: Align(
      alignment: Alignment.topLeft,
      child: FrostButtonControl(label: 'Toggle', onPressed: () => setState(() => _open = !_open)),
    ),
  );
}

Future<void> _toggle(WidgetTester tester, Finder subject) async {
  await tester.tap(find.byWidgetPredicate((w) => w is FrostButtonControl && w.label == 'Toggle').first);
}

BaselineCase _case(String id, Widget Function() build, {List<BaselineEnv> envs = const [wide, medium], BaselineAct? act}) =>
    BaselineCase(id, (_) => windowed(build()), height: _h, envs: envs, act: act);

void main() {
  baselineGroup('FrostInspector', [
    _case('FrostInspector/required', () => const _Host(), envs: [wide, medium, BaselineEnv.standard, narrow, narrowTouch]),
    _case('FrostInspector/required#open', () => const _Host(), act: _toggle, envs: [wide, medium, BaselineEnv.standard, narrow]),
    _case(
      'FrostInspector/open',
      () => const _Host(open: true),
      envs: [
        wide,
        medium,
        BaselineEnv.standard,
        narrow,
        narrowTouch,
        wide.copyWith(brightness: Brightness.light),
      ],
    ),
    _case('FrostInspector/open#focus', () => const _Host(open: true), act: baselineFocus, envs: [wide]),
    _case('FrostInspector/title', () => const _Host(open: true, title: 'Details'), envs: [wide, medium, BaselineEnv.standard, narrow]),
    _case(
      'FrostInspector/title#hover',
      () => const _Host(open: true, title: 'Details'),
      act: (tester, subject) => baselineHover(tester, find.byType(FrostButton).first),
      envs: [wide],
    ),
    _case('FrostInspector/sheetBelow=compact', () => const _Host(open: true, sheetBelow: FrostSizeClass.compact), envs: [wide, BaselineEnv.standard, narrow]),
    _case('FrostInspector/sheetBelow=large', () => const _Host(open: true, sheetBelow: FrostSizeClass.large), envs: [wide, medium]),
    _case('FrostInspector/sheetDetents=fitted', () => const _Host(open: true, sheetDetents: [FrostSheetDetent.fitted]), envs: [BaselineEnv.standard, narrow]),
    _case('FrostInspector/showsSheetCloseButton=false', () => const _Host(open: true, showsSheetCloseButton: false), envs: [BaselineEnv.standard, narrow]),
    // A phone presents the compact inspector as a bottom sheet.
    _case('FrostInspector/required#open-sheet', () => const _Host(), act: onPhone(_toggle), envs: [narrowTouch]),
    _case(
      'FrostInspector/sheetDetents=fitted#open-sheet',
      () => const _Host(sheetDetents: [FrostSheetDetent.fitted]),
      act: onPhone(_toggle),
      envs: [narrowTouch],
    ),
    _case('FrostInspector/showsSheetCloseButton=false#open-sheet', () => const _Host(showsSheetCloseButton: false), act: onPhone(_toggle), envs: [narrowTouch]),
  ]);
}
