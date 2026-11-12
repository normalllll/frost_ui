import 'package:flutter/widgets.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../feedback/_skeleton_geometry.dart';
import '../foundation/metrics.dart';
import 'layout_crossfade.dart';
import 'spring.dart';

/// A count whose changed characters roll to their new value, upward when
/// the number grows and downward when it shrinks.
/// Characters are matched from the right, so 9 → 10 rolls the ones digit and
/// adds the tens while the width eases over. With reduced motion the text is
/// replaced at once.
class FrostRollingText extends StatefulWidget {
  const FrostRollingText(this.text, {this.style, super.key});

  final String text;
  final TextStyle? style;

  @override
  State<FrostRollingText> createState() => _FrostRollingTextState();
}

class _FrostRollingTextState extends State<FrostRollingText> {
  /// 1 when the count grew (new characters come from below), -1 when it shrank.
  double _direction = 1;

  static final _rightToLeftScript = RegExp('[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]');

  static final _quantity = RegExp(r'^\D*?(\d[\d,]*(?:\.\d+)?)\s*([kKmMbB千万亿]?)\D*$');
  static const _units = {'k': 1e3, 'K': 1e3, '千': 1e3, '万': 1e4, 'm': 1e6, 'M': 1e6, '亿': 1e8, 'b': 1e9, 'B': 1e9};

  // A count such as 1.0万 reads with its decimal and unit. Anything else, such
  // as a clock, compares as the digits in order.
  static double? _valueOf(String text) {
    if (_quantity.firstMatch(text) case final match?) {
      return double.parse(match[1]!.replaceAll(',', '')) * (_units[match[2]] ?? 1);
    }
    return double.tryParse(text.replaceAll(RegExp(r'\D'), ''));
  }

  @override
  void didUpdateWidget(FrostRollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text == oldWidget.text) return;
    if ((_valueOf(oldWidget.text), _valueOf(widget.text)) case (final before?, final after?)) {
      _direction = after >= before ? 1 : -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Skeletonizer.maybeOf(context)?.enabled == true) {
      return FrostSkeletonText(child: Text(widget.text, style: widget.style));
    }
    // Slots cannot shape or reorder right-to-left script, so that text stands whole.
    if (_rightToLeftScript.hasMatch(widget.text)) return Text(widget.text, style: widget.style);
    final characters = widget.text.characters.toList();
    final duration = FrostMotion.duration(context, FrostMotion.expand);
    final curve = FrostSpringCurve(FrostMotion.snappy, FrostMotion.expand);
    return Semantics(
      label: widget.text,
      excludeSemantics: true,
      child: FrostMotionSize(
        duration: duration,
        curve: curve,
        // Slots keep their place from the right, so the ones digit holds still.
        alignment: Alignment.centerRight,
        child: Row(
          // Digits and separators read left to right in every text direction.
          textDirection: TextDirection.ltr,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < characters.length; index++)
              ClipRect(
                // Slots are keyed from the right so digits keep their place value.
                key: ValueKey(characters.length - index),
                child: AnimatedSwitcher(
                  duration: duration,
                  switchInCurve: curve,
                  switchOutCurve: Curves.easeIn,
                  layoutBuilder: (current, previous) => Stack(alignment: Alignment.center, children: [...previous, ?current]),
                  transitionBuilder: (child, animation) {
                    final incoming = child.key == ValueKey(characters[index]);
                    final from = Offset(0, incoming ? _direction : -_direction);
                    return SlideTransition(
                      position: animation.drive(Tween(begin: from, end: Offset.zero)),
                      child: child,
                    );
                  },
                  child: FrostSkeletonText(
                    key: ValueKey(characters[index]),
                    child: Text(characters[index], key: ValueKey(characters[index]), style: widget.style),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
