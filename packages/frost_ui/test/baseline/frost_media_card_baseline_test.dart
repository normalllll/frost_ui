import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/media.dart';

import 'baseline.dart';

void _noop() {}

const _media = FrostMediaFrame(
  aspectRatio: 16 / 9,
  child: FrostMediaImage(child: ColoredBox(color: Color(0xFF5577AA))),
);
// Corner slots are app content of a known small size.
const _corner = DecoratedBox(
  decoration: BoxDecoration(color: Color(0xAA000000)),
  child: SizedBox(width: 36, height: 24, child: FrostText('C', tone: FrostTextTone.primary)),
);
const _footer = SizedBox(height: 24, child: FrostText('Footer content', tone: FrostTextTone.primary));
const _metadata = FrostText('Creator · 2 days ago');
const _cover = FrostText('12:48');

// Cards live in a grid: a fixed 220-wide slot.
Widget _slot(Widget card) => SizedBox(width: 220, child: card);

final _menu = [FrostMenuAction('Queue', onSelected: _noop), FrostMenuAction('Remove', onSelected: _noop)];

Future<void> _rightClick(WidgetTester tester, Finder subject) async {
  final gesture = await tester.startGesture(tester.getCenter(subject), kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
  await gesture.up();
}

void main() {
  baselineGroup('FrostMediaCard', [
    BaselineCase('FrostMediaCard/required', (_) => _slot(const FrostMediaCard(media: _media)), envs: BaselineEnv.all),
    BaselineCase('FrostMediaCard/aspectRatio=1', (_) => _slot(const FrostMediaCard(media: _media, aspectRatio: 1))),
    BaselineCase('FrostMediaCard/aspectRatio=0.6', (_) => _slot(const FrostMediaCard(media: _media, aspectRatio: .6))),
    BaselineCase(
      'FrostMediaCard/topStart',
      (_) => _slot(const FrostMediaCard(media: _media, topStart: _corner)),
      envs: BaselineEnv.themes,
    ),
    BaselineCase('FrostMediaCard/topEnd', (_) => _slot(const FrostMediaCard(media: _media, topEnd: _corner))),
    BaselineCase('FrostMediaCard/bottomStart', (_) => _slot(const FrostMediaCard(media: _media, bottomStart: _corner))),
    BaselineCase('FrostMediaCard/bottomEnd', (_) => _slot(const FrostMediaCard(media: _media, bottomEnd: _corner))),
    BaselineCase(
      'FrostMediaCard/topStart+topEnd+bottomStart+bottomEnd',
      (_) => _slot(const FrostMediaCard(media: _media, topStart: _corner, topEnd: _corner, bottomStart: _corner, bottomEnd: _corner)),
    ),
    BaselineCase('FrostMediaCard/footer', (_) => _slot(const FrostMediaCard(media: _media, footer: _footer))),
    BaselineCase(
      'FrostMediaCard/title',
      (_) => _slot(const FrostMediaCard(media: _media, title: 'A title that is long enough to wrap onto a second line')),
      envs: [...BaselineEnv.themes, BaselineEnv.largeText],
    ),
    BaselineCase(
      'FrostMediaCard/title+titleLines=1',
      (_) => _slot(const FrostMediaCard(media: _media, title: 'A title that is long enough to wrap onto a second line', titleLines: 1)),
    ),
    BaselineCase(
      'FrostMediaCard/title+metadata',
      (_) => _slot(const FrostMediaCard(media: _media, title: 'Title', metadata: _metadata)),
      envs: BaselineEnv.themes,
    ),
    BaselineCase('FrostMediaCard/metadata', (_) => _slot(const FrostMediaCard(media: _media, metadata: _metadata))),
    BaselineCase('FrostMediaCard/title+footer', (_) => _slot(const FrostMediaCard(media: _media, title: 'Title', footer: _footer))),
    BaselineCase(
      'FrostMediaCard/overlay',
      (_) => _slot(const FrostMediaCard(media: _media, overlay: _cover)),
      envs: BaselineEnv.themes,
    ),
    BaselineCase('FrostMediaCard/progress=0.4', (_) => _slot(const FrostMediaCard(media: _media, progress: .4))),
    BaselineCase('FrostMediaCard/progress=1.5', (_) => _slot(const FrostMediaCard(media: _media, progress: 1.5))),
    BaselineCase('FrostMediaCard/overlay+progress', (_) => _slot(const FrostMediaCard(media: _media, overlay: _cover, progress: .4))),
    BaselineCase(
      'FrostMediaCard/onPressed',
      (_) => _slot(const FrostMediaCard(media: _media, title: 'Title', onPressed: _noop)),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostMediaCard/onPressed#hover',
      (_) => _slot(const FrostMediaCard(media: _media, title: 'Title', onPressed: _noop)),
      act: baselineHover,
    ),
    BaselineCase(
      'FrostMediaCard/onPressed#press',
      (_) => _slot(const FrostMediaCard(media: _media, title: 'Title', onPressed: _noop)),
      act: baselinePress,
    ),
    BaselineCase(
      'FrostMediaCard/onPressed#focus',
      (_) => _slot(const FrostMediaCard(media: _media, title: 'Title', onPressed: _noop)),
      act: baselineFocus,
    ),
    BaselineCase(
      'FrostMediaCard/onOpenInBackground',
      (_) => _slot(const FrostMediaCard(media: _media, title: 'Title', onPressed: _noop, onOpenInBackground: _noop)),
    ),
    BaselineCase('FrostMediaCard/onOpenInNewTab', (_) => _slot(const FrostMediaCard(media: _media, title: 'Title', onPressed: _noop, onOpenInNewTab: _noop))),
    BaselineCase(
      'FrostMediaCard/selected=false',
      (_) => _slot(const FrostMediaCard(media: _media, title: 'Title', onPressed: _noop, selected: false)),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostMediaCard/selected=true',
      (_) => _slot(const FrostMediaCard(media: _media, title: 'Title', onPressed: _noop, selected: true)),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostMediaCard/selected=true+topEnd',
      (_) => _slot(const FrostMediaCard(media: _media, title: 'Title', onPressed: _noop, selected: true, topEnd: _corner)),
    ),
    BaselineCase('FrostMediaCard/contextMenu', (_) => _slot(FrostMediaCard(media: _media, title: 'Title', onPressed: _noop, contextMenu: _menu))),
    BaselineCase(
      'FrostMediaCard/contextMenu#open',
      (_) => _slot(FrostMediaCard(media: _media, title: 'Title', onPressed: _noop, contextMenu: _menu)),
      act: _rightClick,
    ),
    BaselineCase(
      'FrostMediaCard/semanticLabel',
      (_) => _slot(const FrostMediaCard(media: _media, title: 'Title', onPressed: _noop, semanticLabel: 'Open the work')),
    ),
    BaselineCase('FrostMediaCard.skeleton/required', (_) => _slot(FrostMediaCard.skeleton(aspectRatio: 16 / 9, footer: null)), envs: BaselineEnv.themes),
    BaselineCase('FrostMediaCard.skeleton/footer', (_) => _slot(FrostMediaCard.skeleton(aspectRatio: 16 / 9, footer: 'Loading the title'))),
    BaselineCase('FrostMediaCard.skeleton/aspectRatio=1', (_) => _slot(FrostMediaCard.skeleton(aspectRatio: 1, footer: null))),
    BaselineCase(
      'FrostMediaCard.skeleton/aspectRatio=null',
      (_) => SizedBox(width: 220, height: 160, child: FrostMediaCard.skeleton(aspectRatio: null, footer: null)),
    ),
  ]);
}
