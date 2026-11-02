import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/navigation/window_caption.dart' show FrostCaptionButtons;

import 'support.dart';
import 'window_caption_test.dart' show FakeWindow;

const _iconKey = ValueKey('brand-icon');
const _nameKey = ValueKey('brand-name');

// An ordinary brand: a fixed icon and an unwrapped name, no OverflowBox.
const _rigidBrand = Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    SizedBox(key: _iconKey, width: 24, height: 24),
    SizedBox(width: 8),
    Text('BooruFlow', key: _nameKey),
  ],
);

void main() {
  Widget shell(Widget brand, Widget? title) => frostTestApp(
    FrostWindowCaptionScope(
      window: FakeWindow(),
      child: FrostShell(
        destinations: const [FrostNavDestination(icon: FrostIconData.glyph(Icons.home), label: 'Home')],
        selectedIndex: 0,
        atDestinationRoot: true,
        onDestinationSelected: (_) {},
        canGoBack: false,
        onBack: () {},
        showsMobileNavigation: true,
        brand: FrostShellBrand(expanded: brand),
        titleBarContent: title,
        child: const SizedBox.expand(),
      ),
    ),
  );

  for (final title in ['none', 'text']) {
    testWidgets('a rigid brand Row never overflows as its caption room shrinks (title: $title)', (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final overflows = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (details) => overflows.add(
        '${details.exceptionAsString().split('\n').first} at ${tester.view.physicalSize.width}: '
        '${details.toString().split('\n').where((line) => line.contains('dart:') || line.contains('Row')).take(4).join(' / ')}',
      );
      addTearDown(() => FlutterError.onError = previous);
      // Down to the narrowest window that still fits Back and the caption buttons.
      for (var width = 640.0; width >= 210; width -= 7.3) {
        tester.view.physicalSize = Size(width, 600);
        await tester.pumpWidget(shell(_rigidBrand, title == 'text' ? const Text('A page title that takes caption room') : null));
        final name = find.byKey(_nameKey);
        if (name.evaluate().isNotEmpty) {
          // The name keeps its natural width; a narrow slot clips it instead.
          expect(tester.getSize(name).width, greaterThan(40), reason: 'width $width');
        }
      }
      FlutterError.onError = previous;
      expect(overflows, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a brand with a flexible name still ellipsizes in a short slot', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 600);
    addTearDown(tester.view.reset);
    const brand = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(key: _iconKey, width: 20, height: 20),
        SizedBox(width: 8),
        Flexible(
          child: Text('A very long application brand name', key: _nameKey, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
    await tester.pumpWidget(shell(brand, null));
    final buttons = tester.getRect(find.byType(FrostCaptionButtons));
    final name = tester.getRect(find.byKey(_nameKey));
    expect(name.right, lessThanOrEqualTo(buttons.left), reason: 'the name fits its slot rather than being cut');
    expect(tester.renderObject<RenderParagraph>(find.descendant(of: find.byKey(_nameKey), matching: find.byType(RichText))).didExceedMaxLines, isTrue);
    expect(tester.takeException(), isNull);
  });
}
