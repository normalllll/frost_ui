// Proves that every check can fail: each one runs against a deliberately
// violating widget (which must be judged a failure) and a compliant one (which
// must pass). A check that cannot fail would let a whole family go green.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'harness.dart';

const _start = ValueKey('fixture-start'), _end = ValueKey('fixture-end');

/// A small control. Every flag switches off one thing the contract demands.
class _Fixture extends StatefulWidget {
  const _Fixture({
    required this.onTap,
    this.honoursScope = true,
    this.marksDisabled = true,
    this.labelled = true,
    this.tapSemantics = true,
    this.focusable = true,
    this.hit = 48,
    this.rigidLabel = false,
    this.forceLtr = false,
    this.honoursReducedMotion = true,
    this.leaksFocus = false,
    this.leaksIncrease = false,
  });
  final VoidCallback onTap;
  final bool honoursScope, marksDisabled, labelled, tapSemantics, focusable, rigidLabel, forceLtr, honoursReducedMotion, leaksFocus, leaksIncrease;
  final double hit;

  @override
  State<_Fixture> createState() => _FixtureState();
}

class _FixtureState extends State<_Fixture> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _activate() {
    widget.onTap();
    if (!widget.honoursReducedMotion || !MediaQuery.disableAnimationsOf(context)) _controller.repeat();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !widget.honoursScope || FrostControlScope.enabledOf(context);
    const style = TextStyle(fontSize: 16);
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: widget.forceLtr ? TextDirection.ltr : null,
      children: [
        const SizedBox(key: _start, width: 24, height: 24),
        const SizedBox(width: 8),
        if (widget.rigidLabel)
          const SizedBox(
            width: 100,
            child: Row(
              children: [Text('Hello', key: _end, style: style)],
            ),
          )
        else
          const Flexible(
            child: Text('Hello world', key: _end, style: style),
          ),
      ],
    );
    Widget body = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? _activate : null,
      child: SizedBox(
        height: widget.hit,
        child: Center(widthFactor: 1, child: row),
      ),
    );
    if (widget.focusable) {
      body = FocusableActionDetector(
        enabled: enabled,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        child: body,
      );
    }
    final main = Semantics(
      container: true,
      button: true,
      enabled: widget.marksDisabled ? enabled : true,
      label: widget.labelled ? 'Go' : null,
      onTap: (enabled || !widget.marksDisabled) && widget.tapSemantics ? _activate : null,
      child: ExcludeSemantics(child: body),
    );
    if (!widget.leaksFocus && !widget.leaksIncrease) return main;
    // An extra node that keeps an action although the control is disabled.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        main,
        Semantics(
          container: true,
          onFocus: widget.leaksFocus ? () {} : null,
          onIncrease: widget.leaksIncrease ? () {} : null,
          child: const SizedBox(width: 4, height: 4),
        ),
      ],
    );
  }
}

InteractiveCase _control(String id, _Fixture Function(VoidCallback) make) =>
    InteractiveCase(id, _Fixture, make, start: find.byKey(_start), end: find.byKey(_end));

InteractiveCase _good() => _control('good', (activate) => _Fixture(onTap: activate));

Future<void> _expectViolation(WidgetTester tester, Future<String?> Function(WidgetTester, InteractiveCase) check, InteractiveCase violator, String why) async {
  expect(await check(tester, violator), contains(why), reason: 'the check must fail for the planted violation');
}

void main() {
  group('interactive checks fail on a violator', () {
    testWidgets('disabled-scope: a control that ignores FrostControlScope', (tester) async {
      await _expectViolation(tester, checkDisabledScope, _control('v', (a) => _Fixture(onTap: a, honoursScope: false)), 'was activated');
    });
    testWidgets('disabled-semantics: still marked enabled with a tap action', (tester) async {
      await _expectViolation(
        tester,
        checkDisabledSemantics,
        _control('v', (a) => _Fixture(onTap: a, marksDisabled: false)),
        'no semantics node is marked disabled',
      );
    });
    testWidgets('disabled-semantics: a node that keeps a focus action', (tester) async {
      await _expectViolation(
        tester,
        checkDisabledSemantics,
        _control('v', (a) => _Fixture(onTap: a, leaksFocus: true)),
        'focus on a node that is not marked disabled',
      );
    });
    testWidgets('disabled-semantics: a node that keeps an increase action', (tester) async {
      await _expectViolation(tester, checkDisabledSemantics, _control('v', (a) => _Fixture(onTap: a, leaksIncrease: true)), 'increase on a node');
    });
    testWidgets('semantics: no label', (tester) async {
      await _expectViolation(tester, checkSemantics, _control('v', (a) => _Fixture(onTap: a, labelled: false)), 'empty label');
    });
    testWidgets('semantics: no tap action', (tester) async {
      await _expectViolation(tester, checkSemantics, _control('v', (a) => _Fixture(onTap: a, tapSemantics: false)), 'no semantics node has a tap action');
    });
    testWidgets('keyboard: cannot be focused', (tester) async {
      await _expectViolation(tester, checkKeyboard, _control('v', (a) => _Fixture(onTap: a, focusable: false)), 'Tab does not move focus');
    });
    testWidgets('touch-target: hit area is 20 px tall', (tester) async {
      await _expectViolation(tester, checkTouchTarget, _control('v', (a) => _Fixture(onTap: a, hit: 20)), '4 corners');
    });
    testWidgets('text-scale: a fixed-width row overflows at 2x', (tester) async {
      await _expectViolation(tester, checkTextScale, _control('v', (a) => _Fixture(onTap: a, rigidLabel: true)), 'overflowed');
    });
    testWidgets('rtl: children keep their left-to-right order', (tester) async {
      await _expectViolation(tester, checkRtl, _control('v', (a) => _Fixture(onTap: a, forceLtr: true)), 'do not mirror');
    });
    testWidgets('rtl: a widget that throws in right-to-left', (tester) async {
      final thrower = InteractiveCase('v', _Throws, (_) => const _Throws());
      await _expectViolation(tester, checkRtl, thrower, 'right-to-left is not supported');
    });
    testWidgets('reduced-motion: keeps animating after activation', (tester) async {
      await _expectViolation(tester, checkReducedMotion, _control('v', (a) => _Fixture(onTap: a, honoursReducedMotion: false)), 'still running');
    });
    testWidgets('no-theme: renders silently without Frost', (tester) async {
      expect(await checkNoTheme(tester, Case('v', _Fixture, (_) => const SizedBox(width: 10, height: 10))), contains('rendered silently'));
    });
  });

  group('display checks fail on a violator', () {
    testWidgets('intrinsic: LayoutBuilder cannot answer intrinsic sizes', (tester) async {
      final c = DisplayCase('v', LayoutBuilder, (_) => LayoutBuilder(builder: (context, _) => const SizedBox(width: 10, height: 10)));
      expect(await checkIntrinsic(tester, c), contains('intrinsic'));
    });
    testWidgets('intrinsic: content measures zero', (tester) async {
      expect(await checkIntrinsic(tester, DisplayCase('v', SizedBox, (_) => const SizedBox.shrink())), contains('measured'));
    });
    testWidgets('intrinsic: a smaller intrinsic size than the natural one', (tester) async {
      final c = DisplayCase('v', _Lying, (_) => const _Lying());
      expect(await checkIntrinsic(tester, c), contains('below its natural'));
    });
    testWidgets('intrinsic: an interactive case is checked too', (tester) async {
      final c = InteractiveCase('v', _Lying, (_) => const _Lying());
      expect(await checkIntrinsic(tester, c), contains('below its natural'));
    });
    testWidgets('text-scale: text pushed outside the window without any error', (tester) async {
      final c = DisplayCase(
        'v',
        Transform,
        (_) => Transform.translate(
          offset: const Offset(150, 0),
          child: const Text('Hello world', style: TextStyle(fontSize: 16)),
        ),
      );
      expect(await checkTextScale(tester, c), contains('lies outside'));
    });
    testWidgets('text-scale: a display widget that overflows', (tester) async {
      final c = DisplayCase(
        'v',
        SizedBox,
        (_) => const SizedBox(
          width: 100,
          child: Row(children: [Text('Hello', style: TextStyle(fontSize: 16))]),
        ),
      );
      expect(await checkTextScale(tester, c), contains('overflowed'));
    });
  });

  group('compliant widgets pass', () {
    testWidgets('interactive fixture passes every interactive check', (tester) async {
      final c = _good();
      final results = {
        'disabled-scope': await checkDisabledScope(tester, c),
        'disabled-semantics': await checkDisabledSemantics(tester, c),
        'semantics': await checkSemantics(tester, c),
        'keyboard': await checkKeyboard(tester, c),
        'touch-target': await checkTouchTarget(tester, c),
        'text-scale': await checkTextScale(tester, c),
        'rtl': await checkRtl(tester, c),
        'reduced-motion': await checkReducedMotion(tester, c),
        'intrinsic': await checkIntrinsic(tester, c),
      };
      expect({
        for (final e in results.entries)
          if (e.value != null) e.key: e.value,
      }, isEmpty);
    });
    testWidgets('a widget that needs the Frost scope passes no-theme', (tester) async {
      expect(await checkNoTheme(tester, Case('g', _Fixture, (_) => Builder(builder: (context) => Text('${FrostScope.configOf(context).palettes}')))), isNull);
    });
    testWidgets('a display widget passes text-scale, rtl and intrinsic', (tester) async {
      final c = DisplayCase('g', Text, (_) => const Text('Hello world', style: TextStyle(fontSize: 16)));
      expect(await checkTextScale(tester, c), isNull);
      expect(await checkRtl(tester, c), isNull);
      expect(await checkIntrinsic(tester, c), isNull);
    });
    testWidgets('text-scale: long text in a scroll view the user cannot scroll', (tester) async {
      final c = DisplayCase(
        'v',
        SingleChildScrollView,
        (_) => const SizedBox(
          width: 300,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: NeverScrollableScrollPhysics(),
            child: Text('Hello world and a good deal more', style: TextStyle(fontSize: 16)),
          ),
        ),
      );
      expect(await checkTextScale(tester, c), contains('lies outside'));
    });
    testWidgets('long text in a scroll view passes text-scale', (tester) async {
      final c = DisplayCase(
        'g',
        SingleChildScrollView,
        (_) => const SizedBox(
          width: 300,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text('Hello world and a good deal more', style: TextStyle(fontSize: 16)),
          ),
        ),
      );
      expect(await checkTextScale(tester, c), isNull);
    });
    testWidgets('an empty widget passes intrinsic when it has no content', (tester) async {
      expect(await checkIntrinsic(tester, DisplayCase('g', SizedBox, (_) => const SizedBox.shrink(), hasContent: false)), isNull);
    });
  });

  group('hiding checks', () {
    HidingCase hiding({bool excludeFocus = true, bool ignorePointer = true, bool tickersOff = true}) => HidingCase(
      'fixture',
      () => SimpleHiding(
        (child, hidden) => Opacity(
          opacity: hidden ? 0 : 1,
          child: ExcludeFocus(
            excluding: hidden && excludeFocus,
            child: IgnorePointer(
              ignoring: hidden && ignorePointer,
              child: TickerMode(enabled: !(hidden && tickersOff), child: child),
            ),
          ),
        ),
      ),
    );

    testWidgets('hidden-focus fails when the hidden button can be focused', (tester) async {
      expect(await checkHiddenFocus(tester, hiding(excludeFocus: false)), contains('Tab focused'));
    });
    testWidgets('hidden-tap fails when the hidden button can be tapped', (tester) async {
      expect(await checkHiddenTap(tester, hiding(ignorePointer: false)), contains('tapping where'));
    });
    testWidgets('hidden-ticker fails when tickers keep running', (tester) async {
      expect(await checkHiddenTicker(tester, hiding(tickersOff: false)), contains('TickerMode'));
    });
    testWidgets('a subtree hidden properly passes all three', (tester) async {
      final c = hiding();
      expect(await checkHiddenFocus(tester, c), isNull);
      expect(await checkHiddenTap(tester, c), isNull);
      expect(await checkHiddenTicker(tester, c), isNull);
    });
  });

  group('overlay checks', () {
    final closeKey = const ValueKey('fixture-close'), dragKey = const ValueKey('fixture-drag');

    /// A dialog route. Each flag makes one way of closing ignore the contract.
    OverlayCase dialog({
      bool swallowsPopScope = false,
      bool forcesEsc = false,
      bool forcesClose = false,
      bool forcesDrag = false,
      bool forcesBarrier = false,
      bool pagePopsToo = false,
      bool ignoresEsc = false,
      bool leaksEscToShell = false,
    }) => OverlayCase(
      'fixture',
      closeButton: find.byKey(closeKey),
      dragTarget: find.byKey(dragKey),
      open: (context, options) => showDialog<void>(
        context: context,
        barrierDismissible: forcesBarrier || options.barrierDismissible,
        builder: (dialogContext) => CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () {
              if (ignoresEsc) return;
              if (leaksEscToShell) FrostShellNavigationScope.maybeOf(context)?.goBack();
              if (forcesEsc || pagePopsToo) Navigator.of(dialogContext).pop();
              if (pagePopsToo) Navigator.of(context).pop();
              if (!forcesEsc && !pagePopsToo) Navigator.of(dialogContext).maybePop();
            },
          },
          child: Focus(
            autofocus: true,
            child: Dialog(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  swallowsPopScope ? const SizedBox(width: 240, height: 60, child: Text(overlayMarker)) : options.content(height: 60),
                  IconButton(
                    key: closeKey,
                    onPressed: () => forcesClose ? Navigator.of(dialogContext).pop() : Navigator.of(dialogContext).maybePop(),
                    icon: const Icon(Icons.close),
                  ),
                  GestureDetector(
                    key: dragKey,
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragEnd: (_) {
                      if (forcesDrag) {
                        Navigator.of(dialogContext).pop();
                      } else if (options.barrierDismissible) {
                        Navigator.of(dialogContext).maybePop();
                      }
                    },
                    child: const SizedBox(width: 200, height: 60),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    testWidgets('popscope-esc fails when Escape closes it anyway', (tester) async {
      expect(await checkPopScopeEsc(tester, dialog(forcesEsc: true)), contains('Escape closed'));
    });
    testWidgets('popscope-esc fails when the PopScope is swallowed', (tester) async {
      expect(await checkPopScopeEsc(tester, dialog(swallowsPopScope: true)), contains('Escape closed'));
    });
    testWidgets('popscope-close fails when the close button forces a pop', (tester) async {
      expect(await checkPopScopeClose(tester, dialog(forcesClose: true)), contains('close button closed'));
    });
    testWidgets('popscope-drag fails when dragging forces a pop', (tester) async {
      expect(await checkPopScopeDrag(tester, dialog(forcesDrag: true)), contains('dragging closed'));
    });
    testWidgets('popscope-back fails when the PopScope is swallowed', (tester) async {
      expect(await checkPopScopeBack(tester, dialog(swallowsPopScope: true)), contains('system back closed'));
    });
    testWidgets('barrier fails when the barrier still dismisses', (tester) async {
      expect(await checkBarrier(tester, dialog(forcesBarrier: true)), contains('tapping the barrier'));
    });
    testWidgets('barrier fails when a drag still dismisses', (tester) async {
      expect(await checkBarrier(tester, dialog(forcesDrag: true)), contains('dragging the overlay'));
    });
    testWidgets('back-only-overlay fails for an overlay that is not a route', (tester) async {
      final c = OverlayCase(
        'entry',
        open: (context, options) async {
          final entry = OverlayEntry(
            builder: (_) => const Positioned(left: 20, top: 20, child: Material(child: Text(overlayMarker))),
          );
          Overlay.of(context).insert(entry);
          return null;
        },
      );
      expect(await checkBackOnlyOverlay(tester, c), contains('system back'));
    });
    testWidgets('esc-only-overlay fails when Escape closes the page too', (tester) async {
      expect(await checkEscOnlyOverlay(tester, dialog(pagePopsToo: true)), contains('page under'));
    });
    testWidgets('esc-only-overlay fails when Escape also reaches the shell', (tester) async {
      expect(await checkEscOnlyOverlay(tester, dialog(leaksEscToShell: true)), contains('asked the shell to go back'));
    });
    testWidgets('esc-only-overlay fails when Escape does nothing', (tester) async {
      expect(await checkEscOnlyOverlay(tester, dialog(ignoresEsc: true)), contains('did not close'));
    });
    testWidgets('a compliant dialog passes every overlay check', (tester) async {
      final c = dialog();
      final results = {
        'popscope-esc': await checkPopScopeEsc(tester, c),
        'popscope-close': await checkPopScopeClose(tester, c),
        'popscope-drag': await checkPopScopeDrag(tester, c),
        'popscope-back': await checkPopScopeBack(tester, c),
        'barrier': await checkBarrier(tester, c),
        'back-only-overlay': await checkBackOnlyOverlay(tester, c),
        'esc-only-overlay': await checkEscOnlyOverlay(tester, c),
      };
      expect({
        for (final e in results.entries)
          if (e.value != null) e.key: e.value,
      }, isEmpty);
    });
  });

  group('known failures', () {
    const listed = {'Known.row	semantics'};
    test('a failure with no row fails the test', () {
      expect(() => expectContract('Other.row', 'semantics', 'broken', listed: listed), throwsA(isA<TestFailure>()));
    });
    test('a failure with a row passes', () {
      expectContract('Known.row', 'semantics', 'broken', listed: listed);
    });
    test('a pass with a row fails the test and asks for the row to go', () {
      expect(() => expectContract('Known.row', 'semantics', null, listed: listed), throwsA(isA<TestFailure>()));
    });
    test('a pass with no row passes', () {
      expectContract('Other.row', 'semantics', null, listed: listed);
    });
  });
}

class _Throws extends StatelessWidget {
  const _Throws();
  @override
  Widget build(BuildContext context) {
    if (Directionality.of(context) == TextDirection.rtl) throw StateError('right-to-left is not supported');
    return const SizedBox(width: 20, height: 20);
  }
}

/// A box that fills 100 px when it can but answers 10 px when asked for its intrinsic width.
class _Lying extends LeafRenderObjectWidget {
  const _Lying();
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderLying();
}

class _RenderLying extends RenderBox {
  @override
  void performLayout() => size = constraints.constrain(const Size(100, 30));
  @override
  double computeMinIntrinsicWidth(double height) => 10;
  @override
  double computeMaxIntrinsicWidth(double height) => 10;
  @override
  double computeMinIntrinsicHeight(double width) => 30;
  @override
  double computeMaxIntrinsicHeight(double width) => 30;
}
