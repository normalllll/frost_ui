import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/media.dart';
import 'package:frost_ui/src/media/_video_bar.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

const _ink = Color(0xFF33CC66);
const _scrim = Color(0xFF112233);
const _white = Color(0xFFFFFFFF);
const _black = Color(0xFF000000);

/// Replaces the page's tokens with [override] applied, or leaves them as is.
Widget _tokens(bool override, Widget child) => Builder(
  builder: (context) {
    if (!override) return child;
    final theme = Theme.of(context);
    final tokens = FrostThemeTokens.of(context).copyWith(onMediaInk: _ink, onMediaScrim: _scrim);
    return Theme(
      data: theme.copyWith(
        extensions: [
          for (final item in theme.extensions.values)
            if (item is! FrostThemeTokens) item,
          tokens,
        ],
      ),
      child: child,
    );
  },
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 600);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(frostTestApp(child));
}

void main() {
  for (final override in [true, false]) {
    final ink = override ? _ink : _white;
    final scrim = override ? _scrim : _black;
    final name = override ? 'overridden' : 'default';

    testWidgets('on-media field text follows the $name media ink', (tester) async {
      late FrostThemeTokens inner;
      final controller = TextEditingController(text: 'Hello');
      addTearDown(controller.dispose);
      await _pump(
        tester,
        _tokens(
          override,
          FrostFieldScope(
            appearance: FrostFieldAppearance.onMedia,
            child: Builder(
              builder: (context) {
                inner = FrostThemeTokens.of(context);
                return FrostTextField(controller: controller, placeholder: 'Name');
              },
            ),
          ),
        ),
      );
      expect(inner.textPrimary, ink);
      expect(inner.textSecondary, ink.withValues(alpha: ink.a * .78));
      expect(inner.textQuaternary, ink.withValues(alpha: ink.a * .25));
      expect(tester.widget<EditableText>(find.byType(EditableText)).style.color, ink);
    });

    testWidgets('media button icon follows the $name media ink', (tester) async {
      await _pump(
        tester,
        _tokens(override, Center(child: FrostMediaButton.icon(icon: testIcons.close, label: 'Close', onPressed: () {}))),
      );
      expect(tester.widget<FrostIcon>(find.byType(FrostIcon)).color, ink);
    });

    testWidgets('video bar scrim follows the $name media scrim', (tester) async {
      await _pump(
        tester,
        _tokens(
          override,
          FrostMediaViewport(
            onZoomChanged: (_) {},
            overlay: FrostMediaChrome(
              autoHide: false,
              top: FrostMediaButton.icon(icon: testIcons.close, label: 'Close', onPressed: () {}),
              bottom: FrostMediaButton.icon(icon: testIcons.close, label: 'Back', onPressed: () {}),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      );
      final painters = tester
          .widgetList<CustomPaint>(find.descendant(of: find.byType(FrostMediaChrome), matching: find.byType(CustomPaint)))
          .map((paint) => paint.painter)
          .whereType<FrostVideoScrimPainter>()
          .toList();
      expect(painters, isNotEmpty);
      for (final painter in painters) {
        expect(painter.color.withValues(alpha: 1), scrim.withValues(alpha: 1));
      }
    });
  }

  testWidgets('a solid accent badge draws its ink in the action label colour', (tester) async {
    late FrostThemeTokens tokens;
    await _pump(
      tester,
      Builder(
        builder: (context) {
          tokens = FrostThemeTokens.of(context);
          return const Center(child: FrostBadge(label: 'Live', tone: FrostBadgeTone.accent, style: FrostBadgeStyle.solid));
        },
      ),
    );
    final text = tester.widget<RichText>(find.descendant(of: find.byType(FrostBadge), matching: find.byType(RichText)).first);
    expect(text.text.style?.color, tokens.onAction);
  });
}
