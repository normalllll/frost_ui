// Every public component is registered here: as a case of one family, or with
// the reason it has no behaviour of its own to test. coverage_contract_test.dart
// compares this with tool/library_health/public_api.txt.
export 'cases_display.dart';
export 'cases_hiding.dart';
export 'cases_interactive.dart';
export 'cases_overlay.dart';

/// The categories a class without a case may name.
const notApplicableCategories = {'data', 'controller', 'style', 'scope', 'layout-helper'};

/// Classes the decision cases exercise, by the family that holds the case.
const exercisedByDecisions = {
  'FrostApp': 'no-global-highlight',
  'FrostShell': 'shell-esc',
  'FrostSelectableItem': 'desktop-selection',
  'FrostSelection': 'desktop-selection',
  'FrostSelectionScope': 'desktop-selection',
};

/// Classes the overlay cases open although their ids name a show function.
const exercisedByOverlays = {'FrostDialog': 'showFrostDialog'};

/// The cases of the decisions family as `id<TAB>check`; decisions_contract_test.dart must run exactly these.
const decisionIds = {
  'showFrostConfirm	confirm-enter',
  'showFrostFormDialog	menu-enter',
  'FrostShell	shell-esc',
  'FrostButton	focus-ring-mouse',
  'FrostApp	no-global-highlight',
  'FrostListRow.ctrl	desktop-selection',
  'FrostListRow.cmd	desktop-selection',
  'FrostMediaCard.ctrl	desktop-selection',
  'FrostMediaCard.cmd	desktop-selection',
  'showFrostSheet	modal-autofocus',
  'showFrostDialog	modal-autofocus',
  'FrostRefreshView	mouse-drag',
};

/// Every check name, for the rows of allowlist.txt.
const checkNames = {
  'disabled-scope',
  'disabled-semantics',
  'semantics',
  'keyboard',
  'touch-target',
  'text-scale',
  'rtl',
  'reduced-motion',
  'intrinsic',
  'no-theme',
  'hidden-focus',
  'hidden-tap',
  'hidden-ticker',
  'popscope-esc',
  'popscope-close',
  'popscope-drag',
  'popscope-back',
  'barrier',
  'back-only-overlay',
  'esc-only-overlay',
  'confirm-enter',
  'menu-enter',
  'shell-esc',
  'focus-ring-mouse',
  'no-global-highlight',
  'desktop-selection',
  'modal-autofocus',
  'mouse-drag',
};

const _data = [
  // Values and descriptions that other components read
  'FrostActionState',
  'FrostAppearance',
  'FrostBackIntent',
  'FrostBleedSnap',
  'FrostCaptionMetrics',
  'FrostCaptionState',
  'FrostDetailPage',
  'FrostDialogAction',
  'FrostErrorAction',
  'FrostErrorPresenter',
  'FrostFloatingEntryPosition',
  'FrostFontWarmUpSample',
  'FrostGlyph',
  'FrostHitRegion',
  'FrostIconData',
  'FrostIconSet',
  'FrostKeyValue',
  'FrostLabels',
  'FrostLeading',
  'FrostMediaHeroTag',
  'FrostMenuAction',
  'FrostMenuDivider',
  'FrostMenuEntry',
  'FrostMenuSection',
  'FrostMenuSubmenu',
  'FrostNavDestination',
  'FrostPickerOption',
  'FrostRefreshLocators',
  'FrostRowSubtitle',
  'FrostSectionsCompact',
  'FrostSectionsDetail',
  'FrostSelectionAction',
  'FrostShellBackToFirst',
  'FrostShellBrand',
  'FrostShellSecondary',
  'FrostShellTabs',
  'FrostShellTaskEntry',
  'FrostShellTaskPanel',
  'FrostShortcut',
  'FrostSizeLayout',
  'FrostSwipeAction',
  'FrostTab',
  'FrostTabLabel',
  'FrostTableColumn',
  'FrostTableCompactRow',
  'FrostTaskAction',
  'FrostThreadAction',
  'FrostThreadItem',
  'FrostTokenRule',
  'FrostInputCapability',
  'FrostToolbarItem',
  'FrostVideoState',
];

const _controller = [
  'FrostActionRunner',
  'FrostFormDialogController',
  'FrostFormController',
  'FrostMediaViewportController',
  'FrostPageHeaderSearchController',
  'FrostPagerController',
  'FrostTabsController',
  'FrostToast',
  'FrostTokenEditingController',
  'FrostWaterfallController',
  'FrostWindowActions',
  'FrostWindowTitleRegistry',
];

const _style = [
  'FrostCaptionColors',
  'FrostClickShape',
  'FrostConfig',
  'FrostDensity',
  'FrostFonts',
  'FrostGap',
  'FrostMetrics',
  'FrostMotion',
  'FrostPalettes',
  'FrostRadius',
  'FrostSkeletonStyle',
  'FrostSpringCurve',
  'FrostTheme',
  'FrostThemeTokens',
  'FrostTypography',
];

const _scope = [
  // Environment components; they paint nothing of their own or need a native window
  'FrostChromeActiveBody',
  'FrostAmbientBackdropHost',
  'FrostControlScope',
  'FrostFieldScope',
  'FrostFontWarmUp',
  'FrostInputFeedback',
  'FrostLayoutScope',
  'FrostMediaSystemChrome',
  'FrostMediaSystemChromeHost',
  'FrostPageTitle',
  'FrostScope',
  'FrostShellNavigationScope',
  'FrostShortcuts',
  'FrostSurfaceScope',
  'FrostToastHost',
  'FrostWindowCaptionScope',
  'FrostWindowHost',
  'FrostWindowTitleContribution',
  'FrostWindowTitleScope',
];

const _layoutHelper = [
  // Pure layout that only makes sense inside a larger structure
  'FrostMediaHeroSource',
  'FrostRowLeadingExtent',
  'FrostShellDestination',
  'FrostToolbarTitle',
];

/// Classes with no component case, with the category that says why.
final notApplicable = <String, String>{
  for (final name in _data) name: 'data',
  for (final name in _controller) name: 'controller',
  for (final name in _style) name: 'style',
  for (final name in _scope) name: 'scope',
  for (final name in _layoutHelper) name: 'layout-helper',
};
