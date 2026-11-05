import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/src/motion/_frame_work.dart';

void main() {
  testWidgets('shared queue runs one work item per frame and skips cancelled owners', (tester) async {
    final introduced = <int>[];
    FrostFrameWorkQueue.enqueue(() => introduced.add(1));
    final cancelled = FrostFrameWorkQueue.enqueue(() => introduced.add(2));
    FrostFrameWorkQueue.enqueue(() => introduced.add(3));
    await tester.pump();
    expect(introduced, [1]);
    cancelled.cancel();
    await tester.pump();
    expect(introduced, [1, 3]);
    await tester.pump();
    expect(introduced, [1, 3]);
  });
}
