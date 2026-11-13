import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_control.dart';
import 'package:frost_ui/src/display/_avatar_seed.dart';
import 'package:frost_ui/src/foundation/color_math.dart' show colorContrast;
import 'package:frost_ui/src/overlays/_menu_item.dart';
import 'package:frost_ui/src/primitives/_icon_slot.dart';
import 'package:material_ui/material_ui.dart';

import 'display_badges_test.dart' show display;
import 'support.dart';

// A leading widget fills exactly the slot an icon of the control would use, so
// the optional avatar of a picker option changes nothing about the layout.

const _icon = FrostIconData.glyph(Icons.person);
FrostGlyph _avatar(String name, {String? seed}) =>
    FrostGlyph.avatar(FrostAvatar.person(name: name, colorKey: seed ?? 'GitHub $name', size: FrostAvatarSize.small, semanticLabel: 'GitHub @$name'));

FrostPicker<int> _picker(List<FrostPickerOption<int>> options, {int value = 0}) =>
    FrostPicker<int>.menu(options: options, value: value, onChanged: (_) {}, label: 'Account');

Finder _trigger() => find.byType(FrostFieldButton).hitTestable();

/// The left edge of [label] relative to the left edge of [of].
double _textStart(WidgetTester tester, String label, Finder of) =>
    tester.getTopLeft(find.descendant(of: of, matching: find.text(label)).first).dx - tester.getTopLeft(of).dx;

void main() {
  testWidgets('the trigger button has the size, height and text edge of the same option with an icon', (tester) async {
    await display(tester, _picker(const [FrostPickerOption(value: 0, label: 'zhang', leading: FrostGlyph.icon(_icon))]));
    final withIcon = (tester.getSize(_trigger()), _textStart(tester, 'zhang', _trigger()));
    await display(tester, _picker([FrostPickerOption(value: 0, label: 'zhang', leading: _avatar('zhang'))]));
    final withAvatar = (tester.getSize(_trigger()), _textStart(tester, 'zhang', _trigger()));
    expect(withAvatar, withIcon);
    // The avatar is drawn at the icon size of the control (regular: 18), not the 24 of FrostAvatarSize.small.
    expect(tester.getSize(find.descendant(of: _trigger(), matching: find.byType(FrostIconSlot))), Size.square(FrostControlSize.regular.iconSize));
    final drawn = tester.getRect(find.descendant(of: _trigger(), matching: find.byType(FrostAvatar)));
    expect(drawn.width, closeTo(FrostControlSize.regular.iconSize, .01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('each control size gives the avatar that size\'s icon slot', (tester) async {
    for (final size in [FrostControlSize.small, FrostControlSize.compact, FrostControlSize.regular, FrostControlSize.large]) {
      final icon = FrostPicker<int>.menu(
        options: const [FrostPickerOption(value: 0, label: 'zhang', leading: FrostGlyph.icon(_icon))],
        value: 0,
        onChanged: (_) {},
        label: 'Account',
        size: size,
      );
      final avatar = FrostPicker<int>.menu(
        options: [FrostPickerOption(value: 0, label: 'zhang', leading: _avatar('zhang'))],
        value: 0,
        onChanged: (_) {},
        label: 'Account',
        size: size,
      );
      await display(tester, icon);
      final expected = (tester.getSize(_trigger()), _textStart(tester, 'zhang', _trigger()));
      await display(tester, avatar);
      expect((tester.getSize(_trigger()), _textStart(tester, 'zhang', _trigger())), expected, reason: '$size');
      expect(
        tester.getSize(find.descendant(of: _trigger(), matching: find.byType(FrostIconSlot))),
        Size.square(size.iconSize),
        reason: '$size',
      );
    }
  });

  // Wide windows open an anchored menu (rows are TextButtons); narrow ones the
  // compact sheet (rows are FrostListRows). Both put the option in the icon slot.
  for (final (name, width, row) in [('anchored menu', 800.0, FrostMenuItem), ('compact sheet', 300.0, FrostListRow)]) {
    testWidgets('$name: rows keep their height and text edge, and mixed icon / avatar / plain rows stay aligned', (tester) async {
      List<FrostPickerOption<int>> build(FrostGlyph? Function(int) leading) => [
        for (var i = 0; i < 3; i++) FrostPickerOption(value: i, label: 'Option $i', leading: leading(i)),
      ];
      Future<List<(double, double, double)>> rows(List<FrostPickerOption<int>> items) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 700);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(frostTestApp(Center(child: SizedBox(width: 240, child: _picker(items, value: 2)))));
        await tester.tap(_trigger());
        await tester.pumpAndSettle();
        Finder rowOf(int i) => find.ancestor(of: find.text('Option $i'), matching: find.byType(row)).first;
        final result = [
          for (var i = 0; i < 3; i++)
            (
              tester.getSize(rowOf(i)).height,
              tester.getTopLeft(find.descendant(of: rowOf(i), matching: find.text('Option $i'))).dx,
              tester.getSize(rowOf(i)).width,
            ),
        ];
        await tester.tapAt(const Offset(2, 2));
        await tester.pumpAndSettle();
        return result;
      }

      final icons = await rows(build((_) => const FrostGlyph.icon(_icon)));
      final avatars = await rows(build((i) => _avatar('user$i')));
      final mixed = await rows(build((i) => i == 1 ? _avatar('user$i') : const FrostGlyph.icon(_icon)));
      expect(avatars, icons);
      expect(mixed, icons);
      expect({for (final r in mixed) r.$2}.length, 1, reason: 'one text edge for every row');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a leading widget is excluded from semantics: the option label is read, the avatar label is not', (tester) async {
    final handle = tester.ensureSemantics();
    await display(tester, _picker([FrostPickerOption(value: 0, label: 'zhang', leading: _avatar('zhang'))]));
    expect(find.bySemanticsLabel(RegExp('zhang')), findsWidgets);
    expect(find.bySemanticsLabel('GitHub @zhang'), findsNothing);
    handle.dispose();
  });

  testWidgets('options without the new parameters build no slot and render as before', (tester) async {
    await display(
      tester,
      _picker(const [FrostPickerOption(value: 0, label: 'plain'), FrostPickerOption(value: 1, label: 'iconic', leading: FrostGlyph.icon(_icon))], value: 1),
    );
    expect(find.byType(FrostIconSlot), findsNothing);
    await tester.tap(_trigger());
    await tester.pumpAndSettle();
    expect(find.byType(FrostIconSlot), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('FrostAvatar.person', () {
    test('the initial is the first letter, upper-cased, or the first CJK character', () {
      expect(frostPersonInitial('zhang'), 'Z');
      expect(frostPersonInitial('张三'), '张');
      expect(frostPersonInitial('42-bob'), 'B');
      expect(frostPersonInitial('---'), isNull);
      expect(frostPersonInitial(''), isNull);
    });

    // Independent FNV-1a over UTF-8 bytes (the documented hash), not the library function.
    int fnv(String text) {
      var hash = 0x811c9dc5;
      for (final byte in utf8.encode(text)) {
        hash = ((hash ^ byte) * 0x01000193) & 0xFFFFFFFF;
      }
      return hash;
    }

    final names = [
      'GitHub zhang',
      'GitLab work-li',
      'Codeberg zs-codeberg',
      'GitHub 张三',
      'GitHub octocat',
      'GitLab maintainer',
      'GitHub alice',
      'GitHub bob',
      'Codeberg carol',
      'GitLab dave',
    ];
    final palette = FrostPalettes.pink.lightNeutral.categorical;

    test('the colour is a stable function of the seed', () {
      for (final name in names) {
        expect(frostSeedIndex(name, palette.length), fnv(name) % palette.length, reason: name);
        expect(frostAvatarSeedFill(name, palette), palette[fnv(name) % palette.length]);
      }
      // The documented known answer for the empty string: the FNV offset basis.
      expect(fnv(''), 0x811c9dc5);
      expect(frostSeedIndex('', 8), 0x811c9dc5 % 8);
    });

    test('ten sample accounts are not concentrated on one or two colours', () {
      final used = {for (final name in names) frostSeedIndex(name, palette.length)};
      expect(used.length, greaterThanOrEqualTo(5), reason: '$used');
    });

    test('the initials reach 4.5:1 on every categorical colour of both palettes', () {
      for (final tokens in [FrostPalettes.pink.lightNeutral, FrostPalettes.pink.darkNeutral]) {
        for (final fill in tokens.categorical) {
          expect(colorContrast(fill, frostAvatarSeedInk(fill)), greaterThanOrEqualTo(4.5), reason: '$fill');
        }
      }
    });

    testWidgets('the same seed gives the same fill and ink in light and dark, with the same size', (tester) async {
      Color fillOf() => tester.widget<ColoredBox>(find.descendant(of: find.byType(FrostAvatar), matching: find.byType(ColoredBox)).last).color;
      await display(tester, const FrostAvatar.person(name: 'z', colorKey: 'GitHub zhang'));
      final light = (fillOf(), tester.getSize(find.byType(FrostAvatar)));
      await display(
        tester,
        const FrostAvatar.person(name: 'z', colorKey: 'GitHub zhang'),
        brightness: Brightness.dark,
      );
      final dark = (fillOf(), tester.getSize(find.byType(FrostAvatar)));
      await display(tester, const FrostAvatar(initials: 'z', semanticLabel: 'z'));
      final plain = tester.getSize(find.byType(FrostAvatar));
      expect(dark, light);
      expect(light.$1, frostAvatarSeedFill('GitHub zhang', FrostPalettes.pink.lightNeutral.categorical));
      expect(light.$2, plain);
    });

    testWidgets('without a seed the placeholder is the neutral fill with tertiary initials, as before', (tester) async {
      await display(tester, const FrostAvatar(initials: 'zh', semanticLabel: 'zhang'));
      final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostAvatar)));
      final fill = tester.widgetList<ColoredBox>(find.descendant(of: find.byType(FrostAvatar), matching: find.byType(ColoredBox))).map((box) => box.color);
      expect(fill, contains(tokens.fill));
      final style = tester.widget<RichText>(find.descendant(of: find.byType(FrostAvatar), matching: find.byType(RichText)).first).text.style;
      expect(style?.color, tokens.textTertiary);
    });

    testWidgets('a failing or loading image shows the seeded placeholder', (tester) async {
      await display(tester, const FrostAvatar.person(name: 'zhang', colorKey: 'GitHub zhang', image: NetworkImage('http://localhost:0/missing.png')));
      final seeded = frostAvatarSeedFill('GitHub zhang', FrostPalettes.pink.lightNeutral.categorical);
      expect(find.descendant(of: find.byType(FrostAvatar), matching: find.byWidgetPredicate((w) => w is ColoredBox && w.color == seeded)), findsWidgets);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.descendant(of: find.byType(FrostAvatar), matching: find.byWidgetPredicate((w) => w is ColoredBox && w.color == seeded)), findsWidgets);
      tester.takeException();
    });

    testWidgets('initials stay inside the avatar at the icon-slot scale', (tester) async {
      await display(
        tester,
        FrostPicker<int>.menu(
          options: [FrostPickerOption(value: 0, label: 'zhang', leading: _avatar('zhang'))],
          value: 0,
          onChanged: (_) {},
          label: 'Account',
          size: FrostControlSize.compact,
        ),
      );
      final slot = tester.getRect(find.descendant(of: _trigger(), matching: find.byType(FrostIconSlot)));
      final letter = tester.getRect(find.descendant(of: find.byType(FrostAvatar), matching: find.text('Z')));
      expect(slot.contains(letter.topLeft) && slot.contains(letter.bottomRight), true, reason: 'slot $slot letter $letter');
      expect(tester.takeException(), isNull);
    });
  });
}
