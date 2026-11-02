import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/media.dart';

import 'baseline.dart';

const _picture = SizedBox(width: 160, height: 90, child: ColoredBox(color: Color(0xFF5577AA)));

void main() {
  baselineGroup('FrostMediaImage', [
    // Outside a card the wrapper has no visual effect.
    const BaselineCase('FrostMediaImage/required', _required),
    // Inside a card it marks the displayed image.
    BaselineCase(
      'FrostMediaImage/required+inMediaCard',
      (_) => const SizedBox(
        width: 220,
        child: FrostMediaCard(
          media: FrostMediaFrame(
            aspectRatio: 16 / 9,
            child: FrostMediaImage(child: _picture),
          ),
          title: 'Title',
        ),
      ),
    ),
  ]);
}

Widget _required(BuildContext context) => const FrostMediaImage(child: _picture);
