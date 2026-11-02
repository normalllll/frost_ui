// The registry must be complete for frost_data: every class its public_api.txt
// rows name is a case or says why it has none, and its contract rows name real
// cases.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../frost_ui/test/contract/registry.dart' show checkNames, notApplicableCategories;
import 'cases.dart';

const _prefix = 'frost_data:';

/// The names of this package's rows of [kind] in public_api.txt.
Set<String> _names(String kind) {
  final names = <String>{};
  for (final line in File('../../tool/library_health/public_api.txt').readAsLinesSync()) {
    final fields = line.split('	');
    if (!line.startsWith('#') && fields.length > 2 && fields[0] == kind && fields[2].startsWith(_prefix)) names.add(fields[1]);
  }
  return names;
}

String _constructor(String id) => id.substring(_prefix.length);

void main() {
  final classes = _names('class');
  final constructors = _names('ctor');
  final ids = [for (final c in displayCases) c.id];

  test('public_api.txt lists the frost_data classes', () {
    expect(classes, containsAll(['FrostListSource', 'FrostSliverDataList']));
  });

  test('every case id names the package and a public constructor', () {
    for (final id in ids) {
      expect(id, startsWith(_prefix));
      expect(constructors, contains(_constructor(id)));
    }
  });

  test('every exported class has a case or a not-applicable category', () {
    final registered = {for (final id in ids) _constructor(id).split('.').first, ...notApplicable.keys};
    expect(classes.difference(registered), isEmpty);
  });

  test('the registry names only classes that are exported', () {
    expect(notApplicable.keys.where((name) => !classes.contains(name)), isEmpty);
    expect(notApplicable.values.toSet().difference(notApplicableCategories), isEmpty);
  });

  test('case ids are unique', () {
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('every contract row of this package names a case and a check that exist', () {
    final bad = <String>[];
    for (final line in File('../../tool/library_health/allowlist.txt').readAsLinesSync()) {
      final fields = line.split('	');
      if (line.startsWith('#') || fields.length < 6 || fields[0] != 'contract' || !fields[1].startsWith(_prefix)) continue;
      if (!ids.contains(fields[1]) || !checkNames.contains(fields[3]) || fields[2] != '-' || fields[4] != '1') bad.add(line);
    }
    expect(bad, isEmpty);
  });

  test('skipped checks name a reason', () {
    final blank = [
      for (final c in displayCases)
        for (final entry in c.skip.entries)
          if (entry.value.trim().isEmpty) '${c.id} ${entry.key}',
    ];
    expect(blank, isEmpty);
  });
}
