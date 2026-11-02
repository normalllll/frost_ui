import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../display/module_grid.dart';
import '../foundation/_layout_scope.dart';
import '../foundation/_media_contrast.dart';
import '../foundation/density.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../media/_system_chrome_activation.dart';
import '../media/media_stage.dart';
import '../media/system_chrome.dart';
import '../motion/_frame_work.dart';
import '../motion/layout_crossfade.dart';
import '../primitives/_on_media_chrome_scope.dart';
import '../primitives/_page_outline.dart';
import '../primitives/divider.dart';
import '../surface/_media_ambient.dart';
import '../surface/_window_background.dart';
import '../surface/ambient_backdrop.dart';
import 'content_viewport.dart';
import 'pinned_chrome.dart';

// The information width includes its shared page insets.
const _detailInformationWidth = 380.0;
// Preserve the same local minimum as SplitView before shrinking information.
const _detailMinimumStageWidth = 240.0;
// How far reserving room for information can squeeze a stacked stage. A stage
// whose media needs less keeps its own height.
const _detailMinimumStageHeight = 240.0;
// Compact stages are finite viewports; the caller owns media contain behavior.
const _compactStageFraction = .6;
const _detailBlockGap = FrostGap.section;
const _detailActionGap = FrostGap.group;

/// Where a detail header is pinned on a wide layout.
enum FrostDetailHeaderPlacement { information, page }

/// Whether a stacked stage uses a finite viewport or its natural content height.
enum FrostDetailStageSizing { adaptive, viewport, natural }

enum _DetailBlock { primary, actions, modules, secondary }

/// A media stage beside independently scrolling information, or above it in
/// compact or portrait space. Stage and information State survive every change
/// between the two.
///
/// [stage] fills the available wide stage. The adaptive stacked stage stays
/// above the scrolling information, adopting its media ratio within the space
/// left after reserving max(300, available height * .42) for information, and
/// always within at least 240 of height where the space has it.
/// Explicit natural sizing gives the stage unbounded height. Use FrostMediaStage for its media
/// rectangle, or FrostMediaFrame(fit: BoxFit.contain) or
/// FrostMediaViewport to contain media; this template never scales stage controls.
/// Information receives page keylines and insets, including 24 top and bottom.
/// Pushed pages paint stage, header, primary information and actions immediately.
/// Secondary blocks release paint in order, at most one per frame, after their
/// final layout. Entry scheduling never inserts slivers or changes body extents.
/// Existing content and responsive reflow never restart a released block. Information
/// blocks are laid out lazily; visited block State remains owned by this page.
/// Wide panes have an inset physical-pixel separator. With a page header it
/// starts below the measured chrome; stacked layouts have no pane separator.
class FrostDetailLayout extends StatefulWidget {
  const FrostDetailLayout({
    required this.stage,
    required this.primary,
    this.actions,
    this.modules = const [],
    this.sections = const [],
    this.technical,
    this.backdrop,
    this.header,
    this.mediaHeader,
    this.stackBelow = FrostSizeClass.medium,
    this.headerPlacement = FrostDetailHeaderPlacement.information,
    this.compactStageSizing = FrostDetailStageSizing.adaptive,
    super.key,
  });
  final Widget stage, primary;
  final Widget? actions, technical, header;

  /// Builds controls over edge-to-edge narrow media. The second argument is
  /// true after a scrolling stage passes under the header. Adaptive fixed
  /// stages keep this false while their information scrolls. Use it only to compose title
  /// content; the library owns the scroll boundary and onMedia button styling.
  /// Both wide and narrow forms occupy one measured fixed slot from frame one.
  /// With natural/viewport sizing the narrow builder updates after the stage passes, without
  /// changing body padding or position; wide layouts use [header].
  /// The library owns safe areas, system-bar protection and stage corners.
  /// Wide stages continue to use [header] and [headerPlacement].
  final Widget Function(BuildContext context, bool scrolledPastStage)? mediaHeader;
  final List<FrostModuleGridItem> modules;
  final List<Widget> sections;
  final ImageProvider? backdrop;

  /// Size classes below this threshold stack stage and information vertically,
  /// and so does available space the window shape rule calls portrait, whatever
  /// its width. The default stacks compact only. Use expanded to include medium
  /// without changing navigation breakpoints or any other layout's size
  /// classification.
  final FrostSizeClass stackBelow;

  /// Information pins the header over the information pane on wide layouts.
  /// Page spans the whole page, with stage and information beneath one shared
  /// pinned glass band. Both modes use the same single header when stacked.
  final FrostDetailHeaderPlacement headerPlacement;

  /// Adaptive (default) fixes the stage above the only scrolling information
  /// pane. The stage measures its media ratio within the remaining room after
  /// reserving max(300, available height * .42) for information, excluding a
  /// non-media header. That reserve never takes the stage's room below 240 of
  /// height; information scrolls in what is left.
  /// Viewport retains a scrolling finite 60% slot. Natural gives the stage a finite
  /// width and unbounded height; use FrostMediaStage to size media from its
  /// decoded ratio. Tall media remains uncropped and scrolls with information.
  /// This affects stacked layouts only; wide stages always remain finite.
  final FrostDetailStageSizing compactStageSizing;
  @override
  State<FrostDetailLayout> createState() => _DetailLayoutState();
}

class _DetailLayoutState extends State<FrostDetailLayout> {
  final _stageKey = GlobalKey();
  final _informationKey = GlobalKey();
  final _headerKey = GlobalKey();
  final _scrollKey = GlobalKey();
  final _normalHeaderKey = GlobalKey();
  final _mediaHeaderKey = GlobalKey();
  final _pastStage = ValueNotifier(false);
  bool _headerUpdateScheduled = false;

  void _updateMediaHeader(ScrollMetrics metrics) {
    void update() {
      if (!mounted) return;
      final stage = _stageKey.currentContext?.findRenderObject();
      final header = _headerKey.currentContext?.findRenderObject();
      if (stage is! RenderBox || !stage.hasSize || header is! RenderBox || !header.hasSize) return;
      // Input notifications arrive before the next viewport layout. Derive the
      // boundary from measured extents and the new metrics, not stale paint offsets.
      final headerExtent = header.size.height + MediaQuery.paddingOf(context).top;
      _pastStage.value = metrics.extentBefore >= stage.size.height - headerExtent;
    }

    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      if (_headerUpdateScheduled) return;
      _headerUpdateScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _headerUpdateScheduled = false;
        update();
      });
    } else {
      update();
    }
  }

  ModalRoute<Object?>? _route;
  Animation<double>? _entry;
  FrostFrameWorkPhase _entryPhase = FrostFrameWorkPhase.immediate;
  bool _initialized = false;

  List<Widget> get _secondary => [
    if (widget.modules.isNotEmpty) FrostModuleGrid(key: const ValueKey(_DetailBlock.modules), items: widget.modules),
    ...widget.sections,
    ?widget.technical,
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    _route = route;
    final animation = route?.animation;
    if (_entry != animation) {
      _entry?.removeStatusListener(_entryStatus);
      _entry = animation?..addStatusListener(_entryStatus);
    }
    if (!_initialized) {
      _initialized = true;
      // HeroController first measures a pushed route offstage, exposing a
      // completed animation proxy. That is preparation, not a settled page.
      if (route?.isFirst == false && (route!.offstage || animation?.status == AnimationStatus.forward) && !MediaQuery.disableAnimationsOf(context)) {
        _entryPhase = route.offstage ? FrostFrameWorkPhase.waiting : FrostFrameWorkPhase.queued;
      }
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _entryPhase = FrostFrameWorkPhase.immediate;
    } else if (_entryPhase == FrostFrameWorkPhase.waiting && route?.offstage != true) {
      _entryPhase = FrostFrameWorkPhase.queued;
    }
  }

  void _entryStatus(AnimationStatus status) {
    final phase = switch (status) {
      AnimationStatus.reverse || AnimationStatus.dismissed => FrostFrameWorkPhase.stopped,
      AnimationStatus.forward => _route?.offstage == true ? FrostFrameWorkPhase.waiting : FrostFrameWorkPhase.queued,
      AnimationStatus.completed => FrostFrameWorkPhase.immediate,
    };
    if (mounted && phase != _entryPhase) setState(() => _entryPhase = phase);
  }

  @override
  void dispose() {
    _entry?.removeStatusListener(_entryStatus);
    _pastStage.dispose();
    super.dispose();
  }

  Widget _information() {
    final secondary = _secondary;
    final blocks = <(Key, double, Widget)>[
      (const ValueKey(_DetailBlock.primary), 0, widget.primary),
      if (widget.actions case final actions?) (const ValueKey(_DetailBlock.actions), _detailActionGap, actions),
      for (final (index, section) in secondary.indexed)
        (
          section.key == null ? ValueKey((_DetailBlock.secondary, index)) : ValueKey(section.key),
          _detailBlockGap,
          FrostFrameWorkPaint(phase: _entryPhase, child: section),
        ),
    ];
    return FrostSliverContentColumn(
      key: _informationKey,
      sliver: SliverPadding(
        padding: const EdgeInsets.symmetric(vertical: FrostGap.section),
        sliver: SliverList(
          delegate: SliverChildListDelegate(
            [
              for (final (key, gap, child) in blocks)
                KeepAlive(
                  key: key,
                  keepAlive: true,
                  child: RepaintBoundary(
                    child: Padding(
                      padding: EdgeInsets.only(top: gap),
                      child: child,
                    ),
                  ),
                ),
            ],
            // Explicit keep-alive retains already visited block State while
            // offscreen blocks avoid first build and layout altogether.
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: false,
            addSemanticIndexes: false,
          ),
        ),
      ),
    );
  }

  Widget _scroll({Widget? stage, bool overlayHeader = false}) => CustomScrollView(
    key: _scrollKey,
    slivers: [
      if (!overlayHeader) const FrostChromeSpacer(),
      if (stage != null) SliverToBoxAdapter(child: _stageBody(stage, FrostPageOutline.channelOf(context), removeTop: !overlayHeader, removeBottom: true)),
      _information(),
    ],
  );

  // The stage sees only the safe area it reaches, so controls over its media
  // keep clear of what covers them and of nothing else.
  Widget _stageBody(Widget stage, double channel, {bool removeTop = false, bool removeBottom = false, bool removeLeft = false, bool removeRight = false}) =>
      Padding(
        padding: EdgeInsets.only(right: channel),
        child: FrostPageOutline(
          radius: FrostPageOutline.of(context),
          channelClaimed: true,
          child: Builder(
            builder: (context) => MediaQuery.removePadding(
              context: context,
              removeTop: removeTop,
              removeBottom: removeBottom,
              removeLeft: removeLeft,
              removeRight: removeRight,
              child: stage,
            ),
          ),
        ),
      );

  Widget _pinned(Widget body, {bool page = false, bool media = false, bool fixedStage = false}) => ValueListenableBuilder<bool>(
    valueListenable: _pastStage,
    child: body,
    builder: (context, past, body) {
      final pastStage = !fixedStage && past;
      final onMedia = media && !pastStage;
      final headers = KeyedSubtree(
        key: _headerKey,
        child: IndexedStack(
          index: media ? 1 : 0,
          alignment: AlignmentDirectional.topStart,
          children: [
            TickerMode(
              enabled: !media,
              child: KeyedSubtree(key: _normalHeaderKey, child: widget.header ?? const SizedBox.shrink()),
            ),
            if (widget.mediaHeader != null)
              TickerMode(
                enabled: media,
                child: KeyedSubtree(
                  key: _mediaHeaderKey,
                  child: onMedia
                      ? FrostOnMediaChromeScope(child: Builder(builder: (context) => widget.mediaHeader!(context, pastStage)))
                      : frostWithoutOnMediaChrome(Builder(builder: (context) => widget.mediaHeader!(context, pastStage))),
                ),
              ),
          ],
        ),
      );
      return Stack(
        fit: StackFit.expand,
        children: [
          FrostPinnedChromeMaterial(
            enabled: !onMedia,
            child: FrostPinnedChrome(
              chrome: media ? headers : FrostContentColumn(maxWidth: page ? double.infinity : FrostMetrics.contentMaxWidth, child: headers),
              body: body!,
            ),
          ),
          FrostSystemChromeActivation(
            active: onMedia,
            child: const FrostMediaSystemChrome(child: SizedBox.shrink()),
          ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: _buildForSpace);

  Widget _buildForSpace(BuildContext context, BoxConstraints available) {
    final portrait = available.hasBoundedHeight && !isHorizontalSize(available.biggest, pointer: FrostDensity.of(context).usesPointer);
    final stacked = available.maxWidth < widget.stackBelow.minimumWidth || portrait;
    final edgeToEdge = stacked && available.maxWidth < FrostSizeClass.medium.minimumWidth;
    final mediaHeader = edgeToEdge && widget.mediaHeader != null;
    final fixedStage = stacked && widget.compactStageSizing == FrostDetailStageSizing.adaptive;
    final stage = KeyedSubtree(
      key: _stageKey,
      child: FrostAmbientMediaRegistration(
        child: FrostMediaStagePresentation(radius: edgeToEdge ? 0 : FrostRadius.lg, child: widget.stage),
      ),
    );
    Widget layout = LayoutBuilder(
      builder: (context, constraints) {
        if (stacked) {
          if (fixedStage) {
            return _pinned(
              LayoutBuilder(
                builder: (context, _) => Padding(
                  // FrostPinnedChrome has already measured the actual header,
                  // including enlarged text and system safe areas.
                  padding: EdgeInsets.only(top: mediaHeader ? 0 : MediaQuery.paddingOf(context).top),
                  child: CustomMultiChildLayout(
                    delegate: _StackedDetailLayout(),
                    children: [
                      LayoutId(
                        id: _StackedDetailSlot.stage,
                        child: _stageBody(stage, FrostPageOutline.channelOf(context), removeTop: !mediaHeader, removeBottom: true),
                      ),
                      LayoutId(
                        id: _StackedDetailSlot.information,
                        child: MediaQuery.removePadding(context: context, removeTop: true, child: _scroll(overlayHeader: true)),
                      ),
                    ],
                  ),
                ),
              ),
              media: mediaHeader,
              fixedStage: true,
            );
          }
          return _pinned(
            _scroll(
              overlayHeader: mediaHeader,
              stage: widget.compactStageSizing == FrostDetailStageSizing.natural
                  ? stage
                  : SizedBox(height: constraints.maxHeight * _compactStageFraction, child: stage),
            ),
            media: mediaHeader,
          );
        }
        final rtl = Directionality.of(context) == TextDirection.rtl;
        final channel = FrostPageOutline.channelOf(context);
        final informationChannel = rtl ? 0.0 : channel;
        final stageChannel = rtl ? channel : 0.0;
        final informationWidth = math.min(
          _detailInformationWidth + informationChannel,
          math.max(0.0, constraints.maxWidth - stageChannel - _detailMinimumStageWidth),
        );
        final page = widget.headerPlacement == FrostDetailHeaderPlacement.page;
        final outer = FrostPageOutline.of(context);
        final paneRadius = Directionality.of(context) == TextDirection.ltr
            ? BorderRadius.only(topRight: outer.topRight, bottomRight: outer.bottomRight)
            : BorderRadius.only(topLeft: outer.topLeft, bottomLeft: outer.bottomLeft);
        final information = FrostPageOutline(
          radius: paneRadius,
          scrollbarChannel: informationChannel,
          channelClaimed: true,
          child: page ? _scroll() : _pinned(_scroll()),
        );
        Widget panes(BuildContext context) => Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: page
                  ? Padding(
                      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
                      child: _stageBody(stage, stageChannel, removeTop: true, removeLeft: rtl, removeRight: !rtl),
                    )
                  : _stageBody(stage, stageChannel, removeLeft: rtl, removeRight: !rtl),
            ),
            // A zero-width pane retains its subtree without laying out controls
            // against zero horizontal room. Its requested width is never changed.
            if (informationWidth == 0)
              Offstage(
                child: SizedBox(width: _detailInformationWidth, height: constraints.maxHeight, child: information),
              )
            else
              SizedBox(
                width: informationWidth,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    information,
                    // Overlay the hairline inside the information edge, keeping
                    // both pane widths and their retained content unchanged.
                    PositionedDirectional(
                      start: 0,
                      top: page ? MediaQuery.paddingOf(context).top : 0,
                      bottom: 0,
                      child: const IgnorePointer(child: FrostDivider(axis: Axis.vertical)),
                    ),
                  ],
                ),
              ),
          ],
        );
        return page ? _pinned(Builder(builder: panes), page: true) : panes(context);
      },
    );
    layout = NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        if (mediaHeader && !fixedStage && notification.depth == 0) _updateMediaHeader(notification.metrics);
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (mediaHeader && !fixedStage && notification.depth == 0) _updateMediaHeader(notification.metrics);
          return false;
        },
        child: layout,
      ),
    );
    layout = FrostTimedLayoutCrossfade(layoutIdentity: (stacked, widget.headerPlacement), settleDuration: Duration.zero, child: layout);
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          right: FrostPageOutline.channelOf(context),
          child: widget.backdrop == null
              ? ColoredBox(color: frostMediaBackdropBase(FrostThemeTokens.of(context)))
              : FrostMediaStageScope(
                  stageKey: _stageKey,
                  child: FrostAmbientBackdrop.fromImage(image: widget.backdrop!, child: const SizedBox.expand()),
                ),
        ),
        layout,
      ],
    );
  }
}

enum _StackedDetailSlot { stage, information }

/// Measure the real stage once with a finite cap. LayoutBuilder-backed media
/// cannot report intrinsics; ordinary child layout preserves its ratio and its
/// live image/zoom State without a second offstage measurement or cached size.
class _StackedDetailLayout extends MultiChildLayoutDelegate {
  @override
  void performLayout(Size size) {
    final informationMinimum = math.max(300.0, size.height * .42);
    final stage = layoutChild(
      _StackedDetailSlot.stage,
      BoxConstraints(
        minWidth: size.width,
        maxWidth: size.width,
        maxHeight: math.min(size.height, math.max(_detailMinimumStageHeight, size.height - informationMinimum)),
      ),
    );
    positionChild(_StackedDetailSlot.stage, Offset.zero);
    layoutChild(_StackedDetailSlot.information, BoxConstraints.tight(Size(size.width, size.height - stage.height)));
    positionChild(_StackedDetailSlot.information, Offset(0, stage.height));
  }

  @override
  bool shouldRelayout(_StackedDetailLayout oldDelegate) => false;
}
