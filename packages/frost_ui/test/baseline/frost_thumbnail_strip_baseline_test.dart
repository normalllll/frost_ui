import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _select(int index) {}

Widget _item(BuildContext context, int index) => ColoredBox(
  color: Color(0xFF334455 + index * 0x00101010),
  child: Center(child: FrostText('$index', tone: FrostTextTone.primary)),
);

Widget _strip({int itemCount = 12, int? selectedIndex = 0, ValueChanged<int>? onSelected = _select, FrostThumbnailSize? size}) => SizedBox(
  height: 120,
  child: FrostThumbnailStrip(
    itemCount: itemCount,
    itemBuilder: _item,
    selectedIndex: selectedIndex,
    onSelected: onSelected,
    size: size ?? FrostThumbnailSize.regular,
  ),
);

void main() {
  baselineGroup('FrostThumbnailStrip', [
    BaselineCase('FrostThumbnailStrip/required', (_) => _strip(), envs: [...BaselineEnv.themes, BaselineEnv.narrow, BaselineEnv.touch]),
    BaselineCase('FrostThumbnailStrip/selectedIndex=null', (_) => _strip(selectedIndex: null)),
    // An offscreen selection is revealed with the smallest movement.
    BaselineCase('FrostThumbnailStrip/selectedIndex=9', (_) => _strip(selectedIndex: 9), envs: [BaselineEnv.standard, BaselineEnv.narrow]),
    BaselineCase('FrostThumbnailStrip/onSelected=null', (_) => _strip(onSelected: null)),
    for (final size in FrostThumbnailSize.values)
      BaselineCase('FrostThumbnailStrip/size=${size.name}', (_) => _strip(size: size), envs: [BaselineEnv.standard, BaselineEnv.narrow]),
    BaselineCase('FrostThumbnailStrip/itemCount=0', (_) => _strip(itemCount: 0, selectedIndex: null)),
    BaselineCase('FrostThumbnailStrip/itemCount=3', (_) => _strip(itemCount: 3, selectedIndex: 1)),
    BaselineCase('FrostThumbnailStrip/required#focus', (_) => _strip(), act: baselineFocus),
  ]);
}
