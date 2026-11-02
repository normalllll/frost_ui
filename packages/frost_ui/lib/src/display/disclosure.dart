import 'package:flutter/widgets.dart';

import '../foundation/_control_geometry.dart';
import '../foundation/control_scope.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../primitives/_directional_icon.dart';
import '../primitives/click_surface.dart';
import '../primitives/icon.dart';
import '../primitives/keyline.dart';
import '../primitives/text.dart';
import '_disclosure_body.dart';

class FrostDisclosure extends StatefulWidget {
  const FrostDisclosure({required this.title, required this.child, this.initiallyExpanded = false, this.expanded, this.onExpansionChanged, super.key});
  final String title;
  final Widget child;
  final bool initiallyExpanded;
  final bool? expanded;
  final ValueChanged<bool>? onExpansionChanged;
  // A quiet toggle reads as secondary text inside a row instead of a heading.
  bool get _quiet => false;
  @override
  State<FrostDisclosure> createState() => _DisclosureState();
}

/// A [FrostDisclosure] whose toggle is secondary footnote text, for details
/// inside a list row or message. Internal: Apps reach it through components
/// that compose it, such as [FrostErrorDetails.quiet].
class FrostQuietDisclosure extends FrostDisclosure {
  const FrostQuietDisclosure({required super.title, required super.child, super.initiallyExpanded, super.key});
  @override
  bool get _quiet => true;
}

class _DisclosureState extends State<FrostDisclosure> {
  late bool _expanded = widget.initiallyExpanded;

  bool get expanded => widget.expanded ?? _expanded;
  bool get enabled => (widget.expanded == null || widget.onExpansionChanged != null) && FrostControlScope.enabledOf(context);
  @override
  void didUpdateWidget(FrostDisclosure oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded != null && widget.expanded == null) _expanded = oldWidget.expanded!;
  }

  void _toggle() {
    final next = !expanded;
    if (widget.expanded == null) setState(() => _expanded = next);
    widget.onExpansionChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final quiet = widget._quiet;
    final role = quiet ? FrostTextRole.footnote : FrostTextRole.headline;
    final geometry = frostControlGeometry(context, quiet ? FrostControlSize.compact : FrostControlSize.regular, role: role);
    final turns = frostDisclosureTurns(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FrostBleed(
          amount: FrostGap.of(context).hitInset,
          child: Builder(
            builder: (context) => Semantics(
              label: widget.title,
              button: true,
              expanded: expanded,
              enabled: enabled,
              onTap: enabled ? _toggle : null,
              excludeSemantics: true,
              child: FrostClickSurface(
                onTap: enabled ? _toggle : null,
                feedback: quiet ? FrostClickFeedback.quiet : FrostClickFeedback.surface,
                shape: FrostClickShape.rounded(FrostRadius.borderRadius(FrostRadius.sm)),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: geometry.height),
                  child: Padding(
                    padding: frostBleedOutsetsOf(context).add(EdgeInsets.symmetric(vertical: geometry.verticalInset)),
                    child: Row(
                      children: [
                        Expanded(
                          child: FrostText(widget.title, role: role, tone: quiet ? FrostTextTone.secondary : FrostTextTone.primary, tabular: true),
                        ),
                        const SizedBox(width: FrostGap.related),
                        AnimatedRotation(
                          turns: expanded ? turns : 0,
                          duration: FrostMotion.duration(context, FrostMotion.feedback),
                          curve: FrostMotion.hoverCurve,
                          child: FrostIcon(
                            frostTrailingChevron(context),
                            size: FrostControlSize.compact.iconSize,
                            color: FrostThemeTokens.of(context).textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        FrostDisclosureBody(expanded: expanded, gap: FrostGap.related, child: widget.child),
      ],
    );
  }
}
