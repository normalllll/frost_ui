import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/overlays/_menu_item.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

Future<void> systemApp(WidgetTester tester, Widget child, {double width = 300, bool reduced = false}) => tester.pumpWidget(
  frostTestApp(
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: Scaffold(
          body: Center(
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    ),
  ),
);
Finder copyButton() => find.byType(FrostClickSurface);

void main() {
  testWidgets('Copyable wraps selectable display, copies source, announces and checks for exactly 1500ms', (tester) async {
    final semantics = tester.ensureSemantics();
    final calls = <MethodCall>[], announcements = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility, (message) async {
      announcements.add(message);
      return null;
    });
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
      tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility, null);
    });
    await systemApp(
      tester,
      const FrostCopyable(text: 'full source', display: 'A displayed value that wraps across several lines in a narrow area', monospace: true),
      width: 180,
    );
    final selectable = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(selectable.maxLines, isNull);
    expect(selectable.enableInteractiveSelection, true);
    expect(selectable.style!.fontFamily, 'Consolas');
    final state = tester.state<EditableTextState>(find.byType(EditableText));
    expect(state.renderEditable.size.height, greaterThan(state.renderEditable.preferredLineHeight * 2));
    final selection = await tester.startGesture(tester.getTopLeft(find.byType(SelectableText)) + const Offset(5, 5), kind: PointerDeviceKind.mouse);
    await selection.moveBy(const Offset(60, 0));
    await selection.up();
    await tester.pumpAndSettle();
    expect(state.textEditingValue.selection.isValid, true);
    expect(state.textEditingValue.selection.isCollapsed, false);
    await tester.tap(copyButton());
    await tester.pump();
    expect(calls.where((c) => c.method == 'Clipboard.setData').single.arguments, {'text': 'full source'});
    expect(announcements.any((e) => e is Map && (e['data'] as Map?)?['message'] == 'L.copied'), true);
    expect(find.byKey(const ValueKey(true)), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1499));
    expect(find.byKey(const ValueKey(true)), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byKey(const ValueKey(false)), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey(true)), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
  testWidgets('Copyable secondary click on selectable text opens one shared Copy action', (tester) async {
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await systemApp(tester, const FrostCopyable(text: 'source', display: 'Display'));
    final gesture = await tester.startGesture(tester.getCenter(find.byType(SelectableText)), kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(FrostMenuItem), findsOneWidget);
    expect(find.text('L.copy'), findsOneWidget);
    await tester.tap(find.byType(FrostMenuItem));
    await tester.pumpAndSettle();
    expect(clipboard, 'source');
    expect(find.byKey(const ValueKey(true)), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(tester.takeException(), isNull);
  });
  testWidgets('Copyable ignores stale clipboard completion when text changes or unmounts', (tester) async {
    final completion = Completer<void>();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') await completion.future;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await systemApp(tester, const FrostCopyable(text: 'old'));
    await tester.tap(copyButton());
    await systemApp(tester, const FrostCopyable(text: 'new'));
    completion.complete();
    await tester.pump();
    expect(find.byKey(const ValueKey(true)), findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
