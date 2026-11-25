import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

const _family = 'Kerned clock';

/// A TrueType font with blank glyphs for the clock's characters and a legacy
/// kern table that pulls every digit and colon pair together, so the shaped
/// phrase is narrower than its characters laid out one by one. Digits are
/// tabular (one advance); the colon, space and slash have their own.
ByteData _kernedFont() {
  const characters = ' /0123456789:';
  const advances = [300, 400, 600, 600, 600, 600, 600, 600, 600, 600, 600, 600, 300];
  const glyphs = characters.length + 1; // .notdef first
  int glyph(String character) => characters.indexOf(character) + 1;

  Uint8List table(void Function(ByteData data) write, int length) {
    final bytes = Uint8List(length);
    write(ByteData.sublistView(bytes));
    return bytes;
  }

  final head = table((d) {
    d.setUint32(0, 0x00010000);
    d.setUint32(4, 0x00010000);
    d.setUint32(12, 0x5F0F3CF5);
    d.setUint16(16, 0x000B);
    d.setUint16(18, 1000); // units per em
    d.setInt16(40, 600);
    d.setInt16(42, 700);
    d.setUint16(46, 8);
    d.setInt16(48, 2);
  }, 54);
  final hhea = table((d) {
    d.setUint32(0, 0x00010000);
    d.setInt16(4, 800);
    d.setInt16(6, -200);
    d.setUint16(10, 600);
    d.setInt16(16, 600);
    d.setInt16(18, 1);
    d.setUint16(34, glyphs);
  }, 36);
  final maxp = table((d) {
    d.setUint32(0, 0x00010000);
    d.setUint16(4, glyphs);
    d.setUint16(14, 2);
  }, 32);
  final os2 = table((d) {
    d.setUint16(2, 600);
    d.setUint16(4, 400);
    d.setUint16(6, 5);
    d.setUint16(62, 0x40);
    d.setUint16(64, 0x20);
    d.setUint16(66, 0x3A);
    d.setInt16(68, 800);
    d.setInt16(70, -200);
    d.setUint16(74, 800);
    d.setUint16(76, 200);
  }, 78);
  final hmtx = table((d) {
    d.setUint16(0, 600);
    for (var i = 0; i < advances.length; i++) {
      d.setUint16((i + 1) * 4, advances[i]);
    }
  }, glyphs * 4);
  // Format 4: space alone, then '/' through ':' in glyph order, then the end segment.
  final cmap = table((d) {
    d.setUint16(2, 1);
    d.setUint16(4, 3);
    d.setUint16(6, 1);
    d.setUint32(8, 12);
    const segments = [(0x20, 0x20), (0x2F, 0x3A), (0xFFFF, 0xFFFF)];
    final deltas = [glyph(' ') - 0x20, glyph('/') - 0x2F, 1];
    d.setUint16(12, 4);
    d.setUint16(14, 40);
    d.setUint16(18, 6);
    d.setUint16(20, 4);
    d.setUint16(22, 1);
    d.setUint16(24, 2);
    for (var i = 0; i < 3; i++) {
      d.setUint16(26 + i * 2, segments[i].$2);
      d.setUint16(34 + i * 2, segments[i].$1);
      d.setInt16(40 + i * 2, deltas[i]);
    }
  }, 52);
  final loca = Uint8List((glyphs + 1) * 2);
  final glyf = Uint8List(4);
  final post = table((d) {
    d.setUint32(0, 0x00030000);
    d.setInt16(8, -100);
    d.setInt16(10, 50);
  }, 32);
  final name = table((d) => d.setUint16(4, 6), 6);
  final pairs = <(int, int)>[
    for (final digit in '0123456789'.split('')) ...[(glyph(digit), glyph(':')), (glyph(':'), glyph(digit))],
  ]..sort((a, b) => (a.$1 << 16 | a.$2).compareTo(b.$1 << 16 | b.$2));
  final kern = table((d) {
    d.setUint16(2, 1);
    d.setUint16(6, 14 + pairs.length * 6);
    d.setUint16(8, 0x0001); // horizontal kerning, format 0
    d.setUint16(10, pairs.length);
    d.setUint16(12, 6 * 16);
    d.setUint16(14, 4);
    d.setUint16(16, (pairs.length - 16) * 6);
    for (var i = 0; i < pairs.length; i++) {
      d.setUint16(18 + i * 6, pairs[i].$1);
      d.setUint16(20 + i * 6, pairs[i].$2);
      d.setInt16(22 + i * 6, -90);
    }
  }, 18 + pairs.length * 6);

  final tables = {
    'OS/2': os2,
    'cmap': cmap,
    'glyf': glyf,
    'head': head,
    'hhea': hhea,
    'hmtx': hmtx,
    'kern': kern,
    'loca': loca,
    'maxp': maxp,
    'name': name,
    'post': post,
  };
  final directory = 12 + tables.length * 16;
  var length = directory;
  for (final bytes in tables.values) {
    length += (bytes.length + 3) & ~3;
  }
  final font = ByteData(length);
  font.setUint32(0, 0x00010000);
  font.setUint16(4, tables.length);
  font.setUint16(6, 128);
  font.setUint16(8, 3);
  font.setUint16(10, tables.length * 16 - 128);
  var offset = directory, record = 12;
  for (final MapEntry(key: tag, value: bytes) in tables.entries) {
    for (var i = 0; i < 4; i++) {
      font.setUint8(record + i, tag.codeUnitAt(i));
    }
    font.setUint32(record + 8, offset);
    font.setUint32(record + 12, bytes.length);
    font.buffer.asUint8List().setRange(offset, offset + bytes.length, bytes);
    offset += (bytes.length + 3) & ~3;
    record += 16;
  }
  return font;
}

Widget _frame(Duration position, double scale) {
  final config = testConfig.copyWith(fonts: const FrostFonts(japanese: 'JP', simplifiedChinese: 'SC', defaultScript: FrostContentScript.japanese, numeric: _family));
  return FrostScope(
    config: config,
    child: MaterialApp(
      theme: FrostTheme.build(config: config, brightness: Brightness.light, platform: TargetPlatform.macOS, locale: const Locale('en')),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: Center(
            child: SizedBox(
              width: 800,
              height: 450,
              child: FrostVideoFrame(
                video: const ColoredBox(color: Color(0xFF000000)),
                state: FrostVideoState(playing: false, position: position, duration: const Duration(seconds: 7)),
                onPlayPause: () {},
                onSeek: (_) {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    await (FontLoader(_family)..addFont(Future.value(_kernedFont()))).load();
  });

  test('the test font shapes the clock narrower than its characters one by one', () {
    const style = TextStyle(fontFamily: _family, fontSize: 20);
    double width(String text) {
      final painter = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    const phrase = '00:07 / 00:07';
    final apart = phrase.split('').fold(0.0, (sum, character) => sum + width(character));
    expect(width(phrase), lessThan(apart - 1));
  });

  for (final scale in [1.0, 1.3]) {
    testWidgets('the clock fits its reserved slot as the seconds change, text scale $scale', (tester) async {
      double? slot;
      for (var second = 0; second <= 7; second++) {
        await tester.pumpWidget(_frame(Duration(seconds: second), scale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'no overflow at 00:0$second');
        final clock = find.byType(FrostRollingText);
        final reserve = tester.getSize(find.ancestor(of: clock, matching: find.byType(SizedBox)).first).width;
        expect(tester.getSize(clock).width, lessThanOrEqualTo(reserve), reason: '00:0$second / 00:07');
        expect(reserve, slot ?? reserve, reason: 'the slot keeps one width');
        slot = reserve;
      }
    });
  }
}
