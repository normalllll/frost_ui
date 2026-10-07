import 'package:frost_ui/src/foundation/metrics.dart';
import 'package:flutter/material.dart';
import 'package:frost_ui/src/foundation/scope.dart';
import 'package:frost_ui/src/controls/icon.dart';
import 'package:frost_ui/src/layout/content_viewport.dart';
import 'package:frost_ui/src/foundation/tokens.dart';

/// Shared search chrome; each service owns its query and optional controls.
class FrostSearchInput extends StatelessWidget {
  const FrostSearchInput({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onSubmitted,
    this.onClear,
    this.field,
    this.actions = const [],
    this.leadingIcon = false,
    this.submitButton = true,
    super.key,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final ValueChanged<String> onSubmitted;
  final VoidCallback? onClear;
  final Widget? field;
  final List<Widget> actions;

  /// Shows the search glyph before the text, marking the field as search.
  final bool leadingIcon;

  /// Shows a trailing search button; without it Enter submits.
  final bool submitButton;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, focusNode]),
    builder: (context, _) {
      final colors = Theme.of(context).colorScheme;
      final focus = FrostThemeTokens.of(context).fieldFocus;
      final size = FrostMetrics.fieldHeight(context);
      final radius = BorderRadius.circular(FrostMetrics.controlRadius);
      // The outline is an unclipped foreground stroke inside the field's
      // edge. Clipping a stroked shape cuts its outer half and lets the fill
      // bleed through the antialiased corner, which reads as jagged.
      return AnimatedContainer(
        duration: FrostMotion.duration(context, FrostMotion.hover),
        decoration: BoxDecoration(color: FrostThemeTokens.of(context).surfaceRaised, borderRadius: radius),
        foregroundDecoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: focusNode.hasFocus ? focus : colors.outlineVariant,
            width: focusNode.hasFocus ? FrostMetrics.fieldFocusWidth : 1,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: SizedBox(
          height: size,
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(leadingIcon ? 12 : 10, 0, 2, 0),
            child: Row(
              children: [
                if (leadingIcon) ...[FrostIcon(FrostIconSet.of(context).search, size: 18, color: colors.onSurfaceVariant), const SizedBox(width: 10)],
                Expanded(
                  child:
                      field ??
                      TextField(
                        controller: controller,
                        focusNode: focusNode,
                        onSubmitted: onSubmitted,
                        onTapOutside: (_) => focusNode.unfocus(),
                        textInputAction: TextInputAction.search,
                        style: Theme.of(context).textTheme.bodyMedium,
                        decoration: frostSearchInputDecoration(context, hintText),
                      ),
                ),
                Visibility(
                  visible: controller.text.isNotEmpty,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: SizedBox.square(
                    dimension: size,
                    child: IconButton(
                      tooltip: FrostScope.labelsOf(context).clearText,
                      onPressed: onClear ?? controller.clear,
                      icon: FrostIcon(FrostIconSet.of(context).close, size: 18),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
                for (final action in actions) SizedBox.square(dimension: size, child: action),
                if (submitButton)
                  SizedBox.square(
                    dimension: size,
                    child: IconButton(
                      tooltip: FrostScope.labelsOf(context).search,
                      onPressed: controller.text.trim().isEmpty ? null : () => onSubmitted(controller.text),
                      icon: FrostIcon(FrostIconSet.of(context).search, size: 18),
                      padding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

InputDecoration frostSearchInputDecoration(BuildContext context, String hint) => InputDecoration(
  isDense: true,
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
  disabledBorder: InputBorder.none,
  errorBorder: InputBorder.none,
  focusedErrorBorder: InputBorder.none,
  filled: false,
  contentPadding: EdgeInsets.zero,
  hintText: hint,
  hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
);

/// Centres the search row in the page column it belongs to, with the same
/// gap above and below so it never sits on the edge of its bar.
class FrostSearchInputRegion extends StatelessWidget {
  const FrostSearchInputRegion({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => FrostContentColumn(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: FrostMetrics.compactGap),
      child: child,
    ),
  );
}
