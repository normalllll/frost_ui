import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/desktop.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_control.dart';
import 'package:frost_ui/src/controls/_close_control.dart';
import 'package:frost_ui/src/controls/_control_surfaces.dart';
import 'package:frost_ui/src/controls/_field_frame.dart';
import 'package:frost_ui/src/primitives/_click_feedback.dart';

import 'support.dart';

void main() {
  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    for (final direction in TextDirection.values) {
      testWidgets('embedded clear has its own full-height target $platform $direction', (tester) async {
        var bodies = 0, clears = 0;
        await tester.pumpWidget(
          frostTestApp(
            Directionality(
              textDirection: direction,
              child: Center(
                child: FrostFilterChip(label: 'Filter', value: 'Value', onPressed: () => bodies++, onClear: () => clears++),
              ),
            ),
            platform: platform,
          ),
        );
        await tester.pumpAndSettle();
        final close = find.byType(FrostCloseControl);
        final target = tester.getRect(close);
        final touch = platform == TargetPlatform.android;
        expect(target.size, Size(touch ? 44 : 24, touch ? 44 : 36));
        expect(target.height, tester.getSize(find.byType(FrostFilterChip)).height);
        final paint = find.descendant(of: close, matching: find.byType(FrostClickSurface));
        expect(tester.getSize(paint), const Size(20, 20));
        await tester.tapAt(target.topCenter + const Offset(0, 1));
        expect(clears, 1);
        expect(bodies, 0);
        final body = find.byType(FrostTagButton);
        await tester.tapAt(tester.getRect(body).topCenter + const Offset(0, 1));
        expect(clears, 1);
        expect(bodies, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
  test('platform columns are independent of density and keep four explicit sizes', () {
    for (final platform in TargetPlatform.values) {
      final pointer = [TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux].contains(platform);
      for (final density in FrostDensity.values) {
        final resolved = density.forPlatform(platform);
        expect([for (final size in FrostControlSize.values) resolved.heightFor(size)], pointer ? [30, 32, 36, 44] : [30, 36, 44, 52]);
        expect(resolved.targetHeight, pointer ? 36 : 44);
      }
    }
  });

  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    for (final size in FrostControlSize.values) {
      for (final scale in [1.0, 2.0, 3.0]) {
        testWidgets('field owners and rows preserve layout $platform $size scale=$scale', (tester) async {
          await tester.pumpWidget(
            frostTestApp(
              MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale), alwaysUse24HourFormat: true),
                child: SingleChildScrollView(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: 300,
                      child: FrostControlScope(
                        size: size,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FrostPathField(path: 'C:/media', label: 'Path', onChoose: () async {}),
                            FrostTimePicker(value: const TimeOfDay(hour: 12, minute: 30), onChanged: (_) {}, label: 'Time'),
                            FrostPicker<int>.menu(
                              value: 1,
                              options: const [FrostPickerOption(value: 1, label: 'Current')],
                              onChanged: (_) {},
                              label: 'Choice',
                            ),
                            const FrostListRow(title: '完整显示列表内容与文字', subtitle: FrostRowSubtitle('辅助文字也保持完整显示')),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              platform: platform,
            ),
          );
          await tester.pumpAndSettle();
          final target = platform == TargetPlatform.windows ? 36 : 44;
          for (final element in find.byType(FrostFieldFrame).evaluate()) {
            final box = element.renderObject! as RenderBox;
            expect(box.size.height, greaterThanOrEqualTo(target));
          }
          final trigger = find.byWidgetPredicate((w) => w is FrostFieldButton && !w.search);
          expect(tester.getSize(trigger).height, greaterThanOrEqualTo(target));
          for (final label in ['完整显示列表内容与文字', '辅助文字也保持完整显示']) {
            final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
            expect(paragraph.didExceedMaxLines, isFalse);
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    for (final density in FrostDensity.values) {
      for (final size in FrostControlSize.values) {
        for (final scale in [1.0, 2.0, 3.0]) {
          testWidgets('shared controls remain readable and interactive: $platform $density $size scale=$scale', (tester) async {
            final focus = FocusNode();
            addTearDown(focus.dispose);
            var actions = 0, tags = 0, selected = 0;
            const buttonKey = ValueKey('button'), fieldKey = ValueKey('field'), tagKey = ValueKey('tag'), pickerKey = ValueKey('picker');
            const actionLabel = '完整显示大字号按钮文字';
            const tagLabel = 'P1 完整显示大字号标签';
            await tester.pumpWidget(
              frostTestApp(
                MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: SingleChildScrollView(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: 300,
                        child: FrostControlScope(
                          size: size,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FrostButton(key: buttonKey, label: actionLabel, onPressed: () => actions++),
                              FrostTextField(key: fieldKey, focusNode: focus, placeholder: 'Input'),
                              FrostTag(key: tagKey, label: tagLabel, onPressed: () => tags++),
                              FrostPicker<int>.segmented(
                                key: pickerKey,
                                label: '排序',
                                size: size,
                                options: const [
                                  FrostPickerOption(value: 0, label: '热门推荐'),
                                  FrostPickerOption(value: 1, label: '最新投稿'),
                                ],
                                value: 0,
                                onChanged: (value) => selected = value,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                density: density,
                platform: platform,
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final target = platform == TargetPlatform.windows ? 36.0 : 44.0;
            for (final key in [buttonKey, fieldKey, tagKey, pickerKey]) {
              expect(tester.getSize(find.byKey(key)).height, greaterThanOrEqualTo(target));
            }
            for (final label in [actionLabel, tagLabel, '热门推荐', '最新投稿']) {
              expect(tester.renderObject<RenderParagraph>(find.text(label)).didExceedMaxLines, isFalse, reason: label);
            }
            await tester.ensureVisible(find.byKey(buttonKey));
            await tester.tapAt(tester.getRect(find.byKey(buttonKey)).topCenter + const Offset(0, 1));
            expect(actions, 1);
            await tester.ensureVisible(find.byKey(fieldKey));
            await tester.tapAt(tester.getRect(find.byKey(fieldKey)).topCenter + const Offset(0, 1));
            await tester.pumpAndSettle();
            expect(focus.hasFocus, isTrue);
            await tester.ensureVisible(find.byKey(tagKey));
            await tester.tapAt(tester.getRect(find.byKey(tagKey)).topCenter + const Offset(0, 1));
            expect(tags, 1);
            await tester.ensureVisible(find.byKey(pickerKey));
            final segment = find.ancestor(of: find.text('最新投稿'), matching: find.byType(FrostClickSurface)).first;
            await tester.tapAt(tester.getRect(segment).topCenter + const Offset(0, 1));
            expect(selected, 1);
            if (scale == 1) {
              final track = find.descendant(of: find.byKey(pickerKey), matching: find.byType(FrostControlTrack));
              final paint = find.descendant(of: track, matching: find.byType(AnimatedContainer)).first;
              expect(tester.getSize(paint).height, size.visualHeight(touch: platform == TargetPlatform.android));
              final feedback = find.descendant(of: find.byKey(pickerKey), matching: find.byType(FrostClickFeedbackVisual));
              for (final region in feedback.evaluate()) {
                expect((region.renderObject! as RenderBox).size.height, size.visualHeight(touch: platform == TargetPlatform.android) - 8);
              }
            }
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  }
}
