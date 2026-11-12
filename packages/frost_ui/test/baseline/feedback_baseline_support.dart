// Fixtures shared by the feedback, motion and foundation baseline files.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/feedback/_pull_refresh.dart';

import '../support.dart';
import 'baseline.dart';

/// An error with a stable `toString`, so presenter text is deterministic.
class BaselineFailure implements Exception {
  const BaselineFailure();
  @override
  String toString() => 'BaselineFailure';
}

/// A config whose presenter offers a recovery action (label `Sign in`).
final FrostConfig baselineActionConfig = testConfig.copyWith(
  errors: FrostErrorPresenter(
    message: (context, error) => 'E.message($error)',
    details: (error) => 'E.details($error)',
    action: (context, error) => FrostErrorAction(label: 'Sign in', icon: const FrostIconData.glyph(IconData(0xe010)), onPressed: _resolve),
  ),
);

Future<bool> _resolve() async => true;

/// A 40-point row of text for paged lists.
Widget baselineRow(BuildContext context, int value, int index) => SizedBox(height: 40, child: Text('Item $value'));

/// A card whose height varies deterministically, for grids.
Widget baselineTile(BuildContext context, int value, int index) => SizedBox(
  height: 60.0 + (index % 3) * 20,
  child: DecoratedBox(
    decoration: const BoxDecoration(color: Color(0x33888888)),
    child: Center(child: Text('Item $value')),
  ),
);

/// A scroll view of [slivers] with a Material ancestor, for page-level cases.
Widget baselineScroll(List<Widget> slivers) => Scaffold(body: FrostLoadingScrollView(slivers: slivers));

/// A skeleton placeholder for first loads.
const baselineSkeleton = SizedBox(height: 120, child: Text('Skeleton'));

/// Rebuilds [builder] with `toggled` flipped by [baselineToggle].
class BaselineToggle extends StatefulWidget {
  const BaselineToggle({required this.builder, super.key});
  final Widget Function(BuildContext context, bool toggled) builder;
  @override
  State<BaselineToggle> createState() => BaselineToggleState();
}

class BaselineToggleState extends State<BaselineToggle> {
  bool toggled = false;
  void toggle() => setState(() => toggled = !toggled);
  @override
  Widget build(BuildContext context) => widget.builder(context, toggled);
}

/// Flips the [BaselineToggle] inside the subject.
Future<void> baselineToggle(WidgetTester tester, Finder subject) async {
  tester.state<BaselineToggleState>(find.descendant(of: subject, matching: find.byType(BaselineToggle))).toggle();
  await tester.pump();
}

/// Taps the text [label] inside the subject, for example a disclosure title.
BaselineAct baselineTapText(String label) => (tester, subject) async {
  await tester.tap(find.descendant(of: subject, matching: find.text(label)).first);
};

/// Owns a [ScrollController] for the subject's lifetime.
class BaselineScrollHost extends StatefulWidget {
  const BaselineScrollHost({required this.builder, super.key});
  final Widget Function(BuildContext context, ScrollController controller) builder;
  @override
  State<BaselineScrollHost> createState() => _BaselineScrollHostState();
}

class _BaselineScrollHostState extends State<BaselineScrollHost> {
  final _controller = ScrollController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controller);
}

/// A refresh that never completes, so the refreshing state stays up.
Future<bool> baselineNeverRefresh() => Completer<bool>().future;

/// A refresh that completes at once.
Future<bool> baselineRefresh() async => true;

/// Rows tall enough to scroll in a 300-point viewport.
Widget baselineRows({int count = 30}) => SliverList(
  delegate: SliverChildBuilderDelegate((context, index) => SizedBox(height: 40, child: Text('Row $index')), childCount: count),
);

/// Drags the subject down by [distance] and holds, to show the pull header.
BaselineAct baselinePull(double distance) => (tester, subject) async {
  final gesture = await tester.startGesture(tester.getTopLeft(subject) + const Offset(100, 100));
  addTearDown(gesture.up);
  const steps = 10;
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(Offset(0, distance / steps));
    await tester.pump(const Duration(milliseconds: 16));
  }
};

/// Shows the held refreshing state of the [FrostPullRefresh] inside the subject.
Future<void> baselineRefreshing(WidgetTester tester, Finder subject) async {
  final state = tester.state<FrostPullRefreshState>(find.descendant(of: subject, matching: find.byType(FrostPullRefresh)));
  unawaited(state.refresh());
  await tester.pump();
}

/// Scrolls the first scrollable of the subject by [offset].
BaselineAct baselineScrollBy(Offset offset) => (tester, subject) async {
  await tester.drag(find.descendant(of: subject, matching: find.byType(Scrollable)).first, offset);
};
