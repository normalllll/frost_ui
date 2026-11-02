// Library health gate. Run from anywhere: dart tool/check_library_health.dart
// Spec: tool/library_health/README.md. This file only needs the Dart SDK; the
// checker itself is a small package that needs `dart pub get` once. Its
// compiled kernel is cached next to the package config. The cache key is a
// hash of the sources plus the SDK version, not file times, so moving or
// copying files and upgrading the SDK both rebuild it.
import 'dart:convert';
import 'dart:io';

Future<int> _run(
  List<String> arguments, {
  String? directory,
  bool quiet = false,
}) async {
  final process = await Process.start(
    Platform.resolvedExecutable,
    arguments,
    workingDirectory: directory,
    mode: quiet ? ProcessStartMode.normal : ProcessStartMode.inheritStdio,
  );
  if (quiet) {
    process.stdout.drain<void>();
    process.stderr.drain<void>();
  }
  return process.exitCode;
}

/// FNV-1a, 64 bit: enough to tell two source trees apart, and it needs no
/// package.
int _fnv(int hash, List<int> bytes) {
  for (final byte in bytes) {
    hash = (hash ^ byte) * 0x100000001b3;
  }
  return hash;
}

String _key(Directory package) {
  var hash = 0xcbf29ce484222325;
  final files = <File>[
    File('${package.path}/pubspec.yaml'),
    File('${package.path}/pubspec.lock'),
    for (final name in ['lib', 'bin'])
      if (Directory('${package.path}/$name').existsSync())
        ...Directory('${package.path}/$name')
            .listSync(recursive: true)
            .whereType<File>(),
  ]..sort((a, b) => a.path.compareTo(b.path));
  final base = package.path.replaceAll(r'\', '/');
  for (final file in files) {
    if (!file.existsSync()) continue;
    final name = file.path.replaceAll(r'\', '/').replaceFirst(base, '');
    hash = _fnv(hash, utf8.encode('$name\u0000'));
    hash = _fnv(hash, file.readAsBytesSync());
    hash = _fnv(hash, const [0]);
  }
  hash = _fnv(hash, utf8.encode(Platform.version));
  return hash.toUnsigned(64).toRadixString(16);
}

bool _fresh(File snapshot, File keyFile, String key) {
  if (!snapshot.existsSync() || !keyFile.existsSync()) return false;
  try {
    return keyFile.readAsStringSync().trim() == key;
  } on FileSystemException {
    return false;
  }
}

Future<void> main(List<String> arguments) async {
  final tool = File.fromUri(Platform.script).parent;
  final package = Directory('${tool.path}/library_health');
  final packages = File('${package.path}/.dart_tool/package_config.json');
  if (!packages.existsSync()) {
    final code = await _run(['pub', 'get'], directory: package.path);
    if (code != 0) {
      stderr.writeln('library health: dart pub get failed (exit $code)');
      exitCode = code;
      return;
    }
  }
  final source = '${package.path}/bin/check.dart';
  final snapshot = File('${package.path}/.dart_tool/check.dill');
  final keyFile = File('${package.path}/.dart_tool/check.dill.key');
  final key = _key(package);
  if (!_fresh(snapshot, keyFile, key)) {
    final temporary = '${snapshot.path}.$pid';
    final code = await _run([
      'compile',
      'kernel',
      source,
      '--packages=${packages.path}',
      '-o',
      temporary,
    ], quiet: true);
    if (code == 0) {
      try {
        File(temporary).renameSync(snapshot.path);
        keyFile.writeAsStringSync(key);
      } on FileSystemException {
        // Another run replaced it first.
        try {
          File(temporary).deleteSync();
        } on FileSystemException {
          // Already gone.
        }
      }
    }
  }
  exitCode = _fresh(snapshot, keyFile, key)
      ? await _run([snapshot.path, ...arguments])
      : await _run(['--packages=${packages.path}', source, ...arguments]);
}
