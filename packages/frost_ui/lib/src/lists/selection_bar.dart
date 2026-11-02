import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../controls/_button_control.dart';
import '../controls/_button_types.dart';
import '../controls/buttons.dart';
import '../foundation/density.dart';
import '../foundation/icon_data.dart';
import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../layout/content_viewport.dart';
import '../motion/_material_reveal.dart';
import '../motion/rolling_text.dart';
import '../primitives/_inline_or_below.dart';
import '../primitives/_measured_layout_builder.dart';
import '../primitives/_spaced_wrap.dart';
import '../primitives/divider.dart';
import '../primitives/surface.dart';
import '../primitives/text.dart';
import 'selection.dart';

@immutable
class FrostSelectionAction {
  const FrostSelectionAction({required this.label, required this.icon, required this.onPressed, this.destructive = false});
  final String label;
  final FrostIconData icon;
  final VoidCallback? onPressed;
  final bool destructive;
}

/// A full-width bottom slot which occupies its actual animated height.
/// Place after an Expanded scroll view in a Column, keeping the scroll view's
/// key/controller stable. The shrinking viewport preserves its scroll offset
/// and lets its final item scroll above the bar. In a Stack, the caller must
/// reserve equivalent space; this widget does not report height after layout.
class FrostSelectionBar<T> extends StatelessWidget {
  const FrostSelectionBar({required this.selection, required this.allItems, this.actions = const [], super.key});
  final FrostSelection<T> selection;
  final Iterable<T> allItems;
  final List<FrostSelectionAction> actions;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: selection,
    builder: (context, _) {
      final labels = FrostScope.labelsOf(context);
      final all = allItems.toSet();
      return _SelectionBarVisibility(
        visible: selection.active,
        child: Focus(
          canRequestFocus: false,
          onKeyEvent: (_, event) {
            if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape && selection.active) {
              selection.exit();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            child: FrostSurface(
              role: FrostSurfaceRole.chrome,
              borderRadius: BorderRadius.zero,
              edge: FrostSurfaceEdge.none,
              elevated: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FrostDivider(),
                  SafeArea(
                    top: false,
                    child: FrostContentColumn(
                      maxWidth: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: FrostGap.related),
                        child: FrostInlineOrBelow(
                          direction: Directionality.of(context),
                          gap: FrostGap.related,
                          measuresEndAtWidth: false,
                          start: FrostSpacedWrap(
                            spacing: FrostGap.group,
                            runSpacing: FrostGap.related,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _SelectionCount(labels.selectedCount(selection.selected.length)),
                              FrostButtonControl(
                                label: labels.selectAll,
                                variant: FrostButtonVariant.plain,
                                // This is a neighbour of the count, not a keyline
                                // edge: keep its visible label exactly one group gap away.
                                geometry: FrostButtonGeometry(
                                  horizontalInset: 0,
                                  verticalInset: 0,
                                  minimumWidth: FrostDensity.of(context).targetHeight,
                                  alignment: MainAxisAlignment.start,
                                ),
                                onPressed: all.every(selection.isSelected) ? null : () => selection.selectAll(all),
                              ),
                            ],
                          ),
                          end: FrostSpacedWrap(
                            spacing: FrostGap.group,
                            runSpacing: FrostGap.related,
                            alignment: WrapAlignment.end,
                            children: [
                              for (final action in actions)
                                FrostButton.plain(
                                  label: action.label,
                                  icon: action.icon,
                                  role: action.destructive ? FrostButtonRole.destructive : FrostButtonRole.normal,
                                  onPressed: selection.selected.isEmpty ? null : action.onPressed,
                                ),
                              FrostButton.plain(label: labels.done, onPressed: selection.exit),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _SelectionBarVisibility extends StatefulWidget {
  const _SelectionBarVisibility({required this.visible, required this.child});
  final bool visible;
  final Widget child;
  @override
  State<_SelectionBarVisibility> createState() => _SelectionBarVisibilityState();
}

class _SelectionBarVisibilityState extends State<_SelectionBarVisibility> with SingleTickerProviderStateMixin {
  late final _progress = AnimationController.unbounded(vsync: this, value: widget.visible ? 1 : 0);
  final _glass = FrostRevealHandle();
  void _animate() {
    if (widget.visible) {
      _glass.cancelClose();
    } else if (_glass.hasNestedGlass && _glass.nestedProgress > 0) {
      _glass.prepareClose().then((ready) {
        if (ready && mounted && !widget.visible) _startAnimation();
      });
      return;
    }
    _startAnimation();
  }

  void _startAnimation() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _progress.animateTo(widget.visible ? 1 : 0, duration: FrostMotion.reducedFade);
    } else {
      FrostMotion.springTo(context, _progress, widget.visible ? 1 : 0, FrostMotion.standard);
    }
  }

  @override
  void didUpdateWidget(_SelectionBarVisibility oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) _animate();
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _progress,
    child: widget.child,
    builder: (context, child) {
      final progress = _progress.value.clamp(0.0, 1.0);
      if (progress == 0 && !widget.visible) return const SizedBox.shrink();
      final reduced = MediaQuery.disableAnimationsOf(context);
      return ClipRect(
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: reduced ? 1 : progress,
          child: FractionalTranslation(
            translation: Offset(0, reduced ? 0 : 1 - progress),
            child: FrostMaterialReveal(
              handle: _glass,
              opacity: progress,
              child: IgnorePointer(
                ignoring: !widget.visible,
                child: ExcludeFocus(
                  excluding: !widget.visible,
                  child: ExcludeSemantics(excluding: !widget.visible, child: child!),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Counts roll when they fit; unusually long translations wrap at full size.
class _SelectionCount extends StatelessWidget {
  const _SelectionCount(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final style = FrostTypography.of(context).style(FrostTextRole.callout, tabular: true).copyWith(color: FrostThemeTokens.of(context).textSecondary);
    final line = frostTextLineSize(context, text, style);
    return Semantics(
      liveRegion: true,
      label: text,
      excludeSemantics: true,
      child: FrostMeasuredLayoutBuilder(
        naturalSize: line,
        builder: (context, constraints) => line.width <= constraints.maxWidth
            ? FrostRollingText(text, style: style)
            : FrostText(text, role: FrostTextRole.callout, tone: FrostTextTone.secondary, tabular: true),
      ),
    );
  }
}
