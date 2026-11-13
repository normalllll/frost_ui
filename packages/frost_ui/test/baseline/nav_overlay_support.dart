// Helpers shared by the navigation and overlay baseline files.
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/desktop.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_control.dart';
import 'package:material_ui/material_ui.dart';

import 'baseline.dart';

/// Page-level widths used by the shell and page-level components: 1280 is at
/// the expanded-sidebar threshold (1200), 1000 collapses it, 360 is narrow.
const wide = BaselineEnv(width: 1280);
const medium = BaselineEnv(width: 1000);
const narrow = BaselineEnv.narrow;
const narrowTouch = BaselineEnv(width: 360, input: BaselineInput.touch);

/// The three pointer widths plus the narrow touch phone.
const pageEnvs = [wide, medium, narrow, narrowTouch];

/// Makes the subject's MediaQuery size equal the case's parent constraints, so
/// size-class and navigation decisions follow the environment width. The
/// harness gives every case a surface at least 1280 wide.
Widget windowed(Widget child) => LayoutBuilder(
  builder: (context, constraints) {
    final media = MediaQuery.of(context);
    final size = Size(constraints.maxWidth, constraints.hasBoundedHeight ? constraints.maxHeight : media.size.height);
    return MediaQuery(
      data: media.copyWith(size: size),
      child: child,
    );
  },
);

/// A trigger for menus and popovers that takes the anchor's focus node.
Widget trigger(FocusNode focus, VoidCallback toggle, [String label = 'Open']) => FrostButtonControl(label: label, focusNode: focus, onPressed: toggle);

/// Taps the first frost button inside the subject (the anchor of an overlay).
Future<void> tapTrigger(WidgetTester tester, Finder subject) => tester.tap(find.descendant(of: subject, matching: find.byType(FrostButtonControl)).first);

/// Taps the first widget of [T] inside the subject.
BaselineAct tapType<T extends Widget>() =>
    (tester, subject) => tester.tap(find.descendant(of: subject, matching: find.byType(T)).first);

/// Taps the text [label] anywhere on screen.
BaselineAct tapText(String label) =>
    (tester, subject) => tester.tap(find.text(label).first);

/// Runs [first] and then [second].
BaselineAct then(BaselineAct first, BaselineAct second) => (tester, subject) async {
  await first(tester, subject);
  await tester.pumpAndSettle();
  await second(tester, subject);
};

/// A small deterministic body for popovers, dialogs and sheets.
Widget body([String text = 'Body text']) => Text(text);

/// A menu anchor with a plain trigger, for cases that show entries open.
Widget menuAnchor(List<FrostMenuEntry> entries) => FrostMenuAnchor(entries: entries, builder: (context, focus, toggle) => trigger(focus, toggle));

/// Opens the first menu anchor trigger, then hovers the entry labelled [label].
BaselineAct openThenHover(String label) => (tester, subject) async {
  await tapTrigger(tester, subject);
  await tester.pumpAndSettle();
  await baselineHover(tester, find.text(label).first);
};

/// Shrinks the test window to a phone before running [act], for overlays that
/// choose a sheet from the window width when they open.
BaselineAct onPhone(BaselineAct act) => (tester, subject) async {
  tester.view.physicalSize = const Size(360, 780);
  await tester.pumpAndSettle();
  await act(tester, subject);
};

/// Hovers the subject and lets [delay] pass, for tooltips.
BaselineAct hoverFor(Duration delay) => (tester, subject) async {
  await baselineHover(tester, subject);
  await tester.pump(delay);
};

/// A button that runs [open] with its context: the anchor of show functions.
Widget launcher(Future<Object?> Function(BuildContext context) open, [String label = 'Open']) => Builder(
  builder: (context) => FrostButtonControl(label: label, onPressed: () => open(context)),
);

/// Actions most dialog cases share: a cancel and a default.
const dialogActions = <FrostDialogAction<Object?>>[
  FrostDialogAction(label: 'Cancel', role: FrostButtonRole.cancel),
  FrostDialogAction(label: 'Save', isDefault: true),
];

/// Owns the controller and focus node of a search field for a case, and the
/// header controller that observes its expansion.
class SearchHost extends StatefulWidget {
  const SearchHost({required this.builder, this.text = '', super.key});
  final Widget Function(BuildContext context, Widget search, FrostPageHeaderSearchController header) builder;
  final String text;

  @override
  State<SearchHost> createState() => _SearchHostState();
}

class _SearchHostState extends State<SearchHost> {
  late final _controller = TextEditingController(text: widget.text);
  final _focus = FocusNode();
  final _header = FrostPageHeaderSearchController();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _header.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    FrostSearchInput(controller: _controller, focusNode: _focus, placeholder: 'Find', leadingIcon: true, onSubmitted: _ignore),
    _header,
  );
}

void _ignore(String _) {}

/// Taps the text field inside the subject, which focuses a search field.
Future<void> tapField(WidgetTester tester, Finder subject) async {
  await tester.tap(find.descendant(of: subject, matching: find.byType(EditableText)).first);
}

/// Opens the More menu of a toolbar.
Future<void> tapMore(WidgetTester tester, Finder subject) async {
  await tester.tap(find.byWidgetPredicate((w) => w is FrostButtonControl && w.label == 'L.more').hitTestable().first);
}

/// Taps the first hit-testable frost button in the subject. Toolbars also hold
/// invisible measuring copies of their items, which a plain finder returns first.
Future<void> tapButton(WidgetTester tester, Finder subject) =>
    tester.tap(find.descendant(of: subject, matching: find.byType(FrostButtonControl)).hitTestable().first);

/// Owns a tabs controller with [count] tabs named `Tab 1`..., the one at
/// [active] in front. With [base], the first tab is the permanent `Home`.
class TabsHost extends StatefulWidget {
  const TabsHost({required this.builder, this.count = 1, this.active = 0, this.base = false, super.key});
  final Widget Function(BuildContext context, FrostTabsController<String> controller) builder;
  final int count;
  final int active;
  final bool base;

  @override
  State<TabsHost> createState() => _TabsHostState();
}

class _TabsHostState extends State<TabsHost> {
  late final FrostTabsController<String> _controller = _create();

  FrostTabsController<String> _create() {
    final controller = widget.base ? FrostTabsController<String>.withBaseTab(baseTab: 'Home') : FrostTabsController<String>(initial: 'Tab 1');
    for (var i = widget.base ? 1 : 2; i <= widget.count; i++) {
      controller.open('Tab $i', activate: false);
    }
    controller.activate(widget.active);
    return controller;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controller);
}

/// Owns a title registry and shows the titles it holds for `/` and `/other`.
class RegistryHost extends StatefulWidget {
  const RegistryHost({required this.builder, super.key});
  final Widget Function(BuildContext context) builder;
  @override
  State<RegistryHost> createState() => _RegistryHostState();
}

class _RegistryHostState extends State<RegistryHost> {
  final _registry = FrostWindowTitleRegistry();

  @override
  void dispose() {
    _registry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FrostWindowTitleScope(
    registry: _registry,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListenableBuilder(
          listenable: _registry,
          builder: (context, _) => Text('root=${_registry.page('/')?.title}, other=${_registry.page('/other')?.title}, kind=${_registry.page('/')?.kind}'),
        ),
        Builder(builder: widget.builder),
      ],
    ),
  );
}
