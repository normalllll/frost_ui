import 'package:flutter/material.dart';
import 'package:frost_ui/src/controls/icon.dart';
import 'package:frost_ui/src/foundation/metrics.dart';
import 'package:frost_ui/src/layout/column_placement.dart';
import 'package:frost_ui/src/foundation/scope.dart';
import 'package:frost_ui/src/layout/window_caption_scope.dart';
import 'package:frost_ui/src/navigation/shell_navigation_scope.dart';

/// A page header whose back action belongs to the shell when it is visible.
class FrostPageHeader extends StatelessWidget implements PreferredSizeWidget {
  const FrostPageHeader({required this.title, this.actions, this.onBack, super.key});

  final Widget title;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  /// Width of the leading slot around [FrostCompactBackButton]; its arrow then
  /// sits on the phone page inset instead of 16 in.
  static const leadingWidth = FrostCompactBackButton.width + 4;

  /// Gap between a compact back button and the title.
  static const titleSpacingAfterBack = 8.0;

  /// The title spacing for a header built around [leadingFor]: tight after
  /// the compact back button, the toolbar default without one.
  static double? titleSpacingOf(BuildContext context, {VoidCallback? onBack}) => leadingFor(context, onBack: onBack) == null ? null : titleSpacingAfterBack;

  /// Use with a sliver or a custom header that cannot use [FrostPageHeader].
  static Widget? leadingFor(BuildContext context, {VoidCallback? onBack}) {
    final navigation = FrostShellNavigationScope.maybeOf(context);
    if (navigation?.ownsBackControl ?? false) return null;
    if (navigation != null) {
      return navigation.canGoBack ? FrostCompactBackButton(onPressed: navigation.goBack) : null;
    }
    if (onBack != null) return FrostCompactBackButton(onPressed: onBack);
    if (Navigator.of(context).canPop()) return FrostCompactBackButton(onPressed: () => Navigator.of(context).maybePop());
    return null;
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final leading = leadingFor(context, onBack: onBack);
    return AppBar(
      automaticallyImplyLeading: false,
      leading: leading,
      leadingWidth: leadingWidth,
      titleSpacing: leading == null ? null : titleSpacingAfterBack,
      title: title,
      actions: actions,
    );
  }
}

/// The back control on phone headers. Most people go back with the system
/// gesture, so it is drawn compact: a 40-wide target instead of Material's
/// 48 plus leading padding, leaving the width to the title or the search
/// field beside it. It keeps a full-height target and the platform tooltip.
class FrostCompactBackButton extends StatelessWidget {
  const FrostCompactBackButton({required this.onPressed, super.key});

  static const width = 40.0;

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: FrostScope.labelsOf(context).back,
      onPressed: onPressed,
      icon: FrostIcon(FrostIconSet.of(context).back, size: 22),
      style: IconButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(width, 44),
        fixedSize: const Size(width, 44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

/// Whether the page's title already shows in the window's own caption bar
/// (the Flutter-drawn Windows caption, see [FrostWindowCaptionScope]).
/// Everywhere else the page shows its own header.
bool frostWindowCaptionShowsPageTitle(BuildContext context, {required bool useHorizontalLayout}) =>
    useHorizontalLayout && Theme.of(context).platform == TargetPlatform.windows && FrostWindowCaptionScope.showsPageTitle(context);

/// The heading of a page in the sidebar layout: a large title directly on the
/// backdrop, in the same column as the content below it. Phones use
/// [FrostPageHeader] instead.
class FrostInlinePageHeading extends StatelessWidget {
  const FrostInlinePageHeading({required this.title, this.actions = const [], this.maxWidth = FrostMetrics.contentMaxWidth, super.key});

  final String title;

  /// The content column the heading lines up with.
  final double maxWidth;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final column = FrostColumnPlacement.columnPadding(context, constraints.maxWidth, maxWidth: maxWidth);
        return Padding(
          padding: EdgeInsets.fromLTRB(column.left, FrostMetrics.sectionHeadingGap, column.right - (actions.isEmpty ? 0 : 8), 0),
          child: Row(
            children: [
              Expanded(
                child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge),
              ),
              ...actions,
            ],
          ),
        );
      },
    );
  }
}
