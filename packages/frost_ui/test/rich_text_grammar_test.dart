import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/src/display/_rich_text_parser.dart';

List<FrostRichNode> parse(String source) => FrostRichDocument(source).nodes;
String joined(String source) => parse(source).map((n) => n.text).join();
List<FrostRichNode> targets(String source, FrostRichTarget kind) => parse(source).where((n) => n.target == kind).toList();

void main() {
  group('plain text stays plain', () {
    test('a bracketed note before a link does not swallow the link label', () {
      final nodes = parse('[1] see [docs](https://example.test/d)');
      expect(nodes.map((n) => (n.text, n.target, n.value)), [('[1] see ', null, null), ('docs', FrostRichTarget.link, 'https://example.test/d')]);
    });

    test('stars with spaces on both sides are arithmetic, not emphasis', () {
      final nodes = parse('2 * 3 = 6, 4 * 5');
      expect(nodes.map((n) => (n.text, n.italic, n.bold)), [('2 * 3 = 6, 4 * 5', false, false)]);
    });

    test('a mention or hashtag may follow punctuation, not only whitespace', () {
      expect(targets('转发：@张三', FrostRichTarget.mention).single.value, '张三');
      expect(targets('(@bob)', FrostRichTarget.mention).single.value, 'bob');
      expect(parse('(@bob)').map((n) => n.text), ['(', '@bob', ')']);
      expect(targets('see,#tag.', FrostRichTarget.hashtag).single.value, 'tag');
      expect(targets('**@bob**', FrostRichTarget.mention).single.bold, isTrue);
    });

    test('a symbol glued to a word or to another symbol is not a target', () {
      for (final raw in ['mail me at a@b.test', 'a#tag', 'ab_@x', '𝐀@bob', '@@bob', '&#39;', 'x@']) {
        expect(parse(raw).every((n) => n.target == null), isTrue, reason: raw);
        expect(joined(raw), raw);
      }
    });
  });

  group('emphasis', () {
    test('nests bold and italic in both directions', () {
      final nodes = parse('**a *b* c** and *x **y** z*');
      expect(nodes.map((n) => (n.text, n.bold, n.italic)), [
        ('a ', true, false),
        ('b', true, true),
        (' c', true, false),
        (' and ', false, false),
        ('x ', false, true),
        ('y', true, true),
        (' z', false, true),
      ]);
    });

    test('a triple star closes the inner italic and then the outer bold', () {
      final nodes = parse('**bold *both***!');
      expect(nodes.map((n) => (n.text, n.bold, n.italic)), [('bold ', true, false), ('both', true, true), ('!', false, false)]);
      final opening = parse('***x*** y');
      expect(opening.first.text, 'x');
      expect(opening.first.bold && opening.first.italic, isTrue);
    });

    test('adjacent emphasis closes one marker and opens the next', () {
      final nodes = parse('**a***b*');
      expect(nodes.map((n) => (n.text, n.bold, n.italic)), [('a', true, false), ('b', false, true)]);
      expect(parse('*a**b**').map((n) => n.text).join(), 'ab*');
    });

    test('unclosed markers stay as literal stars', () {
      for (final raw in ['unclosed **bold', 'unclosed *italic', '***x', 'x**', '**a *b**', '* item', 'a * b', '*', '**', '*** ***']) {
        final stars = '*'.allMatches(raw).length;
        final kept = '*'.allMatches(joined(raw)).length;
        expect(kept, lessThanOrEqualTo(stars), reason: raw);
      }
      expect(parse('unclosed **bold').single.text, 'unclosed **bold');
      expect(parse('x**').single.text, 'x**');
      expect(parse('* item').single.text, '* item');
      expect(parse('a **b *c').map((n) => (n.text, n.bold, n.italic)), [('a **b *c', false, false)]);
    });

    test('an opener without a closer does not change the text around a later pair', () {
      final nodes = parse('*a **b** c');
      expect(nodes.map((n) => (n.text, n.bold, n.italic)), [('*a ', false, false), ('b', true, false), (' c', false, false)]);
    });

    test('empty emphasis is kept as literal stars', () {
      expect(parse('****').single.text, '****');
      expect(parse('a****b').single.text, 'a****b');
    });

    test('emphasis styles code, links and targets inside it', () {
      final nodes = parse('**`c` [l](https://e.test) @m #h https://e.test/u**');
      expect(nodes.where((n) => n.target != null || n.code).every((n) => n.bold), isTrue);
      expect(nodes.where((n) => n.target != null || n.code).map((n) => n.text), ['c', 'l', '@m', '#h', 'https://e.test/u']);
    });
  });

  group('code', () {
    test('keeps markers inside a span literal', () {
      final nodes = parse('a `**x** [y](https://e.test) @z` b');
      expect(nodes.map((n) => (n.text, n.code)), [('a ', false), ('**x** [y](https://e.test) @z', true), (' b', false)]);
    });

    test('an empty or unclosed span is literal text', () {
      expect(parse('a `` b').single.text, 'a `` b');
      expect(parse('a ` b').single.text, 'a ` b');
      expect(parse('`a` `b').map((n) => (n.text, n.code)), [('a', true), (' `b', false)]);
    });
  });

  group('links', () {
    test('a label cannot contain an opening bracket', () {
      final nodes = parse('[a [b](https://e.test/x)');
      expect(nodes.map((n) => (n.text, n.target)), [('[a ', null), ('b', FrostRichTarget.link)]);
    });

    test('balanced parentheses stay inside the address', () {
      expect(targets('[w](https://e.test/a(b)c) d)', FrostRichTarget.link).single.value, 'https://e.test/a(b)c');
    });

    test('an unusable address or empty label keeps the whole text', () {
      for (final raw in ['[x](ftp://e.test)', '[x](not a url)', '[](https://e.test/a)', '[x]', '[']) {
        expect(parse(raw).every((n) => n.target == null), isTrue, reason: raw);
        expect(joined(raw), raw);
      }
    });

    test('bare URLs end before sentence punctuation and unbalanced brackets', () {
      final links = targets('go to https://e.test/a(b), (https://e.test/c) or https://e.test/d。next', FrostRichTarget.link);
      expect(links.map((n) => n.value), ['https://e.test/a(b)', 'https://e.test/c', 'https://e.test/d']);
      expect(joined('http:// alone'), 'http:// alone');
    });
  });

  group('edges', () {
    test('empty input has no nodes', () {
      expect(parse(''), isEmpty);
    });

    test('backslashes carry no meaning and stay literal', () {
      expect(joined(r'C:\temp\file'), r'C:\temp\file');
      expect(parse(r'\@bob').map((n) => (n.text, n.target)), [(r'\', null), ('@bob', FrostRichTarget.mention)]);
    });

    test('non-BMP text survives intact around every kind of item', () {
      const source = '😀 **𝒳𝒴** `𠮷` [😀](https://e.test/😀) 😀@𠮷野 #😀tag 😀';
      final nodes = parse(source);
      expect(nodes.where((n) => n.bold).single.text, '𝒳𝒴');
      expect(nodes.where((n) => n.code).single.text, '𠮷');
      expect(targets(source, FrostRichTarget.link).single.text, '😀');
      expect(targets(source, FrostRichTarget.mention).single.value, '𠮷野');
      expect(targets(source, FrostRichTarget.hashtag), isEmpty);
      for (final node in nodes) {
        expect(node.text.runes.every((r) => r < 0xd800 || r > 0xdfff), isTrue);
      }
      expect(joined('😀 hello 😀'), '😀 hello 😀');
      expect(targets('😀@bob', FrostRichTarget.mention).single.value, 'bob');
    });

    test('no node is empty and only markers are dropped from arbitrary text', () {
      final random = Random(7);
      const pieces = ['*', '**', '`', '@', '#', ' ', ' ', 'a', 'é', '😀', '，', '\n', 'https://e.test/p', '_'];
      for (var i = 0; i < 600; i++) {
        final source = List.generate(random.nextInt(24), (_) => pieces[random.nextInt(pieces.length)]).join();
        final nodes = parse(source);
        expect(nodes.every((n) => n.text.isNotEmpty), isTrue, reason: source);
        String strip(String s) => s.replaceAll('*', '').replaceAll('`', '');
        expect(strip(nodes.map((n) => n.text).join()), strip(source), reason: source);
      }
    });

    test('pathological repetition is scanned in linear time', () {
      final watch = Stopwatch()..start();
      parse('[a](x( ' * 20000);
      parse('[a ' * 20000);
      parse('*a ' * 20000);
      parse('`a' * 20001);
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    });
  });
}
