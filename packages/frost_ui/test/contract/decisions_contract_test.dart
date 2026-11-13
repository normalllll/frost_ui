// The owner's behaviour decisions, one case each. A case
// id names the subject; the check names the decision.
import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/media.dart';
import 'package:material_ui/material_ui.dart';

import '../support.dart' show frostFocusRings, testIcons;
import 'harness.dart';
import 'registry.dart' show decisionIds;

/// What the case id and check name are, and how to run it.
typedef _Decision = ({String id, String check, Future<String?> Function(WidgetTester tester) run});

bool _focusIn(Finder target) {
  final context = FocusManager.instance.primaryFocus?.context;
  final targets = target.evaluate().toSet();
  if (context == null || targets.isEmpty) return false;
  if (targets.contains(context)) return true;
  var inside = false;
  context.visitAncestorElements((element) {
    inside = targets.contains(element);
    return !inside;
  });
  return inside;
}

/// Mounts a page with a [BuildContext] to open overlays from.
Future<BuildContext> _page(WidgetTester tester, {TargetPlatform platform = TargetPlatform.windows, Size size = const Size(1200, 800), Widget? body}) async {
  late BuildContext context;
  await pumpEnv(
    tester,
    Builder(
      builder: (c) {
        context = c;
        return body ?? const Text(pageMarker);
      },
    ),
    platform: platform,
    size: size,
    underPage: true,
  );
  return context;
}

/// Whether the focused node covers [inner], such as a button holding its label.
bool _focusOwns(Finder inner) {
  final focus = FocusManager.instance.primaryFocus;
  if (focus == null || focus is FocusScopeNode || inner.evaluate().isEmpty) return false;
  final box = inner.evaluate().first.renderObject! as RenderBox;
  return focus.rect.contains(box.localToGlobal(box.size.center(Offset.zero)));
}

Future<String?> _confirmEnter(WidgetTester tester) => guarded(tester, (errors) async {
  final context = await _page(tester);
  bool? answer;
  void ask() {
    answer = null;
    unawaited(showFrostConfirm(context: context, title: 'Delete it?', confirmLabel: 'Delete').then((value) => answer = value));
  }

  ask();
  await settle(tester);
  if (!_focusOwns(find.text('L.cancel'))) return 'initial focus of a destructive confirmation is not on Cancel';
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await settle(tester);
  if (answer != false) return 'Enter on the initial focus did not cancel (result: $answer)';
  ask();
  await settle(tester);
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump();
  if (!_focusOwns(find.text('Delete'))) return 'Tab from Cancel does not reach the confirm button';
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await settle(tester);
  if (answer != true) return 'Enter on the focused confirm button did not confirm (result: $answer)';
  return null;
});

Future<String?> _menuEnter(WidgetTester tester) => guarded(tester, (errors) async {
  final context = await _page(tester);
  var submits = 0;
  String? picked;
  // A submit that never finishes: if Enter reaches the dialog's default action, it stays busy.
  final submit = Completer<bool>();
  unawaited(
    showFrostFormDialog(
      context: context,
      title: 'Form',
      sections: [
        FrostPicker<String>.menu(
          label: 'Choice',
          value: 'a',
          options: const [
            FrostPickerOption(value: 'a', label: 'Alpha'),
            FrostPickerOption(value: 'b', label: 'Bravo'),
            FrostPickerOption(value: 'c', label: 'Charlie'),
          ],
          onChanged: (value) => picked = value,
        ),
      ],
      onSubmit: () {
        submits++;
        return submit.future;
      },
      submitLabel: 'Save',
    ),
  );
  await settle(tester);
  await tester.tap(find.byType(FrostPicker<String>));
  await settle(tester);
  if (find.text('Bravo').evaluate().isEmpty) return 'the picker menu did not open inside the form dialog';
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
  await tester.pump();
  // The highlighted item is the one holding focus.
  final highlighted = {
    for (final entry in {'Alpha': 'a', 'Bravo': 'b', 'Charlie': 'c'}.entries)
      if (_focusOwns(find.text(entry.key))) entry.value,
  };
  if (highlighted.length != 1) return 'no single menu item is highlighted after the arrow keys, so the case cannot say what Enter should select';
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await settle(tester);
  if (submits > 0) return 'Enter on a highlighted menu item submitted the form';
  if (picked != highlighted.single) return 'Enter selected $picked, not the highlighted item ${highlighted.single}';
  if (find.text('Save').evaluate().isEmpty) return 'the form dialog closed or changed after Enter in the menu';
  // The Save button must still work: a stuck loading state would swallow this click.
  await tester.tap(find.text('Save'));
  await settle(tester);
  if (submits != 1) return 'Save does nothing after Enter in the menu (submits: $submits), as if the dialog were stuck loading';
  submit.complete(true);
  await settle(tester);
  return null;
});

Future<String?> _shellEsc(WidgetTester tester) => guarded(tester, (errors) async {
  var backs = 0;
  await pumpEnv(
    tester,
    FrostShell(
      destinations: [FrostNavDestination(icon: testIcons.add, label: 'Home')],
      selectedIndex: 0,
      atDestinationRoot: false,
      onDestinationSelected: (_) {},
      canGoBack: true,
      onBack: () => backs++,
      showsMobileNavigation: false,
      // A routed page, as in an app: dropping focus leaves it in the page's own scope, inside the shell.
      child: Navigator(
        onDidRemovePage: (_) {},
        pages: const [
          MaterialPage<void>(
            child: Column(
              children: [
                Text(pageMarker),
                Expanded(
                  child: Center(
                    child: SizedBox(width: 300, child: FrostTextField(label: 'Field')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    underPage: true,
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await settle(tester);
  if (backs > 0 || find.text(pageMarker).evaluate().isEmpty) return 'Escape on the page left it (onBack called $backs time(s))';
  await tester.tap(find.byType(EditableText));
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await settle(tester);
  if (backs > 0 || find.text(pageMarker).evaluate().isEmpty) return 'Escape inside a text field left the page (onBack called $backs time(s))';
  // The shell binds no Escape; a second press from the field leaves the page too.
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await settle(tester);
  if (backs > 0 || find.text(pageMarker).evaluate().isEmpty) return 'a second Escape after leaving the text field left the page (onBack called $backs time(s))';
  return null;
});

Future<String?> _focusRingMouse(WidgetTester tester) => guarded(tester, (errors) async {
  await pumpEnv(tester, FrostButton(label: 'Go', onPressed: () {}));
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump(const Duration(milliseconds: 300));
  if (frostFocusRings().evaluate().isEmpty) return 'Tab focus on a button draws no focus ring';
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: const Offset(5, 5));
  await mouse.moveTo(const Offset(40, 40));
  await tester.pump(const Duration(milliseconds: 300));
  if (frostFocusRings().evaluate().isEmpty) return 'moving the mouse hid the focus ring';
  await mouse.moveTo(tester.getCenter(find.byType(FrostButton)));
  await mouse.down(tester.getCenter(find.byType(FrostButton)));
  await mouse.up();
  await tester.pump(const Duration(milliseconds: 300));
  if (frostFocusRings().evaluate().isNotEmpty) return 'the focus ring is still drawn after a mouse click';
  await mouse.removePointer();
  return null;
});

Future<String?> _noGlobalHighlight(WidgetTester tester) => guarded(tester, (errors) async {
  final before = FocusManager.instance.highlightStrategy;
  await pumpEnv(
    tester,
    InkWell(
      onTap: () {},
      child: const SizedBox(width: 100, height: 40, child: Text('Ink')),
    ),
  );
  if (FocusManager.instance.highlightStrategy != before) {
    return 'mounting the app changed FocusManager.highlightStrategy from $before to ${FocusManager.instance.highlightStrategy}';
  }
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump();
  if (!_focusIn(find.byType(InkWell))) return 'the plain InkWell did not take focus on Tab';
  if (FocusManager.instance.highlightMode != FocusHighlightMode.traditional) {
    return 'the plain InkWell gets no focus highlight after Tab (mode ${FocusManager.instance.highlightMode})';
  }
  await tester.tap(find.byType(InkWell));
  await tester.pump();
  if (FocusManager.instance.highlightStrategy != before) {
    return 'a pointer press changed FocusManager.highlightStrategy from $before to ${FocusManager.instance.highlightStrategy}';
  }
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump();
  if (FocusManager.instance.highlightStrategy != before) {
    return 'a key press changed FocusManager.highlightStrategy from $before to ${FocusManager.instance.highlightStrategy}';
  }
  return null;
});

/// A selection mode opened with a modifier click. [card] uses media cards in a grid scope.
Future<String?> _desktopSelection(WidgetTester tester, {required bool card, required TargetPlatform platform, required LogicalKeyboardKey modifier}) =>
    guarded(tester, (errors) async {
      final selection = FrostSelection<int>();
      addTearDown(selection.dispose);
      final opened = <int>[];
      Widget item(int value) => card
          ? FrostMediaCard(
              media: const FrostMediaImage(
                child: SizedBox(width: 100, height: 60, child: ColoredBox(color: Colors.red)),
              ),
              title: 'Item $value',
              semanticLabel: 'Item $value',
              onPressed: () => opened.add(value),
            )
          : FrostListRow(title: 'Item $value', onPressed: () => opened.add(value));
      await pumpEnv(
        tester,
        SizedBox(
          width: 400,
          height: 600,
          child: FrostSelectionScope<int>(
            selection: selection,
            items: const [1, 2, 3],
            child: ListView(
              children: [
                for (final value in [1, 2, 3]) FrostSelectableItem<int>(item: value, child: item(value)),
              ],
            ),
          ),
        ),
        platform: platform,
      );
      Future<void> click(int value, {bool modified = false}) async {
        if (modified) await tester.sendKeyDownEvent(modifier);
        await tester.tap(find.text('Item $value'));
        if (modified) await tester.sendKeyUpEvent(modifier);
        await settle(tester);
      }

      await click(1, modified: true);
      if (!selection.isSelected(1) || !selection.active) return '${modifier.keyLabel}-click did not select the item and enter selection mode';
      await click(2);
      if (!opened.contains(2)) return 'a plain click in selection mode did not open the item';
      if (selection.isSelected(2)) return 'a plain click in selection mode toggled the item instead of opening it';
      await click(1, modified: true);
      if (selection.selected.isNotEmpty) return '${modifier.keyLabel}-click on the selected item did not deselect it';
      if (selection.active) return 'selection mode stayed active after the selection became empty';
      return null;
    });

Future<String?> _modalAutofocus(WidgetTester tester, {required bool sheet}) => guarded(tester, (errors) async {
  Future<bool> focused({required bool autofocus}) async {
    final context = await _page(tester, platform: TargetPlatform.android, size: const Size(400, 800));
    final field = FrostTextField(label: 'Name', autofocus: autofocus);
    unawaited(
      sheet
          ? showFrostSheet<void>(
              context: context,
              title: 'Sheet',
              builder: (_) => Padding(padding: const EdgeInsets.all(16), child: field),
            )
          : showFrostDialog<void>(
              context: context,
              builder: (_) => FrostDialog(title: 'Dialog', content: field),
            ),
    );
    await settle(tester);
    final result = _focusIn(find.byType(EditableText));
    await tester.binding.handlePopRoute();
    await settle(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    return result;
  }

  if (!await focused(autofocus: true)) return 'an explicit autofocus: true did not focus the field, so the check cannot tell';
  if (await focused(autofocus: false)) return 'the ${sheet ? 'sheet' : 'dialog'} focused its text field on a touch platform without autofocus';
  return null;
});

Future<String?> _mouseDrag(WidgetTester tester) => guarded(tester, (errors) async {
  final controller = ScrollController();
  addTearDown(controller.dispose);
  var refreshes = 0;
  await pumpEnv(
    tester,
    SizedBox(
      width: 400,
      height: 600,
      child: FrostRefreshView(
        scrollController: controller,
        onRefresh: () async {
          refreshes++;
          return true;
        },
        builder: (context, physics, locators) => CustomScrollView(
          controller: controller,
          physics: physics,
          slivers: [
            ?locators.sliverHeader,
            const SliverToBoxAdapter(child: SizedBox(height: 3000)),
          ],
        ),
      ),
    ),
  );
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  const start = Offset(600, 400);
  await mouse.down(start);
  for (var i = 1; i <= 10; i++) {
    await mouse.moveTo(start + Offset(0, -20.0 * i));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await mouse.up();
  await settle(tester);
  if (controller.offset != 0) return 'dragging with the mouse scrolled the content to ${controller.offset}';
  await mouse.down(start);
  for (var i = 1; i <= 15; i++) {
    await mouse.moveTo(start + Offset(0, 30.0 * i));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await mouse.up();
  await settle(tester);
  if (refreshes > 0) return 'dragging down with the mouse refreshed the view';
  return null;
});

final _decisions = <_Decision>[
  (id: 'showFrostConfirm', check: 'confirm-enter', run: _confirmEnter),
  (id: 'showFrostFormDialog', check: 'menu-enter', run: _menuEnter),
  (id: 'FrostShell', check: 'shell-esc', run: _shellEsc),
  (id: 'FrostButton', check: 'focus-ring-mouse', run: _focusRingMouse),
  (id: 'FrostApp', check: 'no-global-highlight', run: _noGlobalHighlight),
  (
    id: 'FrostListRow.ctrl',
    check: 'desktop-selection',
    run: (tester) => _desktopSelection(tester, card: false, platform: TargetPlatform.windows, modifier: LogicalKeyboardKey.controlLeft),
  ),
  (
    id: 'FrostListRow.cmd',
    check: 'desktop-selection',
    run: (tester) => _desktopSelection(tester, card: false, platform: TargetPlatform.macOS, modifier: LogicalKeyboardKey.metaLeft),
  ),
  (
    id: 'FrostMediaCard.ctrl',
    check: 'desktop-selection',
    run: (tester) => _desktopSelection(tester, card: true, platform: TargetPlatform.windows, modifier: LogicalKeyboardKey.controlLeft),
  ),
  (
    id: 'FrostMediaCard.cmd',
    check: 'desktop-selection',
    run: (tester) => _desktopSelection(tester, card: true, platform: TargetPlatform.macOS, modifier: LogicalKeyboardKey.metaLeft),
  ),
  (id: 'showFrostSheet', check: 'modal-autofocus', run: (tester) => _modalAutofocus(tester, sheet: true)),
  (id: 'showFrostDialog', check: 'modal-autofocus', run: (tester) => _modalAutofocus(tester, sheet: false)),
  (id: 'FrostRefreshView', check: 'mouse-drag', run: _mouseDrag),
];

void main() {
  test('the decisions registered for coverage are the ones that run', () {
    expect({for (final d in _decisions) '${d.id}	${d.check}'}, decisionIds);
  });

  for (final d in _decisions) {
    testWidgets('${d.id} ${d.check}', (tester) async => expectContract(d.id, d.check, await d.run(tester)));
  }
}
