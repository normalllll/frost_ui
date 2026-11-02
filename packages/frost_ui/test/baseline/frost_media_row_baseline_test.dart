import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/media.dart';

import 'baseline.dart';

void _noop() {}

const _media = FrostMediaImage(child: ColoredBox(color: Color(0xFF5577AA)));
const _title = 'A media title long enough to occupy at most two lines of the row';
const _overlay = FrostText('12:48');
const _badge = DecoratedBox(
  decoration: BoxDecoration(color: Color(0xAA000000)),
  child: SizedBox(width: 28, height: 20, child: FrostText('B', tone: FrostTextTone.primary)),
);
const _mark = SizedBox(width: 12, height: 12, child: ColoredBox(color: Color(0xFFCC6677)));
final _menu = [FrostMenuAction('Queue', onSelected: _noop), FrostMenuAction('Remove', onSelected: _noop)];

Future<void> _rightClick(WidgetTester tester, Finder subject) async {
  final gesture = await tester.startGesture(tester.getCenter(subject), kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
  await gesture.up();
}

void main() {
  baselineGroup('FrostMediaRow', [
    BaselineCase(
      'FrostMediaRow/required',
      (_) => FrostMediaRow(media: _media, title: _title),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostMediaRow/metadata=1',
      (_) => FrostMediaRow(media: _media, title: 'Title', metadata: ['Creator']),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostMediaRow/metadata=2',
      (_) => FrostMediaRow(media: _media, title: 'Title', metadata: ['Creator', 'Updated yesterday']),
      envs: [BaselineEnv.standard, BaselineEnv.narrow],
    ),
    BaselineCase('FrostMediaRow/metadataLeading', (_) => FrostMediaRow(media: _media, title: 'Title', metadata: ['Creator'], metadataLeading: _mark)),
    BaselineCase(
      'FrostMediaRow/overlay',
      (_) => FrostMediaRow(media: _media, title: 'Title', overlay: _overlay),
      envs: BaselineEnv.themes,
    ),
    BaselineCase('FrostMediaRow/topStart', (_) => FrostMediaRow(media: _media, title: 'Title', topStart: _badge)),
    BaselineCase('FrostMediaRow/progress=0.4', (_) => FrostMediaRow(media: _media, title: 'Title', progress: .4)),
    BaselineCase(
      'FrostMediaRow/onPressed',
      (_) => FrostMediaRow(media: _media, title: _title, metadata: ['Creator'], onPressed: _noop),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostMediaRow/onPressed#hover',
      (_) => FrostMediaRow(media: _media, title: 'Title', onPressed: _noop),
      act: baselineHover,
    ),
    BaselineCase(
      'FrostMediaRow/onPressed#press',
      (_) => FrostMediaRow(media: _media, title: 'Title', onPressed: _noop),
      act: baselinePress,
    ),
    BaselineCase(
      'FrostMediaRow/onPressed#focus',
      (_) => FrostMediaRow(media: _media, title: 'Title', onPressed: _noop),
      act: baselineFocus,
    ),
    BaselineCase('FrostMediaRow/onOpenInBackground', (_) => FrostMediaRow(media: _media, title: 'Title', onPressed: _noop, onOpenInBackground: _noop)),
    BaselineCase('FrostMediaRow/onOpenInNewTab', (_) => FrostMediaRow(media: _media, title: 'Title', onPressed: _noop, onOpenInNewTab: _noop)),
    BaselineCase('FrostMediaRow/contextMenu', (_) => FrostMediaRow(media: _media, title: 'Title', onPressed: _noop, contextMenu: _menu)),
    BaselineCase(
      'FrostMediaRow/contextMenu#open',
      (_) => FrostMediaRow(media: _media, title: 'Title', onPressed: _noop, contextMenu: _menu),
      act: _rightClick,
    ),
    BaselineCase(
      'FrostMediaRow/metadata=2+metadataLeading+overlay+topStart+progress',
      (_) => FrostMediaRow(
        media: _media,
        title: _title,
        metadata: ['Creator', 'Updated yesterday'],
        metadataLeading: _mark,
        overlay: _overlay,
        topStart: _badge,
        progress: .5,
        onPressed: _noop,
      ),
      envs: BaselineEnv.themes,
    ),
  ]);
}
