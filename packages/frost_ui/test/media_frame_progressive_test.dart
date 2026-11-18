import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'media_frame_test.dart' show ControlledImage;
import 'support.dart';

final _placeholder = find.text('PLACEHOLDER');
final _picture = find.descendant(of: find.byType(FrostMediaFrame), matching: find.byType(RawImage));

Future<ImageInfo> _scan(WidgetTester tester) async => ImageInfo(image: (await tester.runAsync(() => createTestImage(width: 160, height: 96)))!);

Widget _frame(ImageProvider image) => frostTestApp(
  Center(
    child: SizedBox(
      width: 320,
      height: 200,
      child: FrostMediaFrame(
        image: image,
        aspectRatio: 160 / 96,
        placeholderBuilder: (_, progress) => Text('PLACEHOLDER', key: ValueKey(progress)),
      ),
    ),
  ),
);

void main() {
  testWidgets('a picture arriving scan by scan stays on screen while the rest downloads', (tester) async {
    final image = ControlledImage();
    await tester.pumpWidget(_frame(image));

    image.completer.chunk(1000, 6000);
    await tester.pump();
    expect(_placeholder, findsOneWidget, reason: 'before the first scan the placeholder shows');
    expect(find.byKey(const ValueKey<double?>(1000 / 6000)), findsOneWidget, reason: 'with its progress');
    expect(_picture, findsNothing);

    image.completer.complete(await _scan(tester));
    await tester.pumpAndSettle();
    expect(_picture, findsOneWidget);

    for (final loaded in [3000, 4500]) {
      image.completer.chunk(loaded, 6000);
      await tester.pump();
      expect(_picture, findsOneWidget, reason: 'after $loaded bytes the first scan is still drawn');
      expect(_placeholder, findsNothing);
    }

    image.completer.complete(await _scan(tester));
    image.completer.chunk(6000, 6000);
    await tester.pumpAndSettle();
    expect(_picture, findsOneWidget);
    expect(_placeholder, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
