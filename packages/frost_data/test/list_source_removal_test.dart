import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_data/frost_data.dart';

import '../../frost_ui/test/support.dart';

class _Numbers extends FrostListSource<int> {
  List<int> first = [1, 2, 3, 4];
  Future<List<int>> Function() next = () async => [];
  var nextCalls = 0;
  @override
  Future<List<int>> initList() async => first;
  @override
  Future<List<int>> nextList() {
    nextCalls++;
    return next();
  }

  @override
  bool hasMoreByResult(List<int> list) => more;
  bool more = true;
}

class _Page {
  const _Page(this.items, this.next);
  final List<int> items;
  final String? next;
}

class _Cursor extends FrostCursorListSource<int, _Page> {
  @override
  Future<_Page> loadFirstPage() async => const _Page([1, 2, 3, 4], 'page-2');
  @override
  Future<_Page> loadNextPage(String nextUrl) async => const _Page([5], null);
  @override
  String? nextUrlFromPage(_Page page) => page.next;
  @override
  List<int> itemsFromPage(_Page page) => page.items;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('removing loaded items keeps the others in order and notifies once', () async {
    final source = _Numbers();
    addTearDown(source.dispose);
    await source.refresh();
    var notified = 0;
    source.addListener(() => notified++);
    expect(source.removeWhere((item) => item.isEven), 2);
    expect(source.items, [1, 3]);
    expect(notified, 1);
    expect(source.phase, FrostLoadPhase.content);
    expect(source.hasMore, isTrue);
    expect(source.removeWhere((item) => item > 10), 0);
    expect(notified, 1, reason: 'nothing removed, nothing to hear');
  });

  test('a cursor source keeps its next page across a removal', () async {
    final source = _Cursor();
    addTearDown(source.dispose);
    await source.refresh();
    source.removeWhere((item) => item < 3);
    expect(source.items, [3, 4]);
    expect(source.hasMore, isTrue);
    expect(source.nextUrl, 'page-2');
    await source.loadMore();
    expect(source.items, [3, 4, 5]);
  });

  test('a removal while a page loads keeps the incoming page', () async {
    final source = _Numbers();
    addTearDown(source.dispose);
    await source.refresh();
    final page = Completer<List<int>>();
    source.next = () => page.future;
    final loading = source.loadMore();
    source.removeWhere((item) => item == 2);
    page.complete([5, 6]);
    expect(await loading, isTrue);
    expect(source.items, [1, 3, 4, 5, 6]);
  });

  test('an emptied source without more pages is empty', () async {
    final source = _Numbers()..more = false;
    addTearDown(source.dispose);
    await source.refresh();
    source.removeWhere((_) => true);
    expect(source.phase, FrostLoadPhase.empty);
  });

  testWidgets('removing every item while more pages remain loads the next page', (tester) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final source = _Numbers()..first = List.generate(60, (index) => index);
    source.next = () async {
      source.more = false;
      return [70, 71];
    };
    await tester.pumpWidget(
      frostTestApp(
        Scaffold(
          body: CustomScrollView(
            slivers: [
              FrostSliverDataList<int>(
                source: source,
                firstLoadSkeleton: const SizedBox(height: 120),
                itemExtent: 60,
                itemBuilder: (_, item, _) => Text('Item $item'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(source.nextCalls, 0, reason: 'the end of the list is out of reach');
    final before = source.nextCalls;
    source.removeWhere((_) => true);
    expect(source.phase, isNot(FrostLoadPhase.empty));
    await tester.pumpAndSettle();
    expect(source.nextCalls, greaterThan(before));
    expect(source.items, [70, 71]);
    expect(find.text('Item 70'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    source.dispose();
  });
}
