import 'git.dart';
import 'guidance.dart';
import 'lists.dart';
import 'model.dart';

final _reviewed = RegExp(r'^reviewed:(\d{4})(\d{2})(\d{2}):.*\S');

/// `reviewed:<YYYYMMDD>:<verdict>` with a real calendar date and a verdict
/// that is not empty, and not the value the row already had at the base: that
/// one reviewed an earlier growth.
bool isReviewed(String reason, String? baseReason) {
  final text = reason.trim();
  final match = _reviewed.firstMatch(text);
  if (match == null) return false;
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  final date = DateTime.utc(year, month, day);
  if (month < 1 || date.month != month || date.day != day) return false;
  return text != baseReason?.trim();
}

/// What the two list files gained since [base]. Empty for a list the commit
/// does not have: the gate was introduced after it.
List<Problem> findGrowth(String root, String base, String listDirectory) {
  final problems = <Problem>[];
  void add(String text) => problems.add(Problem(text, text));
  final guidance = guidanceFor('growth', '');

  final baseAllow =
      fileAtBase(root, base, 'tool/library_health/$allowlistName');
  final allow = readAllowList(listDirectory);
  if (baseAllow != null && allow != null) {
    final before = <String, AllowEntry>{};
    for (final e in AllowList('', parseLines(baseAllow)).entries) {
      if (e.wellFormed) before.putIfAbsent(e.key, () => e);
    }
    final seen = <String>{};
    for (final e in allow.entries) {
      if (!e.wellFormed || !seen.add(e.key)) continue;
      final old = before[e.key];
      final delta = e.count! - (old?.count ?? 0);
      if (delta > 0 && !isReviewed(e.reason, old?.reason)) {
        add(
          'growth allowlist ${e.rule} ${e.file} ${e.scope} ${e.detail} '
          '+$delta: $guidance',
        );
      }
    }
  }

  final baseApi = fileAtBase(root, base, 'tool/library_health/$publicApiName');
  final api = readApiList(listDirectory);
  if (baseApi != null && api != null) {
    final before = <String, ApiEntry>{};
    for (final e in ApiList('', parseLines(baseApi)).entries) {
      if (e.wellFormed) before.putIfAbsent(e.key, () => e);
    }
    final seen = <String>{};
    for (final e in api.entries) {
      if (!e.wellFormed || !seen.add(e.key)) continue;
      final old = before[e.key];
      final grew = old == null ||
          (e.kind == 'ctor' && e.params.difference(old.params).isNotEmpty);
      if (grew && !isReviewed(e.source, old?.source)) {
        add(
          'growth public-api ${e.kind} ${e.name} ${e.file} ${e.detail}: '
          '$guidance',
        );
      }
    }
  }
  problems.sort((a, b) => a.sortKey.compareTo(b.sortKey));
  return problems;
}
