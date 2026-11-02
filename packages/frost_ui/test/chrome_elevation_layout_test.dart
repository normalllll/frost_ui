import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/desktop.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/display/stat.dart' show FrostStatStrip;
import 'package:frost_ui/src/overlays/_modal_frame.dart';
import 'package:frost_ui/src/primitives/_page_outline.dart';

import 'support.dart';

void main() {
  testWidgets('dark module stays above an alpha-composited surface parent', (tester) async {
    late Color page, group;
    await tester.pumpWidget(
      frostTestApp(
        FrostSurface(
          role: FrostSurfaceRole.panel,
          child: Builder(
            builder: (context) {
              page = FrostSurfaceScope.maybeOf(context)!.background;
              return FrostSurface(
                role: FrostSurfaceRole.module,
                child: Builder(
                  builder: (context) {
                    group = FrostSurfaceScope.maybeOf(context)!.background;
                    return const SizedBox(width: 300, height: 100);
                  },
                ),
              );
            },
          ),
        ),
        brightness: Brightness.dark,
      ),
    );
    expect(group.computeLuminance(), greaterThan(page.computeLuminance() + .001));
    expect(tester.takeException(), isNull);
  });
  for (final brightness in Brightness.values) {
    testWidgets('touch page and grouped card keep their elevation in both navigation modes $brightness', (tester) async {
      for (final sidebar in [false, true]) {
        late Color page, group;
        await tester.pumpWidget(
          frostTestApp(
            Builder(
              builder: (context) {
                final content = Builder(
                  builder: (context) {
                    page = FrostSurfaceScope.maybeOf(context)!.background;
                    return FrostSurface(
                      role: FrostSurfaceRole.module,
                      child: Builder(
                        builder: (context) {
                          group = FrostSurfaceScope.maybeOf(context)!.background;
                          return const SizedBox(width: 300, height: 100);
                        },
                      ),
                    );
                  },
                );
                return sidebar
                    ? FrostPageOutline(
                        radius: BorderRadius.circular(12),
                        scrollbarChannel: 8,
                        child: FrostSurface(role: FrostSurfaceRole.panel, child: content),
                      )
                    : FrostSurfaceScope(isGlass: false, background: FrostThemeTokens.of(context).canvas, child: content);
              },
            ),
            brightness: brightness,
            platform: TargetPlatform.android,
          ),
        );
        expect(group.computeLuminance(), greaterThan(page.computeLuminance()));
        expect(tester.takeException(), isNull);
      }
    });
  }
  testWidgets('pointer tab overview is capped and centered, with live tab actions', (tester) async {
    final tabs = FrostTabsController<String>(initial: 'Home')..open('Messages', activate: false);
    final presentation = FrostShellTabs<String>(
      controller: tabs,
      label: (_, value) => FrostTabLabel(title: value),
      countLabel: (count) => '$count tabs',
      closeTooltip: 'Close tab',
      newTabTooltip: 'New tab',
      onNewTab: () {},
    );
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) => Center(
            child: TextButton(onPressed: () => presentation.showOverview(context), child: const Text('Overview')),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();
    final panel = tester.getRect(find.byType(FrostModalFrame));
    expect(panel.width, lessThanOrEqualTo(720));
    expect(panel.center.dx, closeTo(tester.view.physicalSize.width / tester.view.devicePixelRatio / 2, .01));
    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();
    expect(tabs.active, 'Messages');
    expect(find.byType(FrostModalFrame), findsNothing);
    await tester.pumpWidget(const SizedBox());
    tabs.dispose();
  });

  for (final scale in [.5, 1.0, 1.5]) {
    for (final direction in TextDirection.values) {
      testWidgets('group separator follows text under scale $scale / $direction', (tester) async {
        await tester.pumpWidget(
          frostTestApp(
            Directionality(
              textDirection: direction,
              child: Center(
                child: Transform.scale(
                  scale: scale,
                  child: const SizedBox(
                    width: 400,
                    child: FrostGroupedSection(
                      children: [
                        FrostListRow(
                          leading: FrostLeading.custom(FrostAvatar(initials: 'A', semanticLabel: 'Avatar')),
                          title: 'First',
                          subtitle: FrostRowSubtitle('Subtitle'),
                        ),
                        FrostListRow(title: 'Second'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final line = tester.renderObject<RenderBox>(
          find.descendant(of: find.byType(FrostDivider), matching: find.byWidgetPredicate((w) => w is LeafRenderObjectWidget)),
        );
        final text = tester.renderObject<RenderBox>(find.text('First'));
        final textEdge = line.globalToLocal(text.localToGlobal(direction == TextDirection.ltr ? Offset.zero : Offset(text.size.width, 0))).dx;
        expect(
          line,
          paints..line(
            p1: Offset(direction == TextDirection.ltr ? textEdge : 0, .5 / tester.view.devicePixelRatio),
            p2: Offset(direction == TextDirection.ltr ? 400 : textEdge, .5 / tester.view.devicePixelRatio),
            strokeWidth: 0,
          ),
        );
      });
    }
  }

  testWidgets('secondary header uses toolbar typography while primary remains large', (tester) async {
    for (final secondary in [false, true]) {
      await tester.pumpWidget(frostTestApp(FrostPageHeader(title: const FrostText('Page'), onBack: secondary ? () {} : null)));
      final paragraph = tester.renderObject<RenderParagraph>(find.text('Page'));
      final type = FrostTypography.of(tester.element(find.text('Page')));
      expect(paragraph.text.style!.fontSize, type.style(secondary ? FrostTextRole.headline : FrostTextRole.title1).fontSize);
    }
  });

  testWidgets('loose centered stats shrink to their natural packed width', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        const SizedBox(
          width: 400,
          child: Align(
            child: FrostStatStrip(
              stats: [
                FrostStat(value: '123', caption: 'Followers'),
                FrostStat(value: '45', caption: 'Following'),
              ],
            ),
          ),
        ),
      ),
    );
    final first = tester.getRect(find.text('Followers'));
    final last = tester.getRect(find.text('Following'));
    final strip = tester.getRect(find.byType(FrostStatStrip));
    expect(strip.width, lessThan(400));
    expect((first.left + last.right) / 2, closeTo(strip.center.dx, 8));
    expect(tester.takeException(), isNull);
  });
}
