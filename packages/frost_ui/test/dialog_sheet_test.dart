import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_control.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';
import 'package:frost_ui/src/overlays/_modal_frame.dart';
import 'package:frost_ui/src/primitives/_click_feedback.dart';
import 'package:material_ui/material_ui.dart';

import 'app_router_test.dart' show TestRouter;
import 'support.dart';

Future<void> launch(
  WidgetTester tester,
  void Function(BuildContext) open, {
  Size size = const Size(900, 700),
  bool settle = true,
  FocusNode? origin,
  bool reduced = false,
  bool router = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final body = Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
      child: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FrostButtonControl(label: 'Open', focusNode: origin, onPressed: () => open(context)),
          ),
        ),
      ),
    ),
  );
  if (router) {
    final delegate = TestRouter(body);
    addTearDown(delegate.dispose);
    await tester.pumpWidget(
      FrostApp.router(
        config: testConfig,
        title: 'Test',
        routerConfig: RouterConfig<Object>(routerDelegate: delegate),
      ),
    );
  } else {
    await tester.pumpWidget(frostTestApp(body));
  }
  if (origin != null) {
    origin.requestFocus();
    await tester.pump();
  }
  await tester.tap(find.text('Open'));
  await tester.pump();
  if (settle) await tester.pumpAndSettle();
}

Finder get modalSurface => find.byWidgetPredicate((widget) => widget is FrostSurface && widget.role == FrostSurfaceRole.sheet);

FrostButtonControl action(WidgetTester tester, String label) =>
    tester.widget<FrostButtonControl>(find.byWidgetPredicate((widget) => widget is FrostButtonControl && widget.label == label));

double dividerOpacity(WidgetTester tester, bool atTop) => tester
    .renderObject<RenderFrostModalScrollDivider>(find.byWidgetPredicate((widget) => widget is FrostModalScrollDivider && widget.atTop == atTop))
    .paintedOpacity;

void main() {
  testWidgets('Alert measures 400 and orders the same buttons in the cold frame', (tester) async {
    await launch(
      tester,
      (context) => showFrostAlert<int>(
        context: context,
        title: 'Title',
        message: 'Message',
        actions: const [
          FrostDialogAction(label: 'Go', value: 1, isDefault: true),
          FrostDialogAction(label: 'Other', value: 2),
          FrostDialogAction(label: 'Cancel', value: 0, role: FrostButtonRole.cancel),
        ],
      ),
      settle: false,
    );
    expect(tester.getSize(modalSurface).width, 400);
    expect(tester.getTopLeft(find.text('Cancel')).dx, lessThan(tester.getTopLeft(find.text('Other')).dx));
    expect(tester.getTopLeft(find.text('Other')).dx, lessThan(tester.getTopLeft(find.text('Go')).dx));
    expect(tester.getCenter(find.text('Cancel')).dy, tester.getCenter(find.text('Go')).dy);
    expect(action(tester, 'Go').variant, FrostButtonVariant.prominent);
    expect(action(tester, 'Other').variant, FrostButtonVariant.standard);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Alert overflows into full width default-first cancel-last before paint', (tester) async {
    await launch(
      tester,
      (context) => showFrostAlert(
        context: context,
        title: 'Title',
        actions: const [
          FrostDialogAction(label: 'Cancel a very long operation', role: FrostButtonRole.cancel),
          FrostDialogAction(label: 'Keep another long operation'),
          FrostDialogAction(label: 'Delete a very long operation', isDefault: true, role: FrostButtonRole.destructive),
        ],
      ),
      settle: false,
    );
    final buttons = ['Delete a very long operation', 'Keep another long operation', 'Cancel a very long operation'];
    for (var index = 1; index < buttons.length; index++) {
      expect(tester.getCenter(find.text(buttons[index])).dy, greaterThan(tester.getCenter(find.text(buttons[index - 1])).dy));
    }
    for (final label in buttons) {
      final button = find.byWidgetPredicate((widget) => widget is FrostButtonControl && widget.label == label);
      expect(tester.getSize(button).width, 360);
      final paintedFill = find.descendant(of: button, matching: find.byType(FrostInteractionDecoration)).first;
      expect(tester.getSize(paintedFill).width, 360);
    }
    expect(action(tester, buttons.first).variant, FrostButtonVariant.prominent);
    expect(action(tester, buttons.first).role, FrostButtonRole.destructive);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Alert asserts duplicate defaults or cancels', (tester) async {
    expect(
      () => FrostAlert(
        title: 'Title',
        actions: const [
          FrostDialogAction(label: 'A', isDefault: true),
          FrostDialogAction(label: 'B', isDefault: true),
        ],
      ),
      throwsAssertionError,
    );
    expect(
      () => FrostDialog(
        title: 'Title',
        content: const SizedBox(),
        actions: const [
          FrostDialogAction(label: 'A', role: FrostButtonRole.cancel),
          FrostDialogAction(label: 'B', role: FrostButtonRole.cancel),
        ],
      ),
      throwsAssertionError,
    );
  });

  testWidgets('Enter returns default value and focus restores to origin', (tester) async {
    final origin = FocusNode();
    addTearDown(origin.dispose);
    int? result;
    await launch(
      tester,
      (context) async => result = await showFrostAlert<int>(
        context: context,
        title: 'Title',
        actions: const [FrostDialogAction(label: 'Accept', value: 7, isDefault: true)],
      ),
      origin: origin,
    );
    expect(action(tester, 'Accept').focusNode!.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(result, 7);
    expect(origin.hasFocus, isTrue);
  });

  testWidgets('Escape uses cancel value and disabled cancel blocks scrim fallback', (tester) async {
    int? result;
    await launch(
      tester,
      (context) async => result = await showFrostAlert<int>(
        context: context,
        title: 'Title',
        actions: const [
          FrostDialogAction(label: 'Cancel', value: 3, role: FrostButtonRole.cancel),
          FrostDialogAction(label: 'Accept', isDefault: true),
        ],
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(result, 3);
    await launch(
      tester,
      (context) => showFrostAlert(
        context: context,
        title: 'Disabled',
        actions: const [
          FrostDialogAction(label: 'Cancel', role: FrostButtonRole.cancel, enabled: false),
          FrostDialogAction(label: 'Accept', isDefault: true, enabled: false),
        ],
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Disabled'), findsOneWidget);
  });

  testWidgets('Dialog has 480/640 widths, viewport bound and compact 16 insets', (tester) async {
    for (final (size, viewport, width) in [
      (FrostDialogSize.regular, const Size(900, 700), 480.0),
      (FrostDialogSize.wide, const Size(900, 700), 640.0),
      (FrostDialogSize.wide, const Size(390, 700), 358.0),
    ]) {
      await launch(
        tester,
        (context) => showFrostDialog(
          context: context,
          builder: (_) => FrostDialog(title: 'Title', size: size, content: const SizedBox(height: 2000)),
        ),
        size: viewport,
      );
      expect(tester.getSize(modalSurface).width, width);
      expect(tester.getSize(modalSurface).height, lessThanOrEqualTo(viewport.height - 48));
      if (viewport.width == 390) expect(tester.getTopLeft(modalSurface).dx, 16);
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Default action gets first focus, multiline Enter leaves it untouched', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var calls = 0;
    await launch(
      tester,
      (context) => showFrostDialog(
        context: context,
        builder: (_) => FrostDialog(
          title: 'Title',
          content: TextField(controller: controller, maxLines: 3),
          actions: [
            FrostDialogAction(
              label: 'Accept',
              isDefault: true,
              onPressed: () {
                calls++;
                return false;
              },
            ),
          ],
        ),
      ),
    );
    expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasPrimaryFocus, isFalse);
    expect(action(tester, 'Accept').focusNode!.hasPrimaryFocus, isTrue);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls, 0);
    await tester.enterText(find.byType(TextField), 'a\nb');
    expect(controller.text, 'a\nb');
  });

  testWidgets('Lazy Dialog uses primary controller and dividers fade from measured edges', (tester) async {
    ScrollController? scroll;
    await launch(
      tester,
      (context) => showFrostDialog(
        context: context,
        builder: (_) => FrostDialog(
          title: 'Title',
          scrollable: false,
          content: Builder(
            builder: (context) {
              scroll = PrimaryScrollController.of(context);
              return ListView.builder(itemCount: 1000, itemExtent: 40, itemBuilder: (_, index) => Text('Row $index'));
            },
          ),
          actions: const [FrostDialogAction(label: 'Accept', isDefault: true)],
        ),
      ),
      settle: false,
    );
    expect(dividerOpacity(tester, true), 0);
    expect(dividerOpacity(tester, false), 1);
    scroll!.jumpTo(100);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    expect(dividerOpacity(tester, true), inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 70));
    expect(dividerOpacity(tester, true), 1);
    scroll!.jumpTo(scroll!.position.maxScrollExtent);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    expect(dividerOpacity(tester, false), inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 70));
    expect(dividerOpacity(tester, false), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Async Enter runs once and follows the 300/400 loading gate', (tester) async {
    var calls = 0;
    final pending = Completer<bool>();
    await launch(
      tester,
      (context) => showFrostDialog(
        context: context,
        builder: (_) => FrostDialog(
          title: 'Title',
          content: const Text('Form'),
          actions: [
            FrostDialogAction(
              label: 'Accept',
              isDefault: true,
              onPressed: () {
                calls++;
                return pending.future;
              },
            ),
          ],
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls, 1);
    expect(action(tester, 'Accept').loading, isTrue);
    final gate = find.descendant(
      of: find.byWidgetPredicate((widget) => widget is FrostButtonControl && widget.label == 'Accept'),
      matching: find.byType(FrostLoadingGate),
    );
    final spinner = find.descendant(of: gate, matching: find.byType(FrostActivityIndicator));
    double spinnerOpacity() => tester.widget<AnimatedOpacity>(find.ancestor(of: spinner, matching: find.byType(AnimatedOpacity)).first).opacity;
    expect(spinnerOpacity(), 0);
    await tester.pump(const Duration(milliseconds: 299));
    expect(spinnerOpacity(), 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(spinnerOpacity(), 1);
    pending.complete(false);
    await tester.pump();
    expect(action(tester, 'Accept').loading, isFalse);
    expect(find.text('Title'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 399));
    expect(spinnerOpacity(), 1);
    await tester.pump(const Duration(milliseconds: 1));
    expect(spinnerOpacity(), 0);
  });

  testWidgets('Cancel during async execution drops the late completion', (tester) async {
    final pending = Completer<bool>();
    Object? result;
    await launch(
      tester,
      (context) async => result = await showFrostAlert(
        context: context,
        title: 'Title',
        actions: [
          FrostDialogAction(label: 'Accept', value: 'accepted', isDefault: true, onPressed: () => pending.future),
          const FrostDialogAction(label: 'Cancel', value: 'cancelled', role: FrostButtonRole.cancel),
        ],
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(result, 'cancelled');
    pending.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Action exceptions are reported and restore the open modal', (tester) async {
    await launch(
      tester,
      (context) => showFrostAlert(
        context: context,
        title: 'Title',
        actions: [FrostDialogAction(label: 'Accept', isDefault: true, onPressed: () => throw StateError('validation'))],
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isStateError);
    expect(find.text('Title'), findsOneWidget);
    expect(action(tester, 'Accept').loading, isFalse);
    expect(action(tester, 'Accept').onPressed, isNotNull);
  });

  testWidgets('An action that shortens the list leaves focus in the dialog', (tester) async {
    var second = true;
    late StateSetter update;
    await launch(
      tester,
      (context) => showFrostDialog<void>(
        context: context,
        builder: (_) => StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return FrostDialog(
              title: 'Title',
              content: const SizedBox(),
              actions: [
                const FrostDialogAction<Object?>(label: 'Cancel', role: FrostButtonRole.cancel),
                if (second)
                  FrostDialogAction<Object?>(
                    label: 'Continue',
                    isDefault: true,
                    onPressed: () {
                      update(() => second = false);
                      return false;
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Continue'), findsNothing);
    final focused = FocusManager.instance.primaryFocus!.context!;
    expect(focused.findAncestorWidgetOfExactType<FrostDialog>(), isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Confirm is Alert on wide and all cancel paths return false', (tester) async {
    for (final mode in ['button', 'escape', 'barrier']) {
      bool? result;
      await launch(tester, (context) async => result = await showFrostConfirm(context: context, title: 'Confirm', confirmLabel: 'Delete'));
      expect(find.byType(FrostAlert), findsOneWidget);
      expect(find.text('L.cancel'), findsOneWidget);
      if (mode == 'button') await tester.tap(find.text('L.cancel'));
      if (mode == 'escape') await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      if (mode == 'barrier') await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    }
  });

  testWidgets('Compact Confirm is a sheet with full width default above cancel', (tester) async {
    bool? result;
    await launch(
      tester,
      (context) async => result = await showFrostConfirm(context: context, title: 'Confirm', message: 'Message', confirmLabel: 'Delete'),
      size: const Size(390, 800),
    );
    expect(find.byType(FrostAlert), findsNothing);
    expect(tester.getSize(modalSurface).width, 390);
    expect(tester.getCenter(find.text('Delete')).dy, lessThan(tester.getCenter(find.text('L.cancel')).dy));
    for (final label in ['Delete', 'L.cancel']) {
      final button = find.byWidgetPredicate((widget) => widget is FrostButtonControl && widget.label == label);
      expect(tester.getSize(find.descendant(of: button, matching: find.byType(FrostInteractionDecoration)).first).width, 350);
    }
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('Sheet sorts/deduplicates detents, has exact handle, and springs between heights', (tester) async {
    await launch(
      tester,
      (context) => showFrostSheet(
        context: context,
        title: 'Sheet',
        detents: const [FrostSheetDetent.large, FrostSheetDetent.medium, FrostSheetDetent.large],
        builder: (_) => const Text('Content'),
      ),
      size: const Size(390, 800),
    );
    expect(tester.getSize(modalSurface).height, 400);
    final handle = find.byWidgetPredicate((widget) => widget is Container && widget.constraints?.maxWidth == 36 && widget.constraints?.maxHeight == 5);
    expect(tester.getSize(handle), const Size(36, 5));
    expect(tester.getTopLeft(handle).dy - tester.getTopLeft(modalSurface).dy, 6);
    await tester.fling(handle, const Offset(0, -90), 800);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(tester.getSize(modalSurface).height, inExclusiveRange(490, 792));
    await tester.pumpAndSettle();
    expect(tester.getSize(modalSurface).height, 792);
    await tester.fling(find.text('Sheet'), const Offset(0, 80), 800);
    await tester.pumpAndSettle();
    expect(tester.getSize(modalSurface).height, 400);
    await tester.fling(find.text('Sheet'), const Offset(0, 80), 800);
    await tester.pumpAndSettle();
    expect(modalSurface, findsNothing);
  });

  testWidgets('Single detent closes only after the minimum pull boundary', (tester) async {
    await launch(
      tester,
      (context) => showFrostSheet(context: context, title: 'Sheet', detents: const [FrostSheetDetent.medium], builder: (_) => const Text('Content')),
      size: const Size(390, 800),
    );
    await tester.timedDrag(find.text('Sheet'), const Offset(0, 80), const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(tester.getSize(modalSurface).height, 400);
    await tester.timedDrag(find.text('Sheet'), const Offset(0, 120), const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(modalSurface, findsNothing);
  });

  testWidgets('Mouse dragging the sheet header selects large without barrier dismissal', (tester) async {
    await launch(
      tester,
      (context) => showFrostSheet(
        context: context,
        title: 'Sheet',
        detents: const [FrostSheetDetent.medium, FrostSheetDetent.large],
        builder: (_) => const Text('Content'),
      ),
      size: const Size(390, 800),
    );
    final handle = find.byWidgetPredicate((widget) => widget is Container && widget.constraints?.maxWidth == 36 && widget.constraints?.maxHeight == 5);
    await tester.drag(handle, const Offset(0, -250), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(tester.getSize(modalSurface).height, 792);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Escape closes a lazy Sheet with no focusable content under both app entries', (tester) async {
    for (final router in [false, true]) {
      await launch(
        tester,
        (context) => showFrostSheet(
          context: context,
          title: 'Sheet',
          scrollable: false,
          builder: (_) => ListView.builder(itemCount: 100, itemBuilder: (_, index) => Text('Item $index')),
        ),
        size: const Size(390, 800),
        router: router,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(modalSurface, findsNothing, reason: FocusManager.instance.rootScope.toStringDeep());
    }
  });

  testWidgets('Lazy Sheet constructs visible rows and consumes downward drag only after list top', (tester) async {
    ScrollController? scroll;
    final built = <int>{};
    await launch(
      tester,
      (context) => showFrostSheet(
        context: context,
        title: 'Sheet',
        detents: const [FrostSheetDetent.medium, FrostSheetDetent.large],
        scrollable: false,
        builder: (context) {
          scroll = PrimaryScrollController.of(context);
          return ListView.builder(
            itemCount: 1000,
            itemExtent: 40,
            itemBuilder: (_, index) {
              built.add(index);
              return Text('Row $index');
            },
          );
        },
      ),
      size: const Size(390, 800),
    );
    expect(built.length, lessThan(30));
    scroll!.jumpTo(100);
    await tester.pump();
    await tester.timedDrag(find.byType(ListView), const Offset(0, 60), const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(tester.getSize(modalSurface).height, 400);
    expect(scroll!.offset, closeTo(40, 2));
    scroll!.jumpTo(0);
    await tester.pump();
    final gesture = await tester.startGesture(tester.getCenter(find.byType(ListView)));
    await gesture.moveBy(const Offset(0, 70));
    await tester.pump();
    expect(tester.getSize(modalSurface).height, lessThan(400));
    expect(scroll!.offset, 0);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Keyboard opens and closes with standard spring rather than jumping height', (tester) async {
    await launch(
      tester,
      (context) => showFrostSheet(context: context, title: 'Sheet', detents: const [FrostSheetDetent.medium], builder: (_) => const Text('Content')),
      size: const Size(390, 800),
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    expect(tester.getSize(modalSurface).height, 400);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getSize(modalSurface).height, inExclusiveRange(300, 400));
    await tester.pumpAndSettle();
    expect(tester.getSize(modalSurface).height, 300);
    tester.view.resetViewInsets();
    await tester.pump();
    expect(tester.getSize(modalSurface).height, 300);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getSize(modalSurface).height, inExclusiveRange(300, 400));
    await tester.pumpAndSettle();
    expect(tester.getSize(modalSurface).height, 400);
  });

  testWidgets('Wide Sheet ignores detents and supplies close, focus and Escape', (tester) async {
    await launch(
      tester,
      (context) => showFrostSheet(context: context, title: 'Sheet', detents: const [FrostSheetDetent.medium], builder: (_) => const TextField()),
    );
    expect(tester.getSize(modalSurface).width, 480);
    expect(findFrostTooltip('L.close'), findsOneWidget);
    expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasPrimaryFocus, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(modalSurface, findsNothing);
  });

  testWidgets('Reduced Sheet entry has opacity intermediate frames and no movement', (tester) async {
    await launch(
      tester,
      (context) => showFrostSheet(context: context, title: 'Sheet', builder: (_) => const Text('Content')),
      size: const Size(390, 800),
      reduced: true,
      settle: false,
    );
    final initial = tester.getTopLeft(modalSurface);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getTopLeft(modalSurface), initial);
    final fade = tester.widget<FrostMaterialRevealTransition>(find.ancestor(of: modalSurface, matching: find.byType(FrostMaterialRevealTransition)).first);
    expect(fade.opacity.value, inExclusiveRange(0, 1));
    expect(tester.widget<SlideTransition>(find.ancestor(of: modalSurface, matching: find.byType(SlideTransition)).first).position.value, Offset.zero);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Action variants render role ink and the sheet material uses xl and dual shadows', (tester) async {
    late FrostThemeTokens tokens;
    await launch(tester, (context) {
      tokens = FrostThemeTokens.of(context);
      showFrostAlert(
        context: context,
        title: 'Title',
        actions: const [
          FrostDialogAction(label: 'Delete', isDefault: true, role: FrostButtonRole.destructive),
          FrostDialogAction(label: 'Remove', role: FrostButtonRole.destructive),
          FrostDialogAction(label: 'Cancel', role: FrostButtonRole.cancel),
        ],
      );
    });
    Color? ink(String label) => tester.renderObject<RenderParagraph>(find.descendant(of: find.text(label), matching: find.byType(RichText))).text.style?.color;
    expect(ink('Delete'), tokens.onNegative);
    expect(ink('Remove'), tokens.negativeInk);
    expect(ink('Cancel'), tokens.textPrimary);
    final surface = tester.widget<FrostSurface>(modalSurface);
    expect(surface.borderRadius, FrostRadius.borderRadius(FrostRadius.xl));
    expect(surface.elevated, isTrue);
    final decorations = tester.widgetList<DecoratedBox>(find.descendant(of: modalSurface, matching: find.byType(DecoratedBox)));
    expect(
      decorations.any(
        (widget) => switch (widget.decoration) {
          ShapeDecoration(:final shadows) => shadows?.length == 2,
          BoxDecoration(:final boxShadow) => boxShadow?.length == 2,
          _ => false,
        },
      ),
      isTrue,
    );
  });

  testWidgets('Enter activates the focused Cancel and Tab stays within modal', (tester) async {
    final origin = FocusNode();
    addTearDown(origin.dispose);
    int? result;
    await launch(
      tester,
      (context) async => result = await showFrostAlert<int>(
        context: context,
        title: 'Title',
        actions: const [
          FrostDialogAction(label: 'Cancel', value: 0, role: FrostButtonRole.cancel),
          FrostDialogAction(label: 'Go', value: 1, isDefault: true),
        ],
      ),
      origin: origin,
    );
    for (var index = 0; index < 6; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(origin.hasFocus, isFalse);
    }
    action(tester, 'Cancel').focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(result, 0);
  });

  group('sheet drag release', () {
    Future<ScrollController> list(WidgetTester tester) async {
      late ScrollController scroll;
      await launch(
        tester,
        (context) => showFrostSheet(
          context: context,
          title: 'Sheet',
          scrollable: false,
          builder: (context) {
            scroll = PrimaryScrollController.of(context);
            return ListView.builder(itemCount: 200, itemExtent: 40, itemBuilder: (_, index) => Text('Row $index'));
          },
        ),
        size: const Size(390, 800),
      );
      return scroll;
    }

    // Drags the list to its top, then [pull] pixels into the sheet, at [speed] px/s.
    Future<void> pullThroughList(WidgetTester tester, ScrollController scroll, double pull, double speed) async {
      scroll.jumpTo(10);
      await tester.pump();
      final rest = tester.getTopLeft(modalSurface).dy;
      final gesture = await tester.startGesture(tester.getCenter(find.byType(ListView)));
      final step = Duration(microseconds: (1e6 / speed).round());
      var time = Duration.zero;
      for (var guard = 0; guard < 400 && tester.getTopLeft(modalSurface).dy - rest < pull; guard++) {
        time += step;
        await gesture.moveBy(const Offset(0, 1), timeStamp: time);
        await tester.pump(step);
      }
      expect(tester.getTopLeft(modalSurface).dy - rest, closeTo(pull, 1));
      await gesture.up(timeStamp: time + const Duration(microseconds: 1));
      await tester.pumpAndSettle();
    }

    for (final pull in [1.0, 23.0]) {
      testWidgets('$pull px into the sheet at 600 px/s stays open and returns to rest', (tester) async {
        final scroll = await list(tester);
        final rest = tester.getTopLeft(modalSurface).dy;
        await pullThroughList(tester, scroll, pull, 600);
        expect(modalSurface, findsOneWidget);
        expect(tester.getTopLeft(modalSurface).dy, rest);
      });
    }

    testWidgets('25 px into the sheet at 600 px/s dismisses', (tester) async {
      final scroll = await list(tester);
      await pullThroughList(tester, scroll, 25, 600);
      expect(modalSurface, findsNothing);
    });

    testWidgets('25 px into the sheet slowly stays open', (tester) async {
      final scroll = await list(tester);
      final rest = tester.getTopLeft(modalSurface).dy;
      await pullThroughList(tester, scroll, 25, 100);
      expect(modalSurface, findsOneWidget);
      expect(tester.getTopLeft(modalSurface).dy, rest);
    });

    for (final (name, primary) in [('its own controller', false), ('the sheet controller', true)]) {
      testWidgets('a list nested in scrolling content with $name never stops the sheet midway', (tester) async {
        await launch(
          tester,
          (context) => showFrostSheet(
            context: context,
            title: 'Sheet',
            builder: (_) => SizedBox(
              height: 300,
              child: ListView.builder(primary: primary, itemCount: 100, itemExtent: 40, itemBuilder: (_, index) => Text('Row $index')),
            ),
          ),
          size: const Size(390, 800),
        );
        final rest = tester.getTopLeft(modalSurface).dy;
        final gesture = await tester.startGesture(tester.getCenter(find.byType(ListView)));
        for (var index = 0; index < 6; index++) {
          await gesture.moveBy(const Offset(0, 10), timeStamp: Duration(milliseconds: 200 * index));
          await tester.pump(const Duration(milliseconds: 200));
        }
        await gesture.up(timeStamp: const Duration(milliseconds: 1400));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(modalSurface).dy, rest);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a horizontal list in a sheet does not move the sheet', (tester) async {
      await launch(
        tester,
        (context) => showFrostSheet(
          context: context,
          title: 'Sheet',
          builder: (_) => SizedBox(
            height: 100,
            child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: 100, itemExtent: 80, itemBuilder: (_, index) => Text('Cell $index')),
          ),
        ),
        size: const Size(390, 800),
      );
      final rest = tester.getTopLeft(modalSurface).dy;
      await tester.drag(find.text('Cell 1'), const Offset(100, 0));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(modalSurface).dy, rest);
    });
  });

  group('inherited scrolling inside a sheet', () {
    Future<void> open(WidgetTester tester, {ScrollPhysics? physics, ScrollBehavior? behavior}) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 800);
      addTearDown(tester.view.reset);
      final button = Builder(
        builder: (context) => FrostButton(
          label: 'Open',
          onPressed: () => showFrostSheet<void>(
            context: context,
            scrollable: false,
            builder: (_) => ListView.builder(physics: physics, itemCount: 200, itemExtent: 40, itemBuilder: (_, index) => Text('Row $index')),
          ),
        ),
      );
      // Above the navigator, where an app configures scrolling for its routes.
      await tester.pumpWidget(
        FrostScope(
          config: testConfig,
          child: MaterialApp(
            theme: FrostTheme.build(config: testConfig, brightness: Brightness.light, platform: TargetPlatform.windows, locale: const Locale('en')),
            builder: (context, child) => behavior == null ? child! : ScrollConfiguration(behavior: behavior, child: child!),
            home: Scaffold(body: button),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('an app ScrollConfiguration reaches the sheet list', (tester) async {
      await open(tester, behavior: const _MouseDragBehavior());
      final position = tester.state<ScrollableState>(find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable))).position;
      await tester.drag(find.byType(ListView), const Offset(0, -150), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(100));
    });

    testWidgets('a list keeps its custom physics and still leads into the sheet at its top', (tester) async {
      await open(tester, physics: const _HalfSpeedPhysics());
      final position = tester.state<ScrollableState>(find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable))).position;
      final gesture = await tester.startGesture(tester.getCenter(find.byType(ListView)));
      await gesture.moveBy(const Offset(0, -40));
      await gesture.moveBy(const Offset(0, -100));
      await tester.pump();
      expect(position.pixels, closeTo(70, .5), reason: 'all 140 px run through the custom physics at half speed');
      await gesture.up();
      await tester.pumpAndSettle();
      position.jumpTo(0);
      await tester.pump();
      final rest = tester.getTopLeft(modalSurface).dy;
      final pull = await tester.startGesture(tester.getCenter(find.byType(ListView)));
      await pull.moveBy(const Offset(0, 60));
      await tester.pump();
      expect(tester.getTopLeft(modalSurface).dy, greaterThan(rest));
      await pull.up();
      await tester.pumpAndSettle();
    });
  });

  group('form dialog keyboard', () {
    testWidgets('Enter on a highlighted menu item selects it, leaves the dialog idle and Save working', (tester) async {
      var submits = 0;
      final picked = <String>[];
      await launch(
        tester,
        (context) => showFrostFormDialog(
          context: context,
          title: 'Form',
          sections: [
            FrostPicker<String>.menu(
              label: 'Choice',
              value: 'a',
              options: const [
                FrostPickerOption(value: 'a', label: 'Alpha'),
                FrostPickerOption(value: 'b', label: 'Bravo'),
              ],
              onChanged: picked.add,
            ),
          ],
          submitLabel: 'Save',
          onSubmit: () {
            submits++;
            return false;
          },
        ),
      );
      await tester.tap(find.byType(FrostPicker<String>));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(submits, 0);
      expect(picked, ['b']);
      expect(action(tester, 'Save').activity.loading, isFalse);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(submits, 1);
    });

    testWidgets('an app Focus that consumes Enter wins over the default action', (tester) async {
      var saves = 0, consumed = 0;
      final inner = FocusNode();
      addTearDown(inner.dispose);
      await launch(
        tester,
        (context) => showFrostDialog(
          context: context,
          builder: (_) => FrostDialog(
            title: 'Title',
            content: Focus(
              focusNode: inner,
              autofocus: true,
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.enter) return KeyEventResult.ignored;
                consumed++;
                return KeyEventResult.handled;
              },
              child: const Text('Body'),
            ),
            actions: [
              FrostDialogAction(
                label: 'Save',
                isDefault: true,
                onPressed: () {
                  saves++;
                  return false;
                },
              ),
            ],
          ),
        ),
      );
      expect(inner.hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(consumed, 1);
      expect(saves, 0);
    });

    testWidgets('a submit accepted while a picker menu is open closes the dialog instead of staying busy', (tester) async {
      final pending = Completer<bool>();
      bool? result;
      await launch(tester, (context) async {
        result = await showFrostFormDialog(
          context: context,
          title: 'Form',
          sections: [
            FrostPicker<String>.menu(
              label: 'Choice',
              value: 'a',
              options: const [
                FrostPickerOption(value: 'a', label: 'Alpha'),
                FrostPickerOption(value: 'b', label: 'Bravo'),
              ],
              onChanged: (_) {},
            ),
          ],
          submitLabel: 'Save',
          onSubmit: () => pending.future,
        );
      });
      await tester.tap(find.text('Save'));
      await tester.pump();
      // The busy button animates, so these wait by time rather than settling.
      await tester.tap(find.byType(FrostPicker<String>));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Bravo'), findsOneWidget);
      pending.complete(true);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(result, isTrue);
      expect(find.byType(FrostDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('field completion in a form-less dialog', () {
    Future<List<String>> open(WidgetTester tester, {FrostButtonRole role = FrostButtonRole.normal, int maxLines = 1}) async {
      final saved = <String>[];
      await launch(
        tester,
        (context) => showFrostDialog(
          context: context,
          builder: (_) => FrostDialog(
            title: 'Rename',
            content: FrostTextField(label: 'Name', autofocus: true, maxLines: maxLines),
            actions: [
              FrostDialogAction(
                label: 'Save',
                isDefault: true,
                role: role,
                onPressed: () {
                  saved.add('save');
                  return false;
                },
              ),
            ],
          ),
        ),
      );
      return saved;
    }

    testWidgets('a single-line field runs the default action', (tester) async {
      final saved = await open(tester);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(saved, ['save']);
    });

    testWidgets('a destructive default is not run by finishing a field', (tester) async {
      final saved = await open(tester, role: FrostButtonRole.destructive);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(saved, isEmpty);
    });

    testWidgets('a field in a popover inside the dialog does not submit it', (tester) async {
      var saves = 0;
      await launch(
        tester,
        (context) => showFrostDialog(
          context: context,
          builder: (_) => FrostDialog(
            title: 'Rename',
            content: FrostPopover(
              builder: (_, focus, toggle) => FrostButtonControl(label: 'More', focusNode: focus, onPressed: toggle),
              contentBuilder: (_, close) => const FrostTextField(label: 'Inner', autofocus: true),
            ),
            actions: [
              FrostDialogAction(
                label: 'Save',
                isDefault: true,
                onPressed: () {
                  saves++;
                  return false;
                },
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(saves, 0);
    });
  });

  testWidgets('Enter right after opening a sheet does not close it', (tester) async {
    await launch(
      tester,
      (context) => showFrostSheet(context: context, title: 'Sheet', barrierDismissible: false, builder: (_) => const Text('Body')),
      size: const Size(390, 800),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Body'), findsOneWidget);
  });

  group('sheet review findings', () {
    double top(WidgetTester tester, String text) => tester.getTopLeft(find.text(text)).dy;

    Future<void> slowDrag(WidgetTester tester, Offset at, Offset step, int count) async {
      final gesture = await tester.startGesture(at);
      for (var index = 0; index < count; index++) {
        await gesture.moveBy(step, timeStamp: Duration(milliseconds: 200 * index));
        await tester.pump(const Duration(milliseconds: 200));
      }
      await gesture.up(timeStamp: Duration(milliseconds: 200 * count + 200));
      await tester.pumpAndSettle();
    }

    testWidgets('a drag up then a small flick down does not dismiss', (tester) async {
      await launch(
        tester,
        (context) => showFrostSheet(
          context: context,
          title: 'S',
          detents: const [FrostSheetDetent.medium, FrostSheetDetent.large],
          builder: (_) => const SizedBox(height: 100, child: Text('Body')),
        ),
        size: const Size(390, 800),
      );
      final gesture = await tester.startGesture(tester.getCenter(find.text('S')));
      await gesture.moveBy(const Offset(0, -30), timeStamp: Duration.zero);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveBy(const Offset(0, -30), timeStamp: const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveBy(const Offset(0, -30), timeStamp: const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveBy(const Offset(0, 10), timeStamp: const Duration(milliseconds: 216));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveBy(const Offset(0, 10), timeStamp: const Duration(milliseconds: 232));
      await gesture.up(timeStamp: const Duration(milliseconds: 240));
      await tester.pumpAndSettle();
      expect(find.text('Body'), findsOneWidget);
    });

    testWidgets('a reversed list at its start scrolls instead of shrinking the sheet', (tester) async {
      await launch(
        tester,
        (context) => showFrostSheet(
          context: context,
          title: 'S',
          scrollable: false,
          builder: (_) => Column(
            children: [
              const Text('Marker'),
              Expanded(child: ListView.builder(primary: true, reverse: true, itemCount: 100, itemExtent: 40, itemBuilder: (_, index) => Text('Row $index'))),
            ],
          ),
        ),
        size: const Size(390, 800),
      );
      final rest = top(tester, 'Marker');
      final gesture = await tester.startGesture(tester.getCenter(find.text('Row 3')));
      for (var index = 0; index < 6; index++) {
        await gesture.moveBy(const Offset(0, -20), timeStamp: Duration(milliseconds: 200 * index));
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(top(tester, 'Marker'), rest);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    for (final (name, physics) in [('default', null), ('NeverScrollable', const NeverScrollableScrollPhysics())]) {
      testWidgets('a nested shrink-wrapped $name list leaves the upward drag to the sheet content', (tester) async {
        await launch(
          tester,
          (context) => showFrostSheet(
            context: context,
            title: 'S',
            builder: (_) => ListView.builder(shrinkWrap: true, physics: physics, itemCount: 100, itemExtent: 40, itemBuilder: (_, index) => Text('Row $index')),
          ),
          size: const Size(390, 800),
        );
        final before = top(tester, 'Row 3');
        await slowDrag(tester, tester.getCenter(find.text('Row 3')), const Offset(0, -30), 6);
        expect(top(tester, 'Row 3'), lessThan(before));
      });
    }

    testWidgets('a list removed mid-drag leaves the sheet at rest', (tester) async {
      late StateSetter update;
      var show = true;
      await launch(
        tester,
        (context) => showFrostSheet(
          context: context,
          title: 'S',
          scrollable: false,
          builder: (_) => StatefulBuilder(
            builder: (_, set) {
              update = set;
              return Column(
                children: [
                  const Text('Marker'),
                  Expanded(child: show ? ListView.builder(itemCount: 100, itemExtent: 40, itemBuilder: (_, index) => Text('Row $index')) : const SizedBox()),
                ],
              );
            },
          ),
        ),
        size: const Size(390, 800),
      );
      final rest = top(tester, 'Marker');
      final gesture = await tester.startGesture(tester.getCenter(find.text('Row 3')));
      for (var index = 0; index < 6; index++) {
        await gesture.moveBy(const Offset(0, 10), timeStamp: Duration(milliseconds: 200 * index));
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(top(tester, 'Marker'), greaterThan(rest));
      update(() => show = false);
      await tester.pump();
      await gesture.up(timeStamp: const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(top(tester, 'Marker'), rest);
    });

    testWidgets('a route pushed mid-drag does not leave the sheet midway', (tester) async {
      await launch(
        tester,
        (context) => showFrostSheet(context: context, title: 'S', builder: (_) => const Text('Body')),
        size: const Size(390, 800),
      );
      final rest = top(tester, 'S');
      final gesture = await tester.startGesture(tester.getCenter(find.text('S')));
      await gesture.moveBy(const Offset(0, 60));
      await tester.pump();
      expect(top(tester, 'S'), greaterThan(rest));
      final navigator = Navigator.of(tester.element(find.text('S')));
      navigator.push(PageRouteBuilder<void>(opaque: false, pageBuilder: (_, _, _) => const SizedBox()));
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pumpAndSettle();
      navigator.pop();
      await tester.pumpAndSettle();
      expect(top(tester, 'S'), rest);
    });
  });
}

class _MouseDragBehavior extends ScrollBehavior {
  const _MouseDragBehavior();
  @override
  Set<PointerDeviceKind> get dragDevices => {...super.dragDevices, PointerDeviceKind.mouse};
}

class _HalfSpeedPhysics extends ClampingScrollPhysics {
  const _HalfSpeedPhysics({super.parent});
  @override
  _HalfSpeedPhysics applyTo(ScrollPhysics? ancestor) => _HalfSpeedPhysics(parent: buildParent(ancestor));
  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) => offset / 2;
}
