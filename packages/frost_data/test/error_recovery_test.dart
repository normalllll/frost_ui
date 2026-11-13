import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frost_data/frost_data.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../../frost_ui/test/error_recovery_test.dart' show recoveryApp, verify;
import '../../frost_ui/test/support.dart';

class _Source extends FrostListSource<int> {
  _Source(this.footer);
  final bool footer;
  var initialCalls = 0, nextCalls = 0;
  bool resolved = false;
  @override
  Future<List<int>> initList() async {
    initialCalls++;
    if (!footer && !resolved) throw 'verify';
    return footer ? [1] : [];
  }

  @override
  Future<List<int>> nextList() async {
    nextCalls++;
    if (!resolved) throw 'verify';
    return [];
  }
}

void main() {
  for (final footer in [false, true]) {
    testWidgets('recovery retries the failed ${footer ? 'footer' : 'page'} once and guards repeat activation', (tester) async {
      final source = _Source(footer);
      await source.refresh(true);
      if (footer) await source.loadMore();
      final pending = Completer<bool>();
      var resolves = 0;
      await tester.pumpWidget(
        recoveryApp(
          Scaffold(
            body: FrostLoadingScrollView(
              slivers: [
                FrostSliverDataList<int>(
                  source: source,
                  autoLoadMore: false,
                  firstLoadSkeleton: const SizedBox(height: 40),
                  itemBuilder: (_, value, index) => Text('$value'),
                ),
              ],
            ),
          ),
          () {
            resolves++;
            return pending.future;
          },
        ),
      );
      await tester.pump();
      if (!footer) {
        expect(find.text('Mapped title'), findsOneWidget);
        expect(tester.widget<FrostIcon>(find.byType(FrostIcon).first).icon, testIcons.clock);
      }
      await tester.ensureVisible(verify());
      await tester.tap(verify());
      await tester.pump();
      await tester.tap(verify());
      await tester.pump();
      expect(resolves, 1);
      source.resolved = true;
      pending.complete(true);
      await tester.pumpAndSettle();
      expect(source.initialCalls, footer ? 1 : 2);
      expect(source.nextCalls, footer ? 2 : 0);
      expect(source.lastError, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      source.dispose();
    });
  }
  testWidgets('replacing the source with the same error cannot retry the new list', (tester) async {
    final first = _Source(false), second = _Source(false);
    await first.refresh(true);
    await second.refresh(true);
    expect(identical(first.lastError, second.lastError), isTrue);
    final pending = Completer<bool>();
    var source = first;
    late StateSetter update;
    await tester.pumpWidget(
      recoveryApp(
        StatefulBuilder(
          builder: (_, set) {
            update = set;
            return FrostLoadingScrollView(
              slivers: [FrostSliverDataList<int>(source: source, firstLoadSkeleton: const SizedBox(), itemBuilder: (_, value, index) => Text('$value'))],
            );
          },
        ),
        () => pending.future,
      ),
    );
    await tester.tap(verify());
    await tester.pump();
    update(() => source = second);
    await tester.pump();
    pending.complete(true);
    await tester.pumpAndSettle();
    expect(first.initialCalls, 1);
    expect(second.initialCalls, 1);
    expect(second.lastError, isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    first.dispose();
    second.dispose();
  });
  for (final direction in TextDirection.values) {
    for (final width in [180.0, 800.0]) {
      testWidgets('footer keeps wide row and reflows narrow actions in first layout $direction $width', (tester) async {
        final source = _Source(true);
        await source.refresh(true);
        await source.loadMore();
        await tester.pumpWidget(
          recoveryApp(
            Center(
              child: Directionality(
                textDirection: direction,
                child: SizedBox(
                  width: width,
                  child: FrostLoadingMoreIndicator(source: source),
                ),
              ),
            ),
            () async => false,
          ),
        );
        final message = tester.getRect(find.byType(FrostCompactMessage));
        final retry = tester.getRect(find.byWidgetPredicate((w) => w is FrostButton && w.label == 'L.retry'));
        expect(retry.center.dy, width == 800 ? closeTo(message.center.dy, .001) : greaterThan(message.bottom));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        source.dispose();
      });
    }
  }
}
