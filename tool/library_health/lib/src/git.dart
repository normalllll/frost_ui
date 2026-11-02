import 'dart:convert';
import 'dart:io';

/// Git failed in a way that is not "no such file" or "not a repository". The
/// gate cannot decide, so the run exits 2.
class GitError extends StateError {
  GitError(super.message);
}

class _Result {
  _Result(this.exitCode, this.stdout, this.stderr);

  final int exitCode;
  final String stdout;
  final String stderr;
}

/// Runs `git -C [root] ...`. Throws [GitError] when git cannot be started.
_Result _run(String root, List<String> arguments) {
  try {
    final result = Process.runSync(
      'git',
      ['-C', root, ...arguments],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
      environment: {'LC_ALL': 'C', 'LANGUAGE': 'C'},
    );
    return _Result(result.exitCode, '${result.stdout}', '${result.stderr}');
  } on ProcessException catch (error) {
    throw GitError('cannot run git: ${error.message}');
  }
}

/// Output of `git -C [root] ...`, or null when git fails or is missing.
String? git(String root, List<String> arguments) {
  try {
    final result = _run(root, arguments);
    return result.exitCode == 0 ? result.stdout : null;
  } on GitError {
    return null;
  }
}

enum BaseState {
  /// [root] is not inside a git repository.
  notRepository,

  /// A repository that does not know the commit.
  unknown,
  ok,
}

/// Throws [GitError] for any failure other than "not a repository".
BaseState baseState(String root, String base) {
  final repository = _run(root, ['rev-parse', '--git-dir']);
  if (repository.exitCode != 0) {
    if (repository.stderr.contains('not a git repository')) {
      return BaseState.notRepository;
    }
    throw GitError('git rev-parse failed: ${repository.stderr.trim()}');
  }
  final commit =
      _run(root, ['rev-parse', '--verify', '--quiet', '$base^{tree}']);
  return commit.exitCode == 0 ? BaseState.ok : BaseState.unknown;
}

/// The content of [path] (relative to [root]) in commit [base], or null when
/// the commit's tree has no such file. Throws [GitError] when git fails.
String? fileAtBase(String root, String base, String path) {
  final listing = _run(root, ['ls-tree', '--name-only', base, '--', path]);
  if (listing.exitCode != 0) {
    throw GitError('git ls-tree failed: ${listing.stderr.trim()}');
  }
  if (listing.stdout.trim().isEmpty) return null;
  final shown = _run(root, ['show', '$base:./$path']);
  if (shown.exitCode != 0) {
    throw GitError('git show failed: ${shown.stderr.trim()}');
  }
  return shown.stdout;
}
