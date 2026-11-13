import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/social.dart';
import 'package:frost_ui/src/primitives/_click_feedback.dart';
import 'package:material_ui/material_ui.dart';

import 'media_frame_test.dart' show ControlledImage;
import 'support.dart';

const glyph = FrostIconData.glyph(IconData(0xe020));
void main() {
  for (final rtl in [false, true]) {
    for (final count in [1, 2, 3, 4]) {
      testWidgets('mosaic every cell clip has only exterior corners count=$count rtl=$rtl', (tester) async {
        await tester.pumpWidget(
          frostTestApp(
            Directionality(
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 320,
                  child: FrostMediaMosaic(images: List.generate(count, (_) => ControlledImage()), onPressed: (_) {}),
                ),
              ),
            ),
          ),
        );
        final frames = find.byType(FrostMediaFrame);
        for (var i = 0; i < count; i++) {
          final cell = find.ancestor(of: frames.at(i), matching: find.byType(FrostClickFeedbackVisual)).first;
          final shape = tester.widget<FrostClickFeedbackVisual>(cell).shape as RoundedSuperellipseBorder;
          final expected = BorderRadiusDirectional.only(
            topStart: i == 0 ? const Radius.circular(10) : Radius.zero,
            topEnd: (count == 1 ? i == 0 : i == 1) ? const Radius.circular(10) : Radius.zero,
            bottomStart: (count < 4 ? i == 0 : i == 2) ? const Radius.circular(10) : Radius.zero,
            bottomEnd: i == count - 1 ? const Radius.circular(10) : Radius.zero,
          ).resolve(rtl ? TextDirection.rtl : TextDirection.ltr);
          expect(shape.borderRadius, expected);
          final clip = tester.widget<ClipPath>(find.descendant(of: cell, matching: find.byType(ClipPath)).first);
          expect((clip.clipper as ShapeBorderClipper).shape, shape);
        }
      });
    }
  }
  test('Popover maxWidth rejects values below 160 and nonfinite', () {
    Widget trigger(BuildContext c, FocusNode f, VoidCallback t) => const SizedBox();
    for (final width in [159.0, double.infinity, double.nan]) {
      expect(() => FrostPopover(maxWidth: width, builder: trigger, contentBuilder: (_, _) => const Text('Body')), throwsAssertionError);
    }
  });
}
