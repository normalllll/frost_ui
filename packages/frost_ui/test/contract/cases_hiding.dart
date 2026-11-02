// Components that hide a subtree. The subtree holds a button; hiding it must
// remove it from focus traversal and hit testing and stop its tickers.
import 'package:flutter/widgets.dart';
import 'package:frost_ui/desktop.dart';
import 'package:frost_ui/frost_ui.dart';

import 'harness.dart';

/// Switches tabs by selecting the second tab when hidden.
class _TabSubject extends HidingSubject {
  final controller = FrostTabsController<String>(initial: 'visible')..open('other', activate: false);

  @override
  Widget build(Widget child, bool hidden) {
    final index = hidden ? 1 : 0;
    if (controller.activeIndex != index) Future.microtask(() => controller.activate(index));
    return SizedBox(
      width: 300,
      height: 200,
      child: FrostTabHost<String>(controller: controller, builder: (context, tab) => tab == 'visible' ? child : const SizedBox(width: 50, height: 50)),
    );
  }

  @override
  void dispose() => controller.dispose();
}

final hidingCases = <HidingCase>[
  HidingCase('FrostSpringReveal.new', () => SimpleHiding((child, hidden) => FrostSpringReveal(shown: !hidden, child: child))),
  HidingCase(
    'FrostLazyIndexedStack.new',
    () => SimpleHiding(
      (child, hidden) => SizedBox(
        width: 300,
        height: 200,
        child: FrostLazyIndexedStack(index: hidden ? 1 : 0, children: [child, const SizedBox(width: 50, height: 50)]),
      ),
    ),
  ),
  HidingCase('FrostTabHost.new', _TabSubject.new),
  HidingCase('FrostPresence.new', () => SimpleHiding((child, hidden) => FrostPresence(visible: !hidden, child: child))),
  HidingCase(
    'FrostInspector.new',
    () => SimpleHiding(
      (child, hidden) => hosted(
        // Wide enough for the inline presentation; below that it is a sheet, which leaves the tree.
        width: 1200,
        height: 600,
        child: FrostInspector(open: !hidden, onOpenChanged: (_) {}, inspector: child, child: const SizedBox.expand()),
      ),
    ),
  ),
  HidingCase(
    'FrostDisclosure.new',
    () => SimpleHiding((child, hidden) => FrostDisclosure(title: 'Disclosure', expanded: !hidden, onExpansionChanged: (_) {}, child: child)),
  ),
];
