import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _noop() {}

// Enough rows to scroll, laid out by the page itself.
Widget get _list => ListView.builder(itemCount: 40, itemBuilder: (_, index) => SizedBox(height: 48, child: FrostText('Item $index')));

Future<void> _scrollDown(WidgetTester tester, Finder subject) async {
  await tester.drag(find.byType(ListView), const Offset(0, -240));
}

Future<void> _scrollBack(WidgetTester tester, Finder subject) async {
  await tester.drag(find.byType(ListView), const Offset(0, -240));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.drag(find.byType(ListView), const Offset(0, 60));
}

void main() {
  baselineGroup('FrostFloatingActionLayer', [
    BaselineCase(
      'FrostFloatingActionLayer/required',
      (_) => FrostFloatingActionLayer(label: 'New', icon: baselineIcon, onPressed: null, child: _list),
      height: 400,
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostFloatingActionLayer/onPressed',
      (_) => FrostFloatingActionLayer(label: 'New', icon: baselineIcon, onPressed: _noop, child: _list),
      height: 400,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostFloatingActionLayer/onPressed#hover',
      (_) => FrostFloatingActionLayer(label: 'New', icon: baselineIcon, onPressed: _noop, child: _list),
      height: 400,
      act: (tester, subject) async {
        final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);
        await gesture.moveTo(tester.getBottomRight(subject) - const Offset(80, 40));
      },
    ),
    BaselineCase(
      'FrostFloatingActionLayer/onPressed#focus',
      (_) => FrostFloatingActionLayer(label: 'New', icon: baselineIcon, onPressed: _noop, child: _list),
      height: 400,
      act: baselineFocus,
    ),
    BaselineCase(
      'FrostFloatingActionLayer/onPressed#collapsed',
      (_) => FrostFloatingActionLayer(label: 'New', icon: baselineIcon, onPressed: _noop, child: _list),
      height: 400,
      act: _scrollDown,
    ),
    BaselineCase(
      'FrostFloatingActionLayer/onPressed#extended',
      (_) => FrostFloatingActionLayer(label: 'New', icon: baselineIcon, onPressed: _noop, child: _list),
      height: 400,
      act: _scrollBack,
    ),
  ]);
}
