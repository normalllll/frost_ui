import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Library-only: the free stretch of a page header's toolbar row, between its
/// leading content and its trailing cluster, written during each toolbar
/// layout. A template that holds section tabs places them there when they fit.
class FrostHeaderRowSpan {
  /// The toolbar row the span is measured in.
  RenderBox? box;

  /// Every item kept its full form: nothing folded, hidden or truncated.
  bool full = false;

  /// Physical x range of the free stretch in [box] coordinates.
  double start = 0, end = 0;

  /// Height of [box], read without reaching into another render object.
  double height = 0;

  /// Whether content precedes / follows the stretch in reading order.
  bool contentBefore = false, contentAfter = false;

  /// The header's search covers its row, which then stays shown.
  bool searchExpanded = false;

  /// Set by the template; called when a toolbar layout or the header's search
  /// changes the span outside the template's own layout.
  VoidCallback? onChanged;

  void report({
    required RenderBox box,
    required bool full,
    required double start,
    required double end,
    required double height,
    required bool contentBefore,
    required bool contentAfter,
  }) {
    if (identical(this.box, box) &&
        this.full == full &&
        this.start == start &&
        this.end == end &&
        this.height == height &&
        this.contentBefore == contentBefore &&
        this.contentAfter == contentAfter) {
      return;
    }
    this.box = box;
    this.full = full;
    this.start = start;
    this.end = end;
    this.height = height;
    this.contentBefore = contentBefore;
    this.contentAfter = contentAfter;
    onChanged?.call();
  }

  set expanded(bool value) {
    if (searchExpanded == value) return;
    searchExpanded = value;
    onChanged?.call();
  }

  /// Whether a change reported now arrives during a layout pass, when the
  /// template must not be marked dirty until the frame ends.
  static bool get duringLayout => SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks;
}

class FrostHeaderRowSpanScope extends InheritedWidget {
  const FrostHeaderRowSpanScope({required this.span, required super.child, super.key});
  final FrostHeaderRowSpan span;

  static FrostHeaderRowSpan? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostHeaderRowSpanScope>()?.span;

  /// For event handlers, without a build dependency.
  static FrostHeaderRowSpan? read(BuildContext context) => context.getInheritedWidgetOfExactType<FrostHeaderRowSpanScope>()?.span;
  @override
  bool updateShouldNotify(FrostHeaderRowSpanScope oldWidget) => span != oldWidget.span;
}
