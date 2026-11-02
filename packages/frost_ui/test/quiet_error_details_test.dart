import 'dart:ui' show Tristate;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

TextStyle _style(WidgetTester tester, String text) => tester.renderObject<RenderParagraph>(find.text(text)).text.style!;

void main() {
  testWidgets('quiet error details toggle is secondary footnote text, lower than the heading toggle', (tester) async {
    late FrostThemeTokens tokens;
    late String label;
    Future<double> pump(Widget details) async {
      await tester.pumpWidget(
        frostTestApp(
          Builder(
            builder: (context) {
              tokens = FrostThemeTokens.of(context);
              label = FrostScope.labelsOf(context).errorDetails;
              return Align(
                alignment: Alignment.topLeft,
                child: SizedBox(width: 400, child: details),
              );
            },
          ),
        ),
      );
      return tester.getSize(find.byType(FrostClickSurface).first).height;
    }

    final loudHeight = await pump(const FrostErrorDetails(details: 'trace'));
    final loud = _style(tester, label);
    final quietHeight = await pump(const FrostErrorDetails.quiet(details: 'trace'));
    final quiet = _style(tester, label);
    expect(quiet.color, tokens.textSecondary);
    expect(quiet.fontSize, lessThan(loud.fontSize!));
    expect(quiet.fontWeight!.value, lessThan(loud.fontWeight!.value));
    expect(quietHeight, lessThan(loudHeight));
  });

  testWidgets('quiet error details expand, announce state and keep the copyable block', (tester) async {
    late String label;
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) {
            label = FrostScope.labelsOf(context).errorDetails;
            return const Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 400, child: FrostErrorDetails.quiet(details: 'stack trace')),
            );
          },
        ),
      ),
    );
    final handle = tester.ensureSemantics();
    expect(tester.getSemantics(find.bySemanticsLabel(label)).flagsCollection.isExpanded, Tristate.isFalse);
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    expect(find.byType(FrostCodeBlock), findsOneWidget);
    expect(tester.widget<FrostCodeBlock>(find.byType(FrostCodeBlock)).text, 'stack trace');
    expect(find.byType(FrostCodeBlock).hitTestable(), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel(label)).flagsCollection.isExpanded, Tristate.isTrue);
    handle.dispose();
  });
}
