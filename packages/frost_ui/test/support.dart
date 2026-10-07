import 'package:flutter/material.dart';
import 'package:frost_ui/frost_ui.dart';

const testFonts = FrostFonts(japanese: 'JP', simplifiedChinese: 'SC', defaultScript: FrostContentScript.japanese);

const _glyph = FrostIconData.glyph(IconData(0xe000));

const testIcons = FrostIconSet(
  back: _glyph,
  close: _glyph,
  more: _glyph,
  expand: _glyph,
  collapse: _glyph,
  chevronLeft: _glyph,
  chevronRight: _glyph,
  chevronDown: _glyph,
  refresh: _glyph,
  copy: _glyph,
  search: _glyph,
  check: _glyph,
  success: _glyph,
  info: _glyph,
  warning: _glyph,
  error: _glyph,
  empty: _glyph,
  sidebarExpand: _glyph,
  sidebarCollapse: _glyph,
);

FrostLabels testLabels(BuildContext context) => const FrostLabels(
  retry: 'L.retry',
  error: 'L.error',
  errorDetails: 'L.errorDetails',
  copyDetails: 'L.copyDetails',
  detailsCopied: 'L.detailsCopied',
  loading: 'L.loading',
  loadFailed: 'L.loadFailed',
  noMoreItems: 'L.noMoreItems',
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
  clearText: 'L.clearText',
  search: 'L.search',
  dismiss: 'L.dismiss',
);

final testErrors = FrostErrorPresenter(message: (context, error) => 'E.message($error)', details: (error) => 'E.details($error)');

final testConfig = FrostConfig(palettes: FrostPalettes.pink, fonts: testFonts, icons: testIcons, labels: testLabels, errors: testErrors);

/// [child] inside a Frost theme, scope and toast host, on a desktop-sized
/// surface unless [size] says otherwise.
Widget frostTestApp(Widget child, {Brightness brightness = Brightness.light, bool reduceTransparency = false}) => FrostScope(
  config: testConfig,
  reduceTransparency: reduceTransparency,
  child: MaterialApp(
    theme: FrostTheme.build(config: testConfig, brightness: brightness, platform: TargetPlatform.windows, locale: const Locale('en')),
    builder: (context, child) => FrostToastHost(child: child!),
    home: child,
  ),
);
