import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_control.dart';
import 'package:frost_ui/src/primitives/_click_feedback.dart';
import 'package:frost_ui/src/primitives/_on_media_chrome_scope.dart' show FrostOnMediaChromeScope;
import 'package:material_ui/material_ui.dart';

import 'support.dart';

// Toolbars also lay out hidden measuring copies; only the shown control is hit-testable.
Finder _control(String label) => find.byWidgetPredicate((w) => w is FrostButtonControl && w.label == label).hitTestable();

/// The press / hover plate drawn for a control.
Rect _plate(WidgetTester tester, String label) => tester.getRect(find.descendant(of: _control(label), matching: find.byType(FrostInteractionDecoration)).first);

void main() {
  // Touch targets keep the 44 height but take 40 across; pointer targets stay square.
  for (final (platform, target, plate) in [(TargetPlatform.android, const Size(40, 44), 36.0), (TargetPlatform.windows, const Size(36, 36), 32.0)]) {
    testWidgets('adjacent icon actions are spaced by their own targets on ${platform.name}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(412, 300);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        frostTestApp(
          Align(
            alignment: Alignment.topCenter,
            child: FrostPageHeader(
              title: const FrostText('Browse'),
              actions: [
                FrostToolbarItem.action(icon: testIcons.filter, label: 'Filter', priority: FrostToolbarPriority.high, onPressed: () {}),
                FrostToolbarItem.menu(
                  label: 'Options',
                  icon: testIcons.more,
                  showsLabel: false,
                  priority: FrostToolbarPriority.high,
                  entries: [FrostMenuAction('Open', onSelected: () {})],
                ),
              ],
            ),
          ),
          platform: platform,
        ),
      );
      final filter = tester.getRect(_control('Filter')), options = tester.getRect(_control('Options'));
      expect(filter.size, target);
      expect(options.size, target);
      expect(options.center.dx - filter.center.dx, target.width, reason: 'centres one target apart, no extra gap');
      expect(options.left, filter.right, reason: 'targets abut without overlapping');
      for (final (label, hit) in [('Filter', filter), ('Options', options)]) {
        final visual = _plate(tester, label);
        expect(visual.size, Size(plate, plate));
        expect(visual.center, hit.center, reason: '$label plate stays centred on its icon');
        expect(
          hit.contains(visual.topLeft) && hit.contains(visual.bottomRight - const Offset(.01, .01)),
          isTrue,
          reason: '$label plate stays inside its own target',
        );
      }
      // The plates keep a visible gap made of the two targets' own margins.
      expect(_plate(tester, 'Options').left - _plate(tester, 'Filter').right, target.width - plate);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('chrome over media keeps square touch targets for its always-visible circles', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 300);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      frostTestApp(
        Align(
          alignment: Alignment.topCenter,
          child: FrostOnMediaChromeScope(
            child: FrostPageHeader(
              onBack: () {},
              actions: [
                FrostToolbarItem.action(icon: testIcons.add, label: 'Save', priority: FrostToolbarPriority.high, onPressed: () {}),
                FrostToolbarItem.action(icon: testIcons.more, label: 'Options', priority: FrostToolbarPriority.high, onPressed: () {}),
              ],
            ),
          ),
        ),
        platform: TargetPlatform.android,
      ),
    );
    final save = tester.getRect(_control('Save')), options = tester.getRect(_control('Options'));
    expect(tester.getSize(_control('L.back')), const Size(44, 44));
    expect(save.size, const Size(44, 44));
    expect(options.left, save.right);
    // The two 36 circles keep 8 of visible room between them.
    expect(_plate(tester, 'Options').left - _plate(tester, 'Save').right, 8);
    expect(tester.takeException(), isNull);
  });

  testWidgets('text actions, the title and the middle slot keep the toolbar gap from icon actions', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 300);
    addTearDown(tester.view.reset);
    final controller = TextEditingController(), focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      frostTestApp(
        Align(
          alignment: Alignment.topCenter,
          child: FrostToolbar(
            title: const FrostText('Title'),
            middle: FrostSearchInput(controller: controller, focusNode: focus, placeholder: 'Search', onSubmitted: (_) {}),
            controls: [FrostToolbarItem.action(icon: testIcons.filter, label: 'Filter', priority: FrostToolbarPriority.high, onPressed: () {})],
            trailing: [
              FrostToolbarItem.action(icon: testIcons.add, label: 'Add item', showsLabel: true, priority: FrostToolbarPriority.high, onPressed: () {}),
              FrostToolbarItem.action(icon: testIcons.refresh, label: 'Refresh', priority: FrostToolbarPriority.high, onPressed: () {}),
              FrostToolbarItem.action(icon: testIcons.more, label: 'More things', priority: FrostToolbarPriority.high, onPressed: () {}),
            ],
          ),
        ),
        platform: TargetPlatform.android,
      ),
    );
    final title = tester.getRect(find.text('Title')), filter = tester.getRect(_control('Filter'));
    final field = tester.getRect(find.byType(FrostSearchInput));
    final add = tester.getRect(_control('Add item')), refresh = tester.getRect(_control('Refresh')), more = tester.getRect(_control('More things'));
    expect(filter.left - title.right, FrostGap.related, reason: 'title to icon');
    expect(field.left - filter.right, FrostGap.related, reason: 'icon to middle');
    expect(refresh.left - add.right, FrostGap.related, reason: 'text action to icon');
    expect(more.left, refresh.right, reason: 'icon to icon');
    expect(tester.takeException(), isNull);
  });

  testWidgets('labelled actions that fold to icons abut, and More abuts the last icon', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 300);
    addTearDown(tester.view.reset);
    final width = ValueNotifier(600.0);
    addTearDown(width.dispose);
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: ValueListenableBuilder(
            valueListenable: width,
            builder: (_, value, _) => SizedBox(
              width: value,
              child: FrostToolbar(
                title: const FrostText('Downloads'),
                trailing: [
                  FrostToolbarItem.action(icon: testIcons.add, label: 'Add download', showsLabel: true, onPressed: () {}),
                  FrostToolbarItem.action(icon: testIcons.refresh, label: 'Retry all', showsLabel: true, onPressed: () {}),
                  FrostToolbarItem.action(icon: testIcons.close, label: 'Clear', priority: FrostToolbarPriority.low, onPressed: () {}),
                ],
              ),
            ),
          ),
        ),
        platform: TargetPlatform.android,
      ),
    );
    const target = 40.0; // A touch icon target's width on Android.
    // Narrow enough that both labelled actions show as icons.
    for (var w = 600.0; w >= 200; w -= 4) {
      width.value = w;
      await tester.pump();
      if (find.text('Add download').hitTestable().evaluate().isEmpty && find.text('Retry all').hitTestable().evaluate().isEmpty) break;
    }
    expect(tester.getRect(_control('Retry all')).left, tester.getRect(_control('Add download')).right);
    // Narrower still: the low-priority action folds into More beside them.
    for (var w = width.value; w >= 100; w -= 4) {
      width.value = w;
      await tester.pump();
      if (_control('L.more').evaluate().isNotEmpty) break;
    }
    final more = tester.getRect(_control('L.more'));
    final last = tester.getRect(_control('Retry all'));
    expect(more.left, last.right);
    expect(more.width, target);
    expect(tester.takeException(), isNull);
  });
}
