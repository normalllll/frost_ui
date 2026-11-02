import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frost_data/frost_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('refresh retains content and coalesces repeated requests', () async {
    final source = _Source();
    addTearDown(source.dispose);
    await source.refresh(true);
    final response = Completer<List<int>>();
    source.initial = () => response.future;
    final pending = source.refresh(true);
    final repeated = source.refresh(true);
    expect(source.items, [1]);
    expect(source.phase, FrostLoadPhase.content);
    expect(source.refreshing, isTrue);
    expect(source.initialCalls, 2);
    response.complete([2]);
    expect(await pending, isTrue);
    expect(await repeated, isTrue);
    expect(source.initialCalls, 2);
    expect(source.items, [2]);
    expect(source.refreshing, isFalse);
  });

  test('refresh waits for pagination then refreshes even when pagination exhausts the list', () async {
    final source = _Source();
    addTearDown(source.dispose);
    await source.refresh(true);
    final response = Completer<List<int>>();
    source.next = () => response.future;
    final page = source.loadMore();
    source.initial = () async => [3];
    final refresh = source.refresh(true);
    expect(source.initialCalls, 1);
    expect(source.items, [1]);
    response.complete([]);
    await page;
    expect(await refresh, isTrue);
    expect(source.initialCalls, 2);
    expect(source.items, [3]);
  });

  test('failed refresh keeps content and retries the refresh rather than pagination', () async {
    final source = _Source();
    addTearDown(source.dispose);
    await source.refresh(true);
    source.initial = () async => throw StateError('refresh failure');
    expect(await source.refresh(true), isFalse);
    expect(source.items, [1]);
    expect(source.phase, FrostLoadPhase.content);
    source.initial = () async => [4];
    expect(await source.errorRefresh(), isTrue);
    expect(source.initialCalls, 3);
    expect(source.nextCalls, 0);
    expect(source.items, [4]);
  });
}

class _Source extends FrostListSource<int> {
  Future<List<int>> Function() initial = () async => [1];
  Future<List<int>> Function() next = () async => [];
  var initialCalls = 0, nextCalls = 0;
  @override
  Future<List<int>> initList() {
    initialCalls++;
    return initial();
  }

  @override
  Future<List<int>> nextList() {
    nextCalls++;
    return next();
  }
}
