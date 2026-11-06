import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_control.dart';
import 'package:frost_ui/src/controls/_button_types.dart';
import 'package:frost_ui/src/overlays/overlay_region.dart';
import 'package:frost_ui/src/primitives/_focus_outline.dart';

export 'package:frost_ui/src/controls/_button_types.dart' show FrostButtonVariant, FrostIconButtonStyle;

const testFonts = FrostFonts(japanese: 'JP', simplifiedChinese: 'SC', defaultScript: FrostContentScript.japanese);

/// Locate the public Frost wrapper even when its tooltip semantics are excluded.
Finder findFrostTooltip(String message) => find.byWidgetPredicate((widget) => widget is FrostTooltip && widget.message == message);

/// Inspect the same concentric outline used by shared fields and click surfaces.
Finder frostFocusRings() => find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter is FrostFocusOutlinePainter);

const _glyph = FrostIconData.glyph(IconData(0xe000));

const testIcons = FrostIconSet(
  back: _glyph,
  close: FrostIconData.glyph(IconData(0xe001)),
  more: _glyph,
  expand: _glyph,
  collapse: _glyph,
  chevronLeft: FrostIconData.glyph(IconData(0xe00a)),
  chevronRight: FrostIconData.glyph(IconData(0xe00b)),
  chevronDown: _glyph,
  arrowDown: FrostIconData.glyph(IconData(0xe003)),
  refresh: _glyph,
  copy: _glyph,
  search: _glyph,
  check: FrostIconData.glyph(IconData(0xe002)),
  success: _glyph,
  info: _glyph,

  error: _glyph,
  empty: _glyph,
  sidebarExpand: _glyph,
  sidebarCollapse: _glyph,
  forward: _glyph,
  chevronUp: _glyph,
  chevronUpDown: _glyph,
  externalLink: _glyph,
  link: _glyph,
  share: _glyph,
  download: _glyph,
  upload: _glyph,
  delete: _glyph,
  edit: _glyph,
  add: _glyph,
  remove: _glyph,
  filter: _glyph,
  sort: _glyph,
  dragHandle: _glyph,
  play: _glyph,
  pause: _glyph,
  repeat: _glyph,
  volumeOn: _glyph,
  volumeOff: _glyph,
  fullscreen: _glyph,
  exitFullscreen: _glyph,
  zoomIn: _glyph,
  zoomOut: _glyph,
  image: _glyph,
  imageError: _glyph,
  multiPage: _glyph,
  minimize: _glyph,
  maximize: _glyph,
  restore: _glyph,
  calendar: _glyph,
  clock: _glyph,
  folder: _glyph,
  eye: _glyph,
  eyeOff: _glyph,
  user: _glyph,
  textFormat: _glyph,
);

/// [testIcons] with distinct direction glyphs (back 0xe100, forward 0xe101,
/// chevron left 0xe102, chevron right 0xe103; the left ones draw arrows that
/// point left until mirrored) that mirror themselves in right-to-left text when [mirrors] is true, the way
/// Material's chevron and arrow icons do.
FrostIconSet directionalTestIcons({required bool mirrors}) {
  FrostIconData glyph(IconData mirroring, IconData plain) => FrostIconData.glyph(mirrors ? mirroring : plain);
  const back = (IconData(0xe100, matchTextDirection: true), IconData(0xe100));
  const forward = (IconData(0xe101, matchTextDirection: true), IconData(0xe101));
  const chevronLeft = (IconData(0xe102, matchTextDirection: true), IconData(0xe102));
  const chevronRight = (IconData(0xe103, matchTextDirection: true), IconData(0xe103));
  return FrostIconSet(
    back: glyph(back.$1, back.$2),
    close: testIcons.close,
    more: testIcons.more,
    expand: testIcons.expand,
    collapse: testIcons.collapse,
    chevronLeft: glyph(chevronLeft.$1, chevronLeft.$2),
    chevronRight: glyph(chevronRight.$1, chevronRight.$2),
    chevronDown: testIcons.chevronDown,
    arrowDown: testIcons.arrowDown,
    refresh: testIcons.refresh,
    copy: testIcons.copy,
    search: testIcons.search,
    check: testIcons.check,
    success: testIcons.success,
    info: testIcons.info,
    error: testIcons.error,
    empty: testIcons.empty,
    sidebarExpand: testIcons.sidebarExpand,
    sidebarCollapse: testIcons.sidebarCollapse,
    forward: glyph(forward.$1, forward.$2),
    chevronUp: testIcons.chevronUp,
    chevronUpDown: testIcons.chevronUpDown,
    externalLink: testIcons.externalLink,
    link: testIcons.link,
    share: testIcons.share,
    download: testIcons.download,
    upload: testIcons.upload,
    delete: testIcons.delete,
    edit: testIcons.edit,
    add: testIcons.add,
    remove: testIcons.remove,
    filter: testIcons.filter,
    sort: testIcons.sort,
    dragHandle: testIcons.dragHandle,
    play: testIcons.play,
    pause: testIcons.pause,
    repeat: testIcons.repeat,
    volumeOn: testIcons.volumeOn,
    volumeOff: testIcons.volumeOff,
    fullscreen: testIcons.fullscreen,
    exitFullscreen: testIcons.exitFullscreen,
    zoomIn: testIcons.zoomIn,
    zoomOut: testIcons.zoomOut,
    image: testIcons.image,
    imageError: testIcons.imageError,
    multiPage: testIcons.multiPage,
    minimize: testIcons.minimize,
    maximize: testIcons.maximize,
    restore: testIcons.restore,
    calendar: testIcons.calendar,
    clock: testIcons.clock,
    folder: testIcons.folder,
    eye: testIcons.eye,
    eyeOff: testIcons.eyeOff,
    user: testIcons.user,
    textFormat: testIcons.textFormat,
  );
}

FrostLabels testLabels(BuildContext context) => const FrostLabels(
  retry: 'L.retry',
  retryAfter: _retryAfter,
  error: 'L.error',
  errorDetails: 'L.errorDetails',
  copyDetails: 'L.copyDetails',
  copied: 'L.copied',
  loading: 'L.loading',
  actionSucceeded: 'L.actionSucceeded',
  actionFailed: 'L.actionFailed',
  loadFailed: 'L.loadFailed',
  noMoreItems: 'L.noMoreItems',
  noItems: 'L.noItems',
  pullToRefresh: 'L.pullToRefresh',
  releaseToRefresh: 'L.releaseToRefresh',
  refreshing: 'L.refreshing',
  refreshComplete: 'L.refreshComplete',
  refreshFailed: 'L.refreshFailed',
  previous: 'L.previous',
  next: 'L.next',
  back: 'L.back',
  more: 'L.more',
  expandNavigation: 'L.expandNavigation',
  collapseNavigation: 'L.collapseNavigation',
  navigationStatus: _navigationStatus,
  clearText: 'L.clearText',
  search: 'L.search',
  noResults: _noResults,
  clearSearch: 'L.clearSearch',
  dismiss: 'L.dismiss',
  expandText: 'L.expandText',
  collapseText: 'L.collapseText',
  showAll: 'L.showAll',
  copy: 'L.copy',
  clearAll: 'L.clearAll',
  showPassword: 'L.showPassword',
  hidePassword: 'L.hidePassword',
  chooseDate: 'L.chooseDate',
  chooseTime: 'L.chooseTime',
  increment: 'L.increment',
  decrement: 'L.decrement',
  reorderHandle: 'L.reorderHandle',
  sortAscending: 'L.sortAscending',
  sortDescending: 'L.sortDescending',
  play: 'L.play',
  pause: 'L.pause',
  loop: 'L.loop',
  mute: 'L.mute',
  unmute: 'L.unmute',
  fullscreen: 'L.fullscreen',
  exitFullscreen: 'L.exitFullscreen',
  minimize: 'L.minimize',
  maximize: 'L.maximize',
  restore: 'L.restore',
  close: 'L.close',
  cancel: 'L.cancel',
  apply: 'L.apply',
  clear: 'L.clear',
  choose: 'L.choose',
  showInFolder: 'L.showInFolder',
  selectedCount: _selectedCount,
  pageOf: _pageOf,
  selectAll: 'L.selectAll',
  done: 'L.done',
  itemPosition: _itemPosition,
  tableDimensions: _tableDimensions,
  taskQueued: 'L.taskQueued',
  taskRunning: 'L.taskRunning',
  taskPaused: 'L.taskPaused',
  taskCompleted: 'L.taskCompleted',
  taskFailed: 'L.taskFailed',
  taskCancelled: 'L.taskCancelled',
  remove: 'L.remove',
  seek: 'L.seek',
  showReplies: _showReplies,
  moreMedia: _moreMedia,
);

final testErrors = FrostErrorPresenter(message: (context, error) => 'E.message($error)', details: (error) => 'E.details($error)');

final testConfig = FrostConfig(palettes: FrostPalettes.pink, fonts: testFonts, icons: testIcons, labels: testLabels, errors: testErrors);

/// [child] inside a Frost theme, scope and toast host, on a desktop-sized
/// surface unless [size] says otherwise.
Widget frostTestApp(
  Widget child, {
  Brightness brightness = Brightness.light,
  bool reduceTransparency = false,
  FrostDensity density = FrostDensity.comfortable,
  TargetPlatform platform = TargetPlatform.windows,
  FrostIconSet? icons,
}) {
  final config = icons == null ? testConfig : testConfig.copyWith(icons: icons);
  return FrostScope(
    config: config,
    reduceTransparency: reduceTransparency,
    child: MaterialApp(
      theme: FrostTheme.build(config: config, brightness: brightness, platform: platform, locale: const Locale('en'), density: density),
      builder: (context, child) => FrostToastHost(child: child!),
      home: child,
    ),
  );
}

String _selectedCount(int count) => 'Selected $count';
String _noResults(String query) => 'L.noResults($query)';
String _pageOf(int page, int total) => '$page of $total';

String _itemPosition(int position, int total) => '$position / $total';

String _tableDimensions(int rows, int columns) => '$rows × $columns';

String _showReplies(int count) => 'L.showReplies($count)';
String _moreMedia(int count) => '+$count';

String _navigationStatus(int count, int? progressPercent) => 'L.navigationStatus($count,$progressPercent)';

String _retryAfter(int seconds) => 'L.retryAfter($seconds)';

/// The internal control a public [FrostButton] builds, to inspect its variant
/// and icon style, which the public widget no longer exposes.
FrostButtonControl buttonControl(WidgetTester tester, Finder button) =>
    tester.widget<FrostButtonControl>(find.descendant(of: button, matching: find.byType(FrostButtonControl)).first);

/// The public constructor for a button [variant], for tests that loop over all.
FrostButton variantButton(
  FrostButtonVariant variant, {
  required String label,
  VoidCallback? onPressed,
  FrostIconData? icon,
  Widget? labelWidget,
  FrostButtonRole role = FrostButtonRole.normal,
  FrostControlSize? size,
  FrostActionState state = FrostActionState.idle,
  String? tooltip,
}) => switch (variant) {
  FrostButtonVariant.standard => FrostButton(
    label: label,
    onPressed: onPressed,
    icon: icon,
    labelWidget: labelWidget,
    role: role,
    size: size,
    state: state,
    tooltip: tooltip,
  ),
  FrostButtonVariant.prominent => FrostButton.prominent(
    label: label,
    onPressed: onPressed,
    icon: icon,
    labelWidget: labelWidget,
    role: role,
    size: size,
    state: state,
    tooltip: tooltip,
  ),
  FrostButtonVariant.tinted => FrostButton.tinted(
    label: label,
    onPressed: onPressed,
    icon: icon,
    labelWidget: labelWidget,
    role: role,
    size: size,
    state: state,
    tooltip: tooltip,
  ),
  FrostButtonVariant.outlined => FrostButton.outlined(
    label: label,
    onPressed: onPressed,
    icon: icon,
    labelWidget: labelWidget,
    role: role,
    size: size,
    state: state,
    tooltip: tooltip,
  ),
  FrostButtonVariant.plain => FrostButton.plain(
    label: label,
    onPressed: onPressed,
    icon: icon,
    labelWidget: labelWidget,
    role: role,
    size: size,
    state: state,
    tooltip: tooltip,
  ),
};

/// The public icon constructor for an icon [style], for tests that loop over all.
FrostButton iconStyleButton(
  FrostIconButtonStyle style, {
  required FrostIconData icon,
  required String label,
  VoidCallback? onPressed,
  FrostControlSize? size,
  bool? selected,
}) => switch (style) {
  FrostIconButtonStyle.plain => FrostButton.icon(icon: icon, label: label, onPressed: onPressed, size: size, selected: selected),
  FrostIconButtonStyle.standard => FrostButton.iconFilled(icon: icon, label: label, onPressed: onPressed, size: size, selected: selected),
  FrostIconButtonStyle.onMedia => FrostButton.iconOnMedia(icon: icon, label: label, onPressed: onPressed, size: size, selected: selected),
};

/// How far one painted fill has moved from [rest], as the largest channel
/// change once both composite over mid grey. A button folds its state wash
/// into its fill, so a hover or press shows up as this distance.
double fillShift(Color rest, Color now) {
  const backdrop = Color(0xFF808080);
  final a = Color.alphaBlend(rest, backdrop), b = Color.alphaBlend(now, backdrop);
  return [(a.r - b.r).abs(), (a.g - b.g).abs(), (a.b - b.b).abs()].reduce((x, y) => x > y ? x : y);
}

class _DrawRecorder implements Canvas {
  var draws = 0;
  Paint? paint;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    const drawing = {#drawRSuperellipse, #drawRRect, #drawCircle, #drawPath, #drawDRRect, #drawRect, #drawOval};
    if (drawing.contains(invocation.memberName)) {
      draws++;
      paint = invocation.positionalArguments.whereType<Paint>().last;
    }
    return null;
  }
}

/// What a media frame under [owner] paints above its clip right now: its shape,
/// the stroke it draws (nothing while an enclosed image is pending), and whether
/// a clip lies between that stroke and its frame.
List<({OutlinedBorder shape, int draws, double? width, Color? color, Color? drawn, bool clipped})> innerStrokes(WidgetTester tester, Finder owner) {
  final result = <({OutlinedBorder shape, int draws, double? width, Color? color, Color? drawn, bool clipped})>[];
  final painted = find.descendant(
    of: owner,
    matching: find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter?.runtimeType.toString() == '_InnerStrokePainter'),
  );
  for (final element in painted.evaluate()) {
    final painter = (element.widget as CustomPaint).foregroundPainter!;
    final recorder = _DrawRecorder();
    painter.paint(recorder, (element.renderObject! as RenderCustomPaint).size);
    var clipped = false;
    element.visitAncestorElements((ancestor) {
      final widget = ancestor.widget;
      if (widget is FrostMediaFrame) return false;
      if (widget is ClipRect || widget is ClipRRect || widget is ClipRSuperellipse || widget is ClipPath || widget is ClipOval) clipped = true;
      return true;
    });
    result.add((
      shape: (painter as dynamic).shape as OutlinedBorder,
      draws: recorder.draws,
      width: (painter as dynamic).width as double,
      color: (painter as dynamic).color as Color,
      drawn: recorder.paint?.color,
      clipped: clipped,
    ));
  }
  return result;
}

/// Search dropdown content of [sections] and a status line, or none when
/// there is nothing to show.
Widget? searchContent(List<Widget> sections, {bool loading = false, String? message}) => sections.isEmpty && !loading && message == null
    ? null
    : Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ...sections,
          FrostSearchStatus(loading: loading, message: message),
        ],
      );

/// Limits overlays opened below it to its live rectangle, the way a shell's
/// content area does for the panels opened inside it.
class TestOverlayRegion extends StatefulWidget {
  const TestOverlayRegion({required this.child, super.key});
  final Widget child;
  @override
  State<TestOverlayRegion> createState() => _TestOverlayRegionState();
}

class _TestOverlayRegionState extends State<TestOverlayRegion> {
  final _bounds = FrostOverlayBounds();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bounds.setParent(FrostOverlayRegionData.maybeOf(context));
  }

  @override
  void dispose() {
    _bounds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FrostOverlayRegionData(
    bounds: _bounds,
    child: FrostOverlayRegionGeometry(onChanged: _bounds.update, child: widget.child),
  );
}
