import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/media.dart';

import 'baseline.dart';

void _changed(int _) {}

Widget _page(BuildContext context, int index) => ColoredBox(
  color: Color(0xFF204060 + index * 0x101010),
  child: Center(child: Text('Page $index')),
);

// A pager needs a finite-height slot.
Widget _slot(Widget pager) => SizedBox(height: 240, child: pager);

class _Controlled extends StatefulWidget {
  const _Controlled({this.page = 2, this.initialPage = 0});
  final int page;
  final int initialPage;
  @override
  State<_Controlled> createState() => _ControlledState();
}

class _ControlledState extends State<_Controlled> {
  late final _controller = FrostPagerController()..jumpTo(widget.page);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _slot(FrostPager(itemCount: 4, itemBuilder: _page, controller: _controller, initialPage: widget.initialPage));
}

Future<void> _hoverArrow(WidgetTester tester, Finder subject) async {
  await baselineHover(tester, subject);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _next(WidgetTester tester, Finder subject) async {
  await tester.tap(find.byType(FrostPager));
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
  await tester.pumpAndSettle();
}

void main() {
  baselineGroup('FrostPager', [
    BaselineCase('FrostPager/required', (_) => _slot(const FrostPager(itemCount: 3, itemBuilder: _page)), envs: BaselineEnv.all),
    BaselineCase('FrostPager/required#hover', (_) => _slot(const FrostPager(itemCount: 3, itemBuilder: _page)), act: _hoverArrow),
    BaselineCase('FrostPager/required#focus', (_) => _slot(const FrostPager(itemCount: 3, itemBuilder: _page)), act: baselineFocus),
    BaselineCase('FrostPager/required#next', (_) => _slot(const FrostPager(itemCount: 3, itemBuilder: _page)), act: _next),
    BaselineCase('FrostPager/itemCount=0', (_) => _slot(const FrostPager(itemCount: 0, itemBuilder: _page))),
    BaselineCase('FrostPager/itemCount=1', (_) => _slot(const FrostPager(itemCount: 1, itemBuilder: _page))),
    BaselineCase('FrostPager/itemCount=12', (_) => _slot(const FrostPager(itemCount: 12, itemBuilder: _page, initialPage: 4))),
    BaselineCase('FrostPager/controller', (_) => const _Controlled(), envs: BaselineEnv.themes),
    BaselineCase('FrostPager/controller+initialPage', (_) => const _Controlled(page: 1, initialPage: 3)),
    BaselineCase('FrostPager/initialPage', (_) => _slot(const FrostPager(itemCount: 4, itemBuilder: _page, initialPage: 2)), envs: BaselineEnv.themes),
    BaselineCase('FrostPager/initialPage=beyond', (_) => _slot(const FrostPager(itemCount: 3, itemBuilder: _page, initialPage: 9))),
    BaselineCase('FrostPager/onPageChanged', (_) => _slot(const FrostPager(itemCount: 3, itemBuilder: _page, onPageChanged: _changed))),
    BaselineCase(
      'FrostPager/onPageChanged#next',
      (_) => _slot(const FrostPager(itemCount: 3, itemBuilder: _page, onPageChanged: _changed)),
      act: _next,
    ),
    BaselineCase(
      'FrostPager/showsIndicator=false',
      (_) => _slot(const FrostPager(itemCount: 3, itemBuilder: _page, showsIndicator: false)),
      envs: [BaselineEnv.standard, BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostPager/indicatorPlacement=overlay',
      (_) => _slot(const FrostPager(itemCount: 3, itemBuilder: _page, indicatorPlacement: FrostPageIndicatorPlacement.overlay)),
      envs: [...BaselineEnv.themes, BaselineEnv.narrow, BaselineEnv.touch],
    ),
    BaselineCase(
      'FrostPager/indicatorPlacement=overlay#hover',
      (_) => _slot(const FrostPager(itemCount: 3, itemBuilder: _page, indicatorPlacement: FrostPageIndicatorPlacement.overlay)),
      act: _hoverArrow,
    ),
    BaselineCase(
      'FrostPager/indicatorPlacement=overlay+showsIndicator=false',
      (_) => _slot(const FrostPager(itemCount: 3, itemBuilder: _page, indicatorPlacement: FrostPageIndicatorPlacement.overlay, showsIndicator: false)),
    ),
  ]);
}
