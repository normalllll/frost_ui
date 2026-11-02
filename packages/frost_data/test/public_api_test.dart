import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_data/frost_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('paged APIs compile with widgets.dart and frost_data alone', () {
    final source = _Source();
    addTearDown(source.dispose);
    final widgets = <Widget>[
      FrostSliverDataGrid<int>(
        source: source,
        itemBuilder: (_, value, index) => Text('$value'),
        firstLoadSkeleton: const SizedBox(height: 80),
        minTileWidth: 100,
        tileHeight: (_, width) => 80,
      ),
    ];
    expect(widgets, hasLength(1));
  });

  test('a source exposes its items read-only', () async {
    final source = _Source();
    addTearDown(source.dispose);
    await source.refresh();
    expect(source.items, [1, 2]);
    expect(() => source.items.add(3), throwsUnsupportedError);
    expect(() => source.items.clear(), throwsUnsupportedError);
    expect(source, isNot(isA<List<int>>()));
  });

  test('the rebuild stream hands out a read-only view too', () async {
    final source = _Source();
    addTearDown(source.dispose);
    final event = source.rebuild.first;
    await source.refresh();
    final items = await event;
    expect(items, [1, 2]);
    expect(() => (items as List<int>).add(3), throwsUnsupportedError);
  });
}

class _Source extends FrostListSource<int> {
  @override
  Future<List<int>> initList() async => [1, 2];
  @override
  Future<List<int>> nextList() async => [];
}
