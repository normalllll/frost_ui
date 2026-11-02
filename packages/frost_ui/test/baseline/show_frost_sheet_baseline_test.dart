import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'nav_overlay_support.dart';

Widget _open({
  String? title,
  FrostSheetPresentation presentation = FrostSheetPresentation.adaptive,
  List<FrostSheetDetent> detents = const [FrostSheetDetent.large],
  bool showsCloseButton = true,
  bool barrierDismissible = true,
  bool scrollable = true,
  Widget? content,
}) => launcher(
  (context) => showFrostSheet<Object?>(
    context: context,
    title: title,
    presentation: presentation,
    detents: detents,
    showsCloseButton: showsCloseButton,
    barrierDismissible: barrierDismissible,
    scrollable: scrollable,
    builder: (_) => content ?? body(),
  ),
);

final _long = Column(children: [for (var i = 0; i < 40; i++) Text('Line $i')]);

void main() {
  // Wide windows present the adaptive sheet as a dialog; `-phone` cases run on
  // a 360-wide window where it is a bottom sheet.
  baselineGroup('showFrostSheet', [
    BaselineCase('showFrostSheet/required#open', (_) => _open(), act: tapTrigger, envs: BaselineEnv.themes),
    BaselineCase('showFrostSheet/required#open-phone', (_) => _open(), act: onPhone(tapTrigger), envs: [narrowTouch]),
    BaselineCase('showFrostSheet/title#open', (_) => _open(title: 'Details'), act: tapTrigger),
    BaselineCase(
      'showFrostSheet/title#open-phone',
      (_) => _open(title: 'Details'),
      act: onPhone(tapTrigger),
      envs: [narrowTouch],
    ),
    BaselineCase('showFrostSheet/presentation=bottom#open', (_) => _open(presentation: FrostSheetPresentation.bottom), act: tapTrigger),
    BaselineCase(
      'showFrostSheet/presentation=bottom#open-phone',
      (_) => _open(presentation: FrostSheetPresentation.bottom),
      act: onPhone(tapTrigger),
      envs: [narrowTouch],
    ),
    for (final detent in FrostSheetDetent.values) ...[
      BaselineCase('showFrostSheet/detents=${detent.name}#open', (_) => _open(detents: [detent]), act: tapTrigger),
      BaselineCase(
        'showFrostSheet/detents=${detent.name}#open-phone',
        (_) => _open(detents: [detent]),
        act: onPhone(tapTrigger),
        envs: [narrowTouch],
      ),
    ],
    BaselineCase(
      'showFrostSheet/detents=medium+large#open-phone',
      (_) => _open(detents: const [FrostSheetDetent.medium, FrostSheetDetent.large]),
      act: onPhone(tapTrigger),
      envs: [narrowTouch],
    ),
    BaselineCase('showFrostSheet/showsCloseButton=false#open', (_) => _open(showsCloseButton: false), act: tapTrigger),
    BaselineCase('showFrostSheet/showsCloseButton=false#open-phone', (_) => _open(showsCloseButton: false), act: onPhone(tapTrigger), envs: [narrowTouch]),
    BaselineCase('showFrostSheet/barrierDismissible=false#open-phone', (_) => _open(barrierDismissible: false), act: onPhone(tapTrigger), envs: [narrowTouch]),
    BaselineCase(
      'showFrostSheet/scrollable=false#open',
      (_) => _open(
        scrollable: false,
        content: SizedBox(height: 80, child: ListView(children: const [Text('One')])),
      ),
      act: tapTrigger,
    ),
    BaselineCase(
      'showFrostSheet/scrollable=false#open-phone',
      (_) => _open(
        scrollable: false,
        content: SizedBox(height: 80, child: ListView(children: const [Text('One')])),
      ),
      act: onPhone(tapTrigger),
      envs: [narrowTouch],
    ),
    BaselineCase(
      'showFrostSheet/content=long#open',
      (_) => _open(title: 'Details', content: _long),
      act: tapTrigger,
    ),
    BaselineCase(
      'showFrostSheet/content=long#open-phone',
      (_) => _open(title: 'Details', content: _long),
      act: onPhone(tapTrigger),
      envs: [narrowTouch],
    ),
  ]);
}
