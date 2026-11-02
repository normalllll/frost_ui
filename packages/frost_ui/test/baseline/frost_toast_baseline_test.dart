import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _noop() {}

// FrostToastHost is installed by the harness app, and a second one would share
// its static key, so every host case goes through the notices it shows. The
// subject is a page; each act raises notices from it.
const _page = FrostText('Page');

typedef _Show = void Function(BuildContext context);

BaselineAct _show(_Show show) => (tester, subject) async {
  show(tester.element(subject));
};

BaselineAct _showAll(List<_Show> shows) => (tester, subject) async {
  for (final show in shows) {
    show(tester.element(subject));
    await tester.pump(const Duration(milliseconds: 100));
  }
};

Future<void> _hoverToast(WidgetTester tester, Finder subject) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await gesture.moveTo(tester.getCenter(find.text('Saved').last));
}

// Raises the notices, then hovers the stack so it spreads into a list.
Future<void> _stackHover(WidgetTester tester, Finder subject) async {
  await _showAll(<_Show>[(_) => FrostToast.success('Saved'), (_) => FrostToast.info('Syncing'), (_) => FrostToast.warning('Low storage')])(tester, subject);
  await tester.pump(const Duration(milliseconds: 600));
  await _hoverToast(tester, subject);
}

Future<void> _copied(WidgetTester tester, Finder subject) async {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  FrostToast.copied('Copied');
}

void main() {
  final themes = [...BaselineEnv.themes, BaselineEnv.touch];
  baselineGroup('FrostToast', [
    BaselineCase('FrostToast.success/required', (_) => _page, act: _show((_) => FrostToast.success('Saved')), envs: [...BaselineEnv.all]),
    BaselineCase(
      'FrostToast.success/description',
      (_) => _page,
      act: _show((_) => FrostToast.success('Saved', description: 'Your changes are live')),
      envs: themes,
    ),
    BaselineCase(
      'FrostToast.success/actionLabel+onAction',
      (_) => _page,
      act: _show((_) => FrostToast.success('Saved', actionLabel: 'View', onAction: _noop)),
      envs: themes,
    ),
    BaselineCase(
      'FrostToast.success/description+actionLabel+onAction',
      (_) => _page,
      act: _show((_) => FrostToast.success('Saved', description: 'Your changes are live', actionLabel: 'View', onAction: _noop)),
    ),
    BaselineCase('FrostToast.error/required', (_) => _page, act: _show((_) => FrostToast.error('Could not save')), envs: themes),
    BaselineCase(
      'FrostToast.error/description',
      (_) => _page,
      act: _show((_) => FrostToast.error('Could not save', description: 'The disk is full')),
      envs: themes,
    ),
    BaselineCase(
      'FrostToast.error/actionLabel+onAction',
      (_) => _page,
      act: _show((_) => FrostToast.error('Could not save', actionLabel: 'Retry', onAction: _noop)),
      envs: themes,
    ),
    BaselineCase('FrostToast.fromError/required', (_) => _page, act: _show((context) => FrostToast.fromError(context, 'boom')), envs: themes),
    BaselineCase(
      'FrostToast.fromError/description',
      (_) => _page,
      act: _show((context) => FrostToast.fromError(context, 'boom', description: 'Try again later')),
    ),
    BaselineCase(
      'FrostToast.fromError/actionLabel+onAction',
      (_) => _page,
      act: _show((context) => FrostToast.fromError(context, 'boom', actionLabel: 'Retry', onAction: _noop)),
      envs: themes,
    ),
    BaselineCase('FrostToast.info/required', (_) => _page, act: _show((_) => FrostToast.info('Syncing')), envs: themes),
    BaselineCase(
      'FrostToast.actionableInfo/required',
      (_) => _page,
      act: _show((_) => FrostToast.actionableInfo('Item removed', actionLabel: 'Undo', onAction: _noop)),
      envs: themes,
    ),
    BaselineCase('FrostToast.warning/required', (_) => _page, act: _show((_) => FrostToast.warning('Low storage')), envs: themes),
    BaselineCase('FrostToast.copied/required', (_) => _page, act: _copied, envs: [BaselineEnv.standard, BaselineEnv.touch]),
    BaselineCase('FrostToast.success/count=2', (_) => _page, act: _showAll(<_Show>[(_) => FrostToast.success('Saved'), (_) => FrostToast.success('Saved')])),
    BaselineCase(
      'FrostToast/stack',
      (_) => _page,
      act: _showAll(<_Show>[(_) => FrostToast.success('Saved'), (_) => FrostToast.info('Syncing'), (_) => FrostToast.warning('Low storage')]),
      envs: [BaselineEnv.standard, BaselineEnv.touch],
    ),
    BaselineCase('FrostToast/stack#hover', (_) => _page, act: _stackHover),
    BaselineCase(
      'FrostToast.success/required#hover',
      (_) => _page,
      act: (tester, subject) async {
        FrostToast.success('Saved');
        await tester.pump(const Duration(milliseconds: 600));
        await _hoverToast(tester, subject);
      },
    ),
  ]);
}
