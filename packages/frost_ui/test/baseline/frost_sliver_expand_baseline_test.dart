import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

Widget _item(BuildContext context, int index) => SizedBox(height: 40, child: FrostText('Row $index', tone: FrostTextTone.primary));

Widget _list({required bool expanded}) => SizedBox(
  height: 420,
  child: CustomScrollView(
    slivers: [
      const SliverToBoxAdapter(
        child: SizedBox(height: 40, child: FrostText('Group header', tone: FrostTextTone.primary)),
      ),
      FrostSliverExpand(
        expanded: expanded,
        sliver: SliverList.builder(itemCount: 8, itemBuilder: _item),
      ),
      const SliverToBoxAdapter(
        child: SizedBox(height: 40, child: FrostText('After the group', tone: FrostTextTone.primary)),
      ),
    ],
  ),
);

// Starts collapsed; a button below flips it.
class _Toggle extends StatefulWidget {
  const _Toggle({required this.initial});
  final bool initial;
  @override
  State<_Toggle> createState() => _ToggleState();
}

class _ToggleState extends State<_Toggle> {
  late bool _expanded = widget.initial;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      FrostButton(label: 'Toggle', onPressed: () => setState(() => _expanded = !_expanded)),
      _list(expanded: _expanded),
    ],
  );
}

Future<void> _toggle(WidgetTester tester, Finder subject) async {
  await tester.tap(find.descendant(of: subject, matching: find.text('Toggle')));
}

void main() {
  baselineGroup('FrostSliverExpand', [
    BaselineCase('FrostSliverExpand/required', (_) => _list(expanded: true), envs: [BaselineEnv.standard, BaselineEnv.narrow]),
    BaselineCase('FrostSliverExpand/expanded=false', (_) => _list(expanded: false)),
    BaselineCase('FrostSliverExpand/expanded=false#open', (_) => const _Toggle(initial: false), act: _toggle),
    BaselineCase('FrostSliverExpand/expanded=true#close', (_) => const _Toggle(initial: true), act: _toggle),
  ]);
}
