import 'package:flutter/widgets.dart';

import '../foundation/spacing.dart';
import '_column_split.dart';
import '_content_padding.dart';
import '_local_back.dart';
import 'navigation_column_row.dart';

/// The selection of a [FrostNavigationColumnLayout] as a routed page, shown
/// instead of the column when the panes cannot fit.
@immutable
class FrostNavigationColumnPage {
  const FrostNavigationColumnPage({required this.child, required this.onClose});

  /// The page with its own header, which replaces the layout's header.
  final Widget child;

  /// Closes the page and returns to the column. The shell's Back, system back
  /// and the page header's Back (when the shell does not own Back) call it
  /// only while the page shows; wide layouts leave Back to the app's routes.
  final VoidCallback onClose;
}

/// A navigation column beside content, with the wide geometry of
/// [FrostSettingsSections]: a column of 22% of the width held between 236 and
/// 320 points, a hairline, a 32-point gap to the content keyline and a content
/// limit of 640 points that grows to 800 between widths of 1200 and 1600. The
/// app builds the column, such as a list of repositories, and the content of
/// its selection.
///
/// Narrow space gives the column the full width, or shows [compactPage] when
/// the selection is open as a routed page. [content] is first built on a wide
/// layout and stays mounted while the layout narrows. Supply a finite height.
class FrostNavigationColumnLayout extends StatefulWidget {
  const FrostNavigationColumnLayout({required this.navigationBuilder, required this.content, this.header, this.compactPage, super.key});

  /// Builds the column; on narrow layouts it fills the width.
  final WidgetBuilder navigationBuilder;

  /// The selection's content on wide layouts.
  final Widget content;

  /// Shared page chrome above the column and the content.
  final Widget? header;

  /// The selection as a routed page on narrow layouts.
  final FrostNavigationColumnPage? compactPage;

  /// Whether the nearest layout shows the column beside the content (true) or
  /// gives it the full width (false). Widgets that read it, such as the column
  /// builder, rebuild when the layout crosses the threshold; only Frost decides
  /// where that is. Needs a [FrostNavigationColumnLayout] above [context].
  static bool isWideOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_ColumnSplitScope>();
    assert(scope != null, 'FrostNavigationColumnLayout.isWideOf called with no FrostNavigationColumnLayout above the context.');
    return scope?.wide ?? false;
  }

  @override
  State<FrostNavigationColumnLayout> createState() => _NavigationColumnLayoutState();
}

/// The layout's current split, for the column and the content below it.
class _ColumnSplitScope extends InheritedWidget {
  const _ColumnSplitScope({required this.wide, required super.child});
  final bool wide;
  @override
  bool updateShouldNotify(_ColumnSplitScope oldWidget) => wide != oldWidget.wide;
}

class _NavigationColumnLayoutState extends State<FrostNavigationColumnLayout> {
  bool _builtContent = false;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = frostColumnSplitIsWide(context, constraints.maxWidth);
      _builtContent |= wide;
      final page = wide ? null : widget.compactPage;
      return _ColumnSplitScope(
        wide: wide,
        child: FrostLocalBack(
          onClose: page?.onClose,
          child: FrostColumnBody(
            wide: wide,
            retainsPanes: true,
            header: widget.header,
            narrowPage: page == null ? null : FrostLocalBack.header(context, page.onClose, page.child),
            panes: FrostColumnPanes(
              wide: wide,
              width: constraints.maxWidth,
              navigation: FrostNavigationColumnFocus(
                // Wide columns put their keyline on the row text line, inside the
                // list's own inset, as the settings section list does; narrow
                // ones keep the page keyline. One structure keeps the column's
                // state across the change.
                child: FrostContentPadding(
                  padding: wide ? const EdgeInsetsDirectional.only(start: FrostGap.related + frostNavigationRowTextStart, end: FrostGap.related) : null,
                  child: Builder(builder: widget.navigationBuilder),
                ),
              ),
              content: _builtContent ? widget.content : null,
            ),
          ),
        ),
      );
    },
  );
}
