import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../foundation/control_scope.dart';
import '../foundation/density.dart';
import '../foundation/radius.dart';
import '../foundation/sizes.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../lists/_row_scope.dart';
import '../overlays/context_menu.dart';
import '../overlays/menu_entry.dart';
import '../primitives/_click_surface_visuals.dart';
import '../primitives/_measured_layout_builder.dart';
import '../primitives/click_surface.dart';
import '_cover_scrim.dart';
import 'media_card.dart';

/// Generic media list content. Metadata and cover text come entirely from Apps.
class FrostMediaRow extends StatefulWidget {
  const FrostMediaRow({
    required this.media,
    required this.title,
    this.metadata = const [],
    this.metadataLeading,
    this.overlay,
    this.topStart,
    this.progress,
    this.onPressed,
    this.onOpenInBackground,
    this.onOpenInNewTab,
    this.contextMenu = const [],
    super.key,
  }) : assert(metadata.length <= 2);
  final Widget media;
  final String title;
  final List<String> metadata;
  final Widget? metadataLeading;
  final Widget? overlay;
  final Widget? topStart;
  final double? progress;
  final VoidCallback? onPressed;
  final VoidCallback? onOpenInBackground;
  final VoidCallback? onOpenInNewTab;
  final List<FrostMenuEntry> contextMenu;

  @override
  State<FrostMediaRow> createState() => _FrostMediaRowState();
}

class _FrostMediaRowState extends State<FrostMediaRow> {
  FrostListItemHandle? _handle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final handle = FrostListItemScope.of(context)?.handle;
    if (_handle != handle) {
      _handle?.activate = null;
      _handle = handle;
    }
    _handle?.activate = _activate;
  }

  void _activate() {
    if (!FrostControlScope.enabledOf(context)) return;
    (FrostListItemScope.of(context)?.onSelected ?? widget.onPressed)?.call();
  }

  @override
  void dispose() {
    _handle?.activate = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final FrostMediaRow(:media, :title, :metadata, :overlay, :progress, :onPressed, :contextMenu) = widget;
    final enabled = FrostControlScope.enabledOf(context);
    final item = FrostListItemScope.of(context);
    final interactive = enabled && (onPressed != null || item?.onSelected != null);
    final touch = FrostDensity.of(context).heightFor(FrostControlSize.regular) == 44;
    final tokens = FrostThemeTokens.of(context);
    final titleStyle = FrostTypography.of(context).style(FrostTextRole.subheadline).copyWith(fontSize: 13);
    double textBlockHeight(double width) {
      final painter = TextPainter(
        text: TextSpan(text: title, style: titleStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 2,
      )..layout(maxWidth: width);
      final titleHeight = painter.height;
      painter.dispose();
      final metadataLine = frostTextLineSize(context, ' ', FrostTypography.of(context).style(FrostTextRole.caption, tabular: true)).height;
      return titleHeight + metadata.length * (3 + metadataLine);
    }

    Widget row = FrostClickHighlight(
      highlighted: enabled && (item?.highlighted ?? false),
      child: FrostClickSurface(
        onTap: interactive ? _activate : null,
        onOpenInBackground: interactive ? widget.onOpenInBackground : null,
        onOpenInNewTab: interactive ? widget.onOpenInNewTab : null,
        focusNode: FrostRowFocus.of(context),
        shape: FrostClickShape.rounded(FrostRadius.borderRadius(FrostRadius.sm)),
        child: Semantics(
          button: interactive,
          enabled: onPressed == null && item?.onSelected == null ? null : enabled,
          label: [title, ...metadata].join(', '),
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FrostMeasuredLayoutBuilder(
              naturalSize: Size(
                (touch ? 136 : 141) + 10 + frostTextLineSize(context, title, titleStyle).width,
                math.max((touch ? 136 : 141) * 9 / 16, textBlockHeight(double.infinity)),
              ),
              heightForWidth: (width) {
                final thumbnail = math.min(touch ? 136.0 : 141.0, math.max(0.0, width - 100));
                return math.max(thumbnail * 9 / 16, textBlockHeight(math.max(0, width - thumbnail - 10)));
              },
              builder: (context, constraints) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: math.min(touch ? 136 : 141, math.max(0, constraints.maxWidth - 100)),
                    child: IgnorePointer(
                      child: FrostCoverRowScope(
                        child: FrostMediaCard(topStart: widget.topStart, media: media, aspectRatio: 16 / 9, overlay: overlay, progress: progress),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: titleStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
                        if (metadata.isNotEmpty) const SizedBox(height: 3),
                        for (final (index, text) in metadata.indexed) ...[
                          if (index > 0) const SizedBox(height: 3),
                          Row(
                            children: [
                              if (index == 0 && widget.metadataLeading != null) ...[widget.metadataLeading!, const SizedBox(width: 6)],
                              Expanded(
                                child: Text(
                                  text,
                                  style: FrostTypography.of(
                                    context,
                                  ).style(FrostTextRole.caption, tabular: true).copyWith(fontWeight: FontWeight.w400, color: tokens.textTertiary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (!enabled) row = Opacity(opacity: .38, child: row);
    if (contextMenu.isNotEmpty) row = FrostContextMenuRegion(enabled: enabled, entries: contextMenu, child: row);
    return DefaultTextStyle.merge(
      style: TextStyle(color: tokens.textPrimary),
      child: row,
    );
  }
}
