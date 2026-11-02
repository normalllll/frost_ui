import 'package:flutter/widgets.dart';

import '../controls/buttons.dart';
import '../foundation/icon_data.dart';
import '../foundation/spacing.dart';
import '../foundation/typography.dart';
import '../lists/_row_scope.dart';
import '../lists/list_row.dart';
import '../overlays/_modal_frame.dart';
import '../overlays/adaptive_panel.dart';
import '../overlays/dialogs.dart';
import '../overlays/sheet.dart';
import '../primitives/glyph.dart';
import '_tab_brand.dart';
import 'tabs.dart';

// Shared caption budget and strip limits must agree: minimum decides folding,
// maximum limits growth once the remaining caption width has been consumed.
const frostShellTabMinWidth = 112.0;
const frostShellTabMaxWidth = 220.0;

// The caption's base button remains visible; its folded menu contains content.
Future<void> showFrostContentTabs(BuildContext context, FrostShellTabs<Object> tabs) => tabs._showOverview(context, contentOnly: true);

/// Shell presentation of an App-owned tab controller. App supplies localized
/// labels and tab identities; this object never reads or writes saved data.
class FrostShellTabs<T extends Object> {
  const FrostShellTabs({
    required this.controller,
    required this.label,
    required this.countLabel,
    required this.closeTooltip,
    required this.newTabTooltip,
    this.onNewTab,
    this.sidebarLabel,
  });
  final FrostTabsController<T> controller;
  final FrostTabLabel Function(BuildContext context, T tab) label;
  final String Function(int count) countLabel;
  final String Function(int count)? sidebarLabel;
  final String closeTooltip, newTabTooltip;
  final VoidCallback? onNewTab;

  bool get hasVisibleTabs => controller.baseTab != null || controller.length > 1;

  bool get canCreateTab => controller.baseTab == null && onNewTab != null;

  Widget strip(BuildContext context) => FrostTabStrip<T>(
    controller: controller,
    label: (context, tab) {
      final value = label(context, tab);
      final brand = FrostTabBrand.maybeOf(context);
      return tab != controller.baseTab || brand == null ? value : FrostTabLabel(title: brand.label(value.title), leading: brand.icon);
    },
    closeTooltip: closeTooltip,
    newTabTooltip: newTabTooltip,
    newTabIcon: FrostIconSet.of(context).add,
    onNewTab: onNewTab,
    minTabWidth: frostShellTabMinWidth,
    maxTabWidth: frostShellTabMaxWidth,
  );

  Future<void> showOverview(BuildContext context) => _showOverview(context);

  Future<void> _showOverview(BuildContext context, {bool contentOnly = false}) {
    final brand = FrostTabBrand.maybeOf(context);
    Widget overview(BuildContext context) => _overview(context, brand: brand, contentOnly: contentOnly);
    if (!frostPanelUsesSheet(context)) {
      return showFrostDialog<void>(
        context: context,
        builder: (context) => FrostModalSurface(width: 720, child: FrostModalFrame(content: overview(context))),
      );
    }
    return showFrostSheet<void>(
      context: context,
      showsCloseButton: false,
      presentation: FrostSheetPresentation.bottom,
      detents: const [FrostSheetDetent.fitted],
      builder: overview,
    );
  }

  Widget _overview(BuildContext context, {FrostTabBrand? brand, required bool contentOnly}) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Keep the localized count live when a tab closes in this overview.
        FrostModalHeader(
          title: countLabel(controller.length - (contentOnly && controller.baseTab != null ? 1 : 0)),
          role: FrostTextRole.headline,
          showsCloseButton: true,
        ),
        const SizedBox(height: FrostGap.group),
        for (final (index, tab) in controller.tabs.indexed)
          if (!contentOnly || tab != controller.baseTab)
            _inlineValue(
              controller.baseTab != null,
              FrostListRow(
                title: label(context, tab).title,
                leading: switch (tab == controller.baseTab && brand != null
                    ? brand.icon
                    : controller.baseTab == null
                    ? null
                    : label(context, tab).leading) {
                  null => null,
                  final leading => FrostLeading.custom(leading),
                },
                selected: controller.activeIndex == index,
                onPressed: () {
                  controller.activate(index);
                  Navigator.of(context).pop();
                },
                trailing: tab == controller.baseTab
                    ? null
                    : FrostButton.icon(
                        icon: FrostIconSet.of(context).close,
                        label: closeTooltip,
                        onPressed: controller.canClose(index) ? () => controller.close(index) : null,
                      ),
              ),
            ),
        if (canCreateTab)
          FrostButton(
            label: newTabTooltip,
            icon: FrostIconSet.of(context).add,
            onPressed: () {
              Navigator.of(context).pop();
              onNewTab!();
            },
          ),
      ],
    ),
  );
}

// A tab's close action stays at the end even when its title wraps.
Widget _inlineValue(bool inline, Widget row) => inline ? FrostRowInlineValue(child: row) : row;
