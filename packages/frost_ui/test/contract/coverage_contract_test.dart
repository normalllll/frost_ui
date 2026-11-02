// The registry must be complete: every exported class is a case or says why it
// has none, and every public constructor of an interactive class has a case.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'registry.dart';

/// The names of the rows of [kind] in public_api.txt. frost_data's rows belong
/// to its own suite in packages/frost_data/test/contract.
Set<String> _names(String kind) {
  final lines = File('../../tool/library_health/public_api.txt').readAsLinesSync();
  final names = <String>{};
  for (final line in lines) {
    final fields = line.split('	');
    final other = fields.length > 2 && fields[2].startsWith('frost_data:');
    if (!line.startsWith('#') && !other && fields.length > 1 && fields[0] == kind) names.add(fields[1]);
  }
  return names;
}

String _className(String id) => id.split('.').first;

void main() {
  final classes = _names('class');
  final constructors = _names('ctor');
  final functions = _names('func');
  final interactiveIds = [for (final c in interactiveCases) c.id];
  final componentIds = [...interactiveIds, for (final c in displayCases) c.id, for (final c in hidingCases) c.id, for (final c in overlayCases) c.id];
  final registered = {for (final id in componentIds) _className(id), ...notApplicable.keys, ...exercisedByDecisions.keys, ...exercisedByOverlays.keys};

  test('public_api.txt is readable', () {
    expect(classes.length, greaterThan(200));
    expect(constructors.length, greaterThan(250));
  });

  test('every exported class has a case or a not-applicable category', () {
    final missing = [
      for (final name in classes)
        if (!registered.contains(name)) name,
    ]..sort();
    expect(missing, isEmpty, reason: 'Register these in test/contract/registry.dart or in a family file.');
  });

  test('the registry names only classes that are exported', () {
    final stale = [
      for (final name in [...notApplicable.keys, ...exercisedByDecisions.keys, ...exercisedByOverlays.keys])
        if (!classes.contains(name)) name,
      for (final id in componentIds)
        if (id.startsWith('Frost') && !classes.contains(_className(id))) id,
    ];
    expect(stale, isEmpty);
  });

  test('a class is either a component case or not applicable, not both', () {
    final cased = {for (final id in componentIds) _className(id)};
    expect(notApplicable.keys.where(cased.contains), isEmpty);
    expect(notApplicable.values.toSet().difference(notApplicableCategories), isEmpty);
  });

  test('case ids are unique within a family', () {
    final repeated = <String>{};
    for (final ids in [
      interactiveIds,
      [for (final c in displayCases) c.id],
      [for (final c in hidingCases) c.id],
      [for (final c in overlayCases) c.id],
    ]) {
      final seen = <String>{};
      repeated.addAll(ids.where((id) => !seen.add(id)));
    }
    expect(repeated, isEmpty);
  });

  test('every public constructor of an interactive class has a case', () {
    final interactiveClasses = {for (final id in interactiveIds) _className(id)};
    final missing = [
      for (final ctor in constructors)
        if (interactiveClasses.contains(_className(ctor)) && !interactiveIds.contains(ctor)) ctor,
    ]..sort();
    expect(missing, isEmpty, reason: 'Add an InteractiveCase with this id to cases_interactive.dart.');
  });

  test('every interactive and display case id is a public constructor', () {
    final unknown = [
      for (final id in [...interactiveIds, for (final c in displayCases) c.id])
        if (!constructors.contains(id)) id,
    ];
    expect(unknown, isEmpty);
  });

  test('every show function has an overlay case', () {
    final opened = {for (final c in overlayCases) _className(c.id)};
    final missing = [
      for (final name in functions)
        if (name.startsWith('showFrost') && !opened.contains(name)) name,
    ];
    expect(missing, isEmpty);
  });

  test('the hiding family includes the required components', () {
    final names = {for (final c in hidingCases) _className(c.id)};
    expect(names, containsAll(['FrostSpringReveal', 'FrostLazyIndexedStack', 'FrostTabHost']));
  });

  test('every contract row of allowlist.txt names a case and a check that exist', () {
    final ids = {...componentIds, for (final pair in decisionIds) pair.split('	').first};
    final bad = <String>[];
    for (final line in File('../../tool/library_health/allowlist.txt').readAsLinesSync()) {
      final fields = line.split('	');
      if (line.startsWith('#') || fields.length < 6 || fields[0] != 'contract' || fields[1].startsWith('frost_data:')) continue;
      if (!ids.contains(fields[1]) || !checkNames.contains(fields[3]) || fields[2] != '-' || fields[4] != '1') bad.add(line);
    }
    expect(bad, isEmpty);
  });

  test('skipped checks name a reason', () {
    final blank = [
      for (final c in [...interactiveCases, ...displayCases])
        for (final entry in c.skip.entries)
          if (entry.value.trim().isEmpty) '${c.id} ${entry.key}',
      for (final c in hidingCases)
        for (final entry in c.skip.entries)
          if (entry.value.trim().isEmpty) '${c.id} ${entry.key}',
      for (final c in overlayCases)
        for (final entry in c.skip.entries)
          if (entry.value.trim().isEmpty) '${c.id} ${entry.key}',
    ];
    expect(blank, isEmpty);
  });
}
