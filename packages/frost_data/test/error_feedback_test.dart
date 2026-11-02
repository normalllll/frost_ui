import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_data/frost_data.dart';
import 'package:frost_ui/frost_ui.dart';

import '../../frost_ui/test/display_badges_test.dart' show display;
import '../../frost_ui/test/support.dart';

void main() {
  testWidgets('refresh error retry is standard compact and exhausted tail remains', (tester) async {
    final source = _Source()..fails = true;
    addTearDown(source.dispose);
    await source.refresh(true);
    await display(tester, FrostLoadingMoreIndicator<int>(source: source));
    final retry = tester.widget<FrostButton>(find.byType(FrostButton));
    expect(buttonControl(tester, find.byType(FrostButton)).variant, FrostButtonVariant.standard);
    expect(retry.size, FrostControlSize.compact);
    source.fails = false;
    await source.refresh(true);
    await tester.pump();
    expect(find.text(FrostScope.labelsOf(tester.element(find.byType(FrostLoadingMoreIndicator<int>))).noMoreItems), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  test('paged feedback stays free of Material appearance calls', () {
    final prohibited = RegExp(r'\b(?:TextButton|FilledButton|ElevatedButton|OutlinedButton|IconButton|AppBar)\s*(?:\.|\()|\b(?:textTheme|colorScheme)\b');
    for (final file in Directory('lib/src').listSync().whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      expect(file.readAsStringSync(), isNot(matches(prohibited)), reason: file.path);
    }
  });
}

class _Source extends FrostListSource<int> {
  bool fails = false;
  @override
  Future<List<int>> initList() async {
    if (fails) throw StateError('failure');
    return [];
  }

  @override
  Future<List<int>> nextList() async => [];
}
