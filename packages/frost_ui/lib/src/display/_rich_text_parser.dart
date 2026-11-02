/// A deliberately small private grammar. Widgets own focus and callbacks.
///
/// The source is scanned once, left to right. Anything the scanner cannot
/// recognise stays in the output as literal text, so joining the node texts
/// reproduces every character of the input except the markers that were
/// actually consumed (emphasis stars, code backticks, link punctuation).
enum FrostRichTarget { link, mention, hashtag }

class FrostRichNode {
  const FrostRichNode(this.text, {this.bold = false, this.italic = false, this.code = false, this.target, this.value});
  final String text;
  final bool bold, italic, code;
  final FrostRichTarget? target;
  final String? value;
}

class FrostRichDocument {
  FrostRichDocument(String text) : nodes = List.unmodifiable(_RichScanner(text).scan());
  final List<FrostRichNode> nodes;
}

enum _PieceKind { plain, code, target, open, close }

/// One scanned item. Emphasis markers become `open` and `close` pieces; an
/// `open` that never found its `close` is written back as literal stars.
class _Piece {
  _Piece(this.kind, this.text, {this.target, this.value, this.width = 0, this.run = -1});
  final _PieceKind kind;
  final String text;
  final FrostRichTarget? target;
  final String? value;
  final int width, run;
  bool matched = false;
}

class _RichScanner {
  _RichScanner(this.source);
  final String source;
  static final _word = RegExp(r'[\p{L}\p{N}_]', unicode: true);
  static final _space = RegExp(r'\s');
  // Unescaped full-width sentence punctuation terminates a URL immediately;
  // it is not merely stripped from the end of an already-consumed token.
  static const _urlSentenceBoundary = '，。！？；：、';
  // Sentence punctuation belongs outside automatically detected URLs.
  static const _punctuation = '.,!?;:，。！？；：、"\'”’」』';
  // A mention or hashtag may follow anything except a word character or a
  // character that makes the symbol part of something else (`a@b`, `&#39;`).
  static const _targetBlockers = '@#&';

  final _pieces = <_Piece>[];
  final _plain = StringBuffer();
  // Indexes into _pieces of the emphasis openers still waiting for a closer.
  final _openers = <int>[];
  // Emphasis ranges as (first piece, end piece, width), applied after the scan.
  final _ranges = <(int, int, int)>[];
  var _runs = 0;

  /// For every `(`, the index of its matching `)` or -1. Built on first use so
  /// text without links pays nothing, and so each link candidate is answered
  /// in constant time rather than by rescanning to the end of the source.
  late final List<int> _parenClose = _matchParens();

  List<FrostRichNode> scan() {
    var index = 0;
    while (index < source.length) {
      final char = source[index];
      if (char == '`') {
        final end = source.indexOf('`', index + 1);
        if (end == index + 1) {
          _plain.write('``');
          index += 2;
          continue;
        }
        if (end > index) {
          _add(_Piece(_PieceKind.code, source.substring(index + 1, end)));
          index = end + 1;
          continue;
        }
      } else if (char == '*') {
        index = _emphasis(index);
        continue;
      } else if (char == '[') {
        final next = _link(index);
        if (next > index) {
          index = next;
          continue;
        }
      } else if (char == 'h' && (source.startsWith('http://', index) || source.startsWith('https://', index))) {
        final next = _autoLink(index);
        if (next > index) {
          index = next;
          continue;
        }
      } else if ((char == '@' || char == '#') && _canStartTarget(index)) {
        final next = _target(index);
        if (next > index) {
          index = next;
          continue;
        }
      }
      _plain.write(char);
      index++;
    }
    return _assemble();
  }

  void _add(_Piece piece) {
    if (_plain.isNotEmpty) {
      _pieces.add(_Piece(_PieceKind.plain, _plain.toString()));
      _plain.clear();
    }
    _pieces.add(piece);
  }

  /// Reads a run of stars at [start]. A run opens emphasis when text follows
  /// it directly and closes emphasis when text precedes it directly, so
  /// spaced stars such as `2 * 3` stay literal. Returns the index after the run.
  int _emphasis(int start) {
    var end = start;
    while (end < source.length && source[end] == '*') {
      end++;
    }
    final canOpen = end < source.length && !_space.hasMatch(source[end]);
    final canClose = start > 0 && !_space.hasMatch(source[start - 1]);
    final run = _runs++;
    var remaining = end - start;
    while (remaining > 0) {
      if (canClose && _openers.isNotEmpty) {
        final open = _pieces[_openers.last];
        // A run never closes an opener it created itself, so `****` between
        // letters opens twice instead of producing an empty emphasis.
        if (open.run != run && open.width <= remaining) {
          _add(_Piece(_PieceKind.close, '*' * open.width));
          open.matched = true;
          _ranges.add((_openers.removeLast() + 1, _pieces.length - 1, open.width));
          remaining -= open.width;
          continue;
        }
      }
      if (canOpen) {
        final width = remaining >= 2 ? 2 : 1;
        _add(_Piece(_PieceKind.open, '*' * width, width: width, run: run));
        _openers.add(_pieces.length - 1);
        remaining -= width;
        continue;
      }
      _plain.write('*' * remaining);
      break;
    }
    return end;
  }

  /// Reads `[label](http-url)` at [start]. Returns the index after it, or
  /// [start] when this `[` does not begin a link, so the caller keeps it as
  /// text. A well-formed link whose target is not http(s) or whose label is
  /// empty is kept whole as text.
  int _link(int start) {
    var labelEnd = start + 1;
    while (labelEnd < source.length && source[labelEnd] != ']') {
      // A nested `[` begins its own candidate; this one is plain text.
      if (source[labelEnd] == '[') return start;
      labelEnd++;
    }
    if (labelEnd + 1 >= source.length || source[labelEnd + 1] != '(') return start;
    final urlEnd = _parenClose[labelEnd + 1];
    if (urlEnd < 0) return start;
    final label = source.substring(start + 1, labelEnd), raw = source.substring(labelEnd + 2, urlEnd), uri = Uri.tryParse(raw);
    if (label.isNotEmpty && uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty) {
      _add(_Piece(_PieceKind.target, label, target: FrostRichTarget.link, value: raw));
    } else {
      _plain.write(source.substring(start, urlEnd + 1));
    }
    return urlEnd + 1;
  }

  /// Reads a bare URL at [start]. Returns the index after it, or [start] when
  /// what follows `http://` is not a usable address.
  int _autoLink(int start) {
    var end = start;
    while (end < source.length && !_space.hasMatch(source[end]) && !'<>`*'.contains(source[end]) && !_urlSentenceBoundary.contains(source[end])) {
      end++;
    }
    var url = source.substring(start, end);
    var trimming = true;
    while (trimming && url.isNotEmpty) {
      trimming = false;
      if (_punctuation.contains(url[url.length - 1])) {
        url = url.substring(0, url.length - 1);
        trimming = true;
        continue;
      }
      for (final pair in const [('(', ')'), ('[', ']'), ('{', '}'), ('（', '）'), ('【', '】')]) {
        if (url.endsWith(pair.$2) && pair.$2.allMatches(url).length > pair.$1.allMatches(url).length) {
          url = url.substring(0, url.length - pair.$2.length);
          trimming = true;
          break;
        }
      }
    }
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty || url.isEmpty) return start;
    _add(_Piece(_PieceKind.target, url, target: FrostRichTarget.link, value: url));
    return start + url.length;
  }

  /// Reads `@name` or `#name` at [start]. Returns the index after it, or
  /// [start] when no name follows the symbol.
  int _target(int start) {
    var end = start + 1;
    while (end < source.length) {
      final unit = source.codeUnitAt(end);
      final length = unit >= 0xd800 && unit <= 0xdbff && end + 1 < source.length ? 2 : 1;
      if (!_word.hasMatch(source.substring(end, end + length))) break;
      end += length;
    }
    if (end == start + 1) return start;
    _add(
      _Piece(
        _PieceKind.target,
        source.substring(start, end),
        target: source[start] == '@' ? FrostRichTarget.mention : FrostRichTarget.hashtag,
        value: source.substring(start + 1, end),
      ),
    );
    return end;
  }

  /// Whether the symbol at [index] stands apart from a preceding word, so that
  /// `(@bob)` and `转发：@张三` are targets while `a@b` is not.
  bool _canStartTarget(int index) {
    if (index == 0) return true;
    var start = index - 1;
    final unit = source.codeUnitAt(start);
    if (unit >= 0xdc00 && unit <= 0xdfff && start > 0) {
      final lead = source.codeUnitAt(start - 1);
      if (lead >= 0xd800 && lead <= 0xdbff) start--;
    }
    final previous = source.substring(start, index);
    return !_word.hasMatch(previous) && !_targetBlockers.contains(previous);
  }

  List<int> _matchParens() {
    final close = List<int>.filled(source.length, -1), open = <int>[];
    for (var i = 0; i < source.length; i++) {
      if (source[i] == '(') {
        open.add(i);
      } else if (source[i] == ')' && open.isNotEmpty) {
        close[open.removeLast()] = i;
      }
    }
    return close;
  }

  List<FrostRichNode> _assemble() {
    if (_plain.isNotEmpty) {
      _pieces.add(_Piece(_PieceKind.plain, _plain.toString()));
      _plain.clear();
    }
    final boldChange = List<int>.filled(_pieces.length + 1, 0), italicChange = List<int>.filled(_pieces.length + 1, 0);
    for (final (from, to, width) in _ranges) {
      final change = width == 2 ? boldChange : italicChange;
      change[from]++;
      change[to]--;
    }
    final nodes = <FrostRichNode>[], pending = StringBuffer();
    var bold = 0, italic = 0, pendingBold = false, pendingItalic = false;
    void flush() {
      if (pending.isNotEmpty) {
        nodes.add(FrostRichNode(pending.toString(), bold: pendingBold, italic: pendingItalic));
        pending.clear();
      }
    }

    void writePlain(String text) {
      final isBold = bold > 0, isItalic = italic > 0;
      if (isBold != pendingBold || isItalic != pendingItalic) flush();
      pendingBold = isBold;
      pendingItalic = isItalic;
      pending.write(text);
    }

    for (var i = 0; i < _pieces.length; i++) {
      bold += boldChange[i];
      italic += italicChange[i];
      final piece = _pieces[i];
      switch (piece.kind) {
        case _PieceKind.plain:
          writePlain(piece.text);
        case _PieceKind.open:
          if (!piece.matched) writePlain(piece.text);
        case _PieceKind.close:
          break;
        case _PieceKind.code:
        case _PieceKind.target:
          flush();
          nodes.add(
            FrostRichNode(piece.text, bold: bold > 0, italic: italic > 0, code: piece.kind == _PieceKind.code, target: piece.target, value: piece.value),
          );
      }
    }
    flush();
    return nodes;
  }
}
