/// One occurrence of something the gate counts.
class Finding {
  Finding(this.rule, this.file, this.line, this.scope, this.detail);

  final String rule;

  /// Relative to `lib/src`, forward slashes.
  final String file;
  final int line;
  final String scope;
  final String detail;

  String get key => keyOf(rule, file, scope, detail);

  static String keyOf(String rule, String file, String scope, String detail) =>
      [rule, file, scope, detail].join('\t');
}

/// One row of the public API snapshot.
class ApiRow {
  ApiRow(this.kind, this.name, this.file, this.line, [this.detail = '-']);

  final String kind;
  final String name;
  final String file;
  final int line;

  /// For `ctor`, the sorted public parameter names joined with commas.
  final String detail;

  String get key => [kind, name, file].join('\t');

  Set<String> get params =>
      detail == '-' || detail.isEmpty ? <String>{} : detail.split(',').toSet();
}

/// A problem the gate reports; printed in the order given by [sortKey].
class Problem {
  Problem(this.text, this.sortKey);

  final String text;
  final String sortKey;
}

int compareFields(List<String> a, List<String> b) {
  for (var i = 0; i < a.length && i < b.length; i++) {
    final c = a[i].compareTo(b[i]);
    if (c != 0) return c;
  }
  return a.length.compareTo(b.length);
}
