import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/desktop.dart';
import 'package:frost_ui/frost_ui.dart';

import '../support.dart';
import '../window_caption_test.dart' show FakeWindow;
import 'baseline.dart';
import 'nav_overlay_support.dart';

void _noop() {}
void _select(int _) {}
void _expanded(bool _) {}

const _home = FrostNavDestination(icon: baselineIcon, label: 'Home');
const _search = FrostNavDestination(icon: baselineIcon, label: 'Search');
const _library = FrostNavDestination(icon: baselineIcon, label: 'Library');
const _settings = FrostNavDestination(icon: baselineIcon, label: 'Settings');
const _downloads = FrostNavDestination(icon: baselineIcon, label: 'Downloads');
const _primary = [_home, _search];
const _secondary = [_settings, _downloads];
const _badged = [
  FrostNavDestination(icon: baselineIcon, label: 'Home', badge: 7),
  FrostNavDestination(icon: baselineIcon, label: 'Search', badge: 120, badgeTone: FrostCountBadgeTone.negative),
  FrostNavDestination(icon: baselineIcon, label: 'Library', progress: .4),
  FrostNavDestination(icon: baselineIcon, label: 'Account', badge: 2, progress: 1),
];

const _brand = Text('Frost Family', maxLines: 1, overflow: TextOverflow.ellipsis);
const _brandIcon = SizedBox(width: 24, height: 24, child: FrostIcon(baselineIcon));

// The page of a destination: a header (for Back and Back to first in bottom
// navigation) above a body.
Widget _page({bool header = false}) => FrostShellDestination(
  child: header
      ? const Column(
          children: [
            FrostPageHeader(title: Text('Detail')),
            Expanded(child: Center(child: Text('Page'))),
          ],
        )
      : const Center(child: Text('Page')),
);

FrostShellTabs<Object> _tabs({bool base = false}) {
  final controller = base ? FrostTabsController<Object>.withBaseTab(baseTab: 'Home') : FrostTabsController<Object>(initial: 'Home');
  controller.open('Page two');
  return FrostShellTabs<Object>(
    controller: controller,
    label: (_, tab) => FrostTabLabel(title: '$tab'),
    countLabel: (count) => '$count tabs',
    closeTooltip: 'Close tab',
    newTabTooltip: 'New tab',
  );
}

/// Every FrostShell argument, defaulting to the required-only call. [caption]
/// puts the shell in a window with client caption controls.
Widget _shell({
  List<FrostNavDestination> destinations = _primary,
  int? selectedIndex = 0,
  bool atDestinationRoot = true,
  bool canGoBack = false,
  bool showsMobileNavigation = true,
  FrostShellSecondary? secondary,
  bool? initiallyExpanded,
  ValueChanged<bool>? onExpandedChanged,
  FrostShellBrand? brand,
  Widget? titleBarContent,
  FrostShellTabs<Object>? tabs,
  FrostNavigationPlacement? navigationPlacement,
  FrostSidebarAlignment? sidebarAlignment,
  int? routeDepth,
  FrostShellBackToFirst? backToFirst,
  bool header = false,
  bool caption = false,
}) {
  Widget shell = FrostShell(
    destinations: destinations,
    selectedIndex: selectedIndex,
    atDestinationRoot: atDestinationRoot,
    onDestinationSelected: _select,
    canGoBack: canGoBack,
    onBack: _noop,
    showsMobileNavigation: showsMobileNavigation,
    secondary: secondary,
    initiallyExpanded: initiallyExpanded ?? false,
    onExpandedChanged: onExpandedChanged,
    brand: brand,
    titleBarContent: titleBarContent,
    tabs: tabs,
    navigationPlacement: navigationPlacement,
    sidebarAlignment: sidebarAlignment ?? FrostSidebarAlignment.automatic,
    routeDepth: routeDepth ?? 0,
    backToFirst: backToFirst,
    child: _page(header: header),
  );
  if (caption) shell = FrostWindowCaptionScope(window: FakeWindow(), child: shell);
  return windowed(shell);
}

Finder _item(String label) => find.byWidgetPredicate((w) => w is FrostNavItem && w.label == label);

Future<void> _hoverItem(WidgetTester tester, Finder subject) => baselineHover(tester, _item('Search'));
Future<void> _pressItem(WidgetTester tester, Finder subject) => baselinePress(tester, _item('Search'));
Future<void> _toggle(WidgetTester tester, Finder subject) => tester.tap(findFrostTooltip('L.expandNavigation'));
Future<void> _openMore(WidgetTester tester, Finder subject) => tester.tap(_item('L.more'));
Future<void> _collapse(WidgetTester tester, Finder subject) => tester.tap(findFrostTooltip('L.collapseNavigation'));

const _h = 820.0;

BaselineCase _c(String id, Widget Function() build, {List<BaselineEnv> envs = const [wide, medium], BaselineAct? act}) =>
    BaselineCase(id, (_) => build(), height: _h, envs: envs, act: act);

FrostShellSecondary _secondaryOf(List<FrostNavDestination> destinations, {int? selectedIndex}) =>
    FrostShellSecondary(destinations: destinations, selectedIndex: selectedIndex, onSelected: _select);

const _backToFirst = FrostShellBackToFirst(label: 'Back to first', icon: baselineIcon, onPressed: _noop);

// A label that needs more than the widest expanded sidebar (240).
const _long = [FrostNavDestination(icon: baselineIcon, label: 'Notifications and alerts'), FrostNavDestination(icon: baselineIcon, label: 'Search')];

void main() {
  baselineGroup('FrostShell', [
    // Required arguments only, collapsed and in the three widths and the touch phone.
    _c(
      'FrostShell/required',
      () => _shell(),
      envs: [
        ...pageEnvs,
        wide.copyWith(brightness: Brightness.light),
        wide.copyWith(textScale: 2),
        wide.copyWith(input: BaselineInput.touch),
      ],
    ),
    _c('FrostShell/required#hover', () => _shell(), act: _hoverItem),
    _c('FrostShell/required#press', () => _shell(), act: _pressItem),
    _c('FrostShell/required#focus', () => _shell(), act: baselineFocus),
    _c('FrostShell/selectedIndex=null', () => _shell(selectedIndex: null), envs: [wide, narrowTouch]),
    _c('FrostShell/atDestinationRoot=false', () => _shell(atDestinationRoot: false)),
    _c('FrostShell/canGoBack', () => _shell(canGoBack: true), envs: pageEnvs),
    _c('FrostShell/showsMobileNavigation=false', () => _shell(showsMobileNavigation: false), envs: [wide, narrowTouch]),
    _c('FrostShell/destinations=three', () => _shell(destinations: const [_home, _search, _library]), envs: pageEnvs),
    _c('FrostShell/destinations=one', () => _shell(destinations: const [_home]), envs: [wide, narrowTouch]),

    // Expansion: the sidebar sits beside the page from 1200; below it stays collapsed.
    _c(
      'FrostShell/initiallyExpanded',
      () => _shell(initiallyExpanded: true),
      envs: [
        ...pageEnvs,
        wide.copyWith(brightness: Brightness.light),
        wide.copyWith(textScale: 2),
      ],
    ),
    _c('FrostShell/initiallyExpanded#hover', () => _shell(initiallyExpanded: true), act: _hoverItem),
    _c('FrostShell/initiallyExpanded#press', () => _shell(initiallyExpanded: true), act: _pressItem),
    _c('FrostShell/onExpandedChanged#toggle', () => _shell(onExpandedChanged: _expanded), act: _toggle),
    _c('FrostShell/onExpandedChanged', () => _shell(onExpandedChanged: _expanded)),

    // secondary: FrostShellSecondary(destinations, selectedIndex, onSelected).
    // The ids keep the names of the arguments it replaced.
    _c(
      'FrostShell/secondaryDestinations+selectedSecondaryIndex+onSecondarySelected',
      () => _shell(secondary: _secondaryOf(_secondary, selectedIndex: 1)),
      envs: pageEnvs,
    ),
    _c(
      'FrostShell/secondaryDestinations+selectedSecondaryIndex+onSecondarySelected+initiallyExpanded',
      () => _shell(secondary: _secondaryOf(_secondary, selectedIndex: 1), initiallyExpanded: true),
      envs: [wide, medium],
    ),
    _c(
      'FrostShell/secondaryDestinations+selectedSecondaryIndex+onSecondarySelected#open',
      () => _shell(secondary: _secondaryOf(_secondary, selectedIndex: 1)),
      act: _openMore,
      envs: [medium],
    ),
    _c('FrostShell/secondaryDestinations+onSecondarySelected', () => _shell(secondary: _secondaryOf(_secondary)), envs: [wide, medium]),
    _c('FrostShell/secondaryDestinations+onSecondarySelected+initiallyExpanded', () => _shell(secondary: _secondaryOf(_secondary), initiallyExpanded: true)),
    _c(
      'FrostShell/secondaryDestinations+onSecondarySelected#open',
      () => _shell(secondary: _secondaryOf(_secondary)),
      act: _openMore,
      envs: [medium],
    ),
    // The old spelling without a callback rendered like the one with it.
    _c('FrostShell/secondaryDestinations', () => _shell(secondary: _secondaryOf(_secondary))),
    _c(
      'FrostShell/secondaryDestinations+selectedSecondaryIndex+onSecondarySelected+selectedIndex=null',
      () => _shell(secondary: _secondaryOf(_secondary, selectedIndex: 0), selectedIndex: null, initiallyExpanded: true),
    ),

    // brand: FrostShellBrand(expanded, icon, label), ids named after the old arguments.
    _c(
      'FrostShell/brand+brandIcon+brandLabel',
      () => _shell(
        brand: const FrostShellBrand(expanded: _brand, icon: _brandIcon, label: 'Frost Family'),
        canGoBack: true,
      ),
      envs: pageEnvs,
    ),
    _c(
      'FrostShell/brand+brandIcon+brandLabel+initiallyExpanded',
      () => _shell(
        brand: const FrostShellBrand(expanded: _brand, icon: _brandIcon, label: 'Frost Family'),
        canGoBack: true,
        initiallyExpanded: true,
      ),
      envs: pageEnvs,
    ),
    _c(
      'FrostShell/brand+brandIcon+brandLabel#caption',
      () => _shell(
        brand: const FrostShellBrand(expanded: _brand, icon: _brandIcon, label: 'Frost Family'),
        canGoBack: true,
        caption: true,
      ),
    ),
    _c(
      'FrostShell/brand+brandIcon+brandLabel+initiallyExpanded#caption',
      () => _shell(
        brand: const FrostShellBrand(expanded: _brand, icon: _brandIcon, label: 'Frost Family'),
        canGoBack: true,
        initiallyExpanded: true,
        caption: true,
      ),
    ),
    _c('FrostShell/brand', () => _shell(brand: const FrostShellBrand(expanded: _brand), canGoBack: true, initiallyExpanded: true)),
    _c('FrostShell/brand#caption', () => _shell(brand: const FrostShellBrand(expanded: _brand), canGoBack: true, caption: true)),
    _c(
      'FrostShell/brandIcon',
      () => _shell(brand: const FrostShellBrand(icon: _brandIcon)),
      envs: [wide, narrowTouch],
    ),
    _c('FrostShell/brandIcon#caption', () => _shell(brand: const FrostShellBrand(icon: _brandIcon), caption: true)),
    _c(
      'FrostShell/brandLabel',
      () => _shell(brand: const FrostShellBrand(label: 'Frost Family')),
      envs: [wide, narrowTouch],
    ),
    _c('FrostShell/brandLabel#caption', () => _shell(brand: const FrostShellBrand(label: 'Frost Family'), caption: true)),
    _c(
      'FrostShell/brand=long',
      () => _shell(
        brand: const FrostShellBrand(expanded: Text('A very long application name that cannot fit', maxLines: 1, overflow: TextOverflow.ellipsis)),
        initiallyExpanded: true,
      ),
    ),

    // backToFirst: FrostShellBackToFirst(label, icon, onPressed), shown by page
    // headers in bottom navigation once the route is two levels deep. The ids
    // keep the names of the arguments it replaced.
    _c(
      'FrostShell/onBackToFirst+backToFirstLabel+backToFirstIcon',
      () => _shell(canGoBack: true, routeDepth: 2, backToFirst: _backToFirst, header: true),
      envs: pageEnvs,
    ),
    _c(
      'FrostShell/onBackToFirst+backToFirstLabel+backToFirstIcon+initiallyExpanded',
      () => _shell(canGoBack: true, routeDepth: 2, backToFirst: _backToFirst, header: true, initiallyExpanded: true),
      envs: [wide],
    ),
    _c('FrostShell/routeDepth=1', () => _shell(canGoBack: true, routeDepth: 1, backToFirst: _backToFirst, header: true), envs: [wide, narrowTouch]),
    _c('FrostShell/routeDepth=3', () => _shell(canGoBack: true, routeDepth: 3, header: true), envs: [wide, narrowTouch]),

    // The inset sidebar, formerly sidebarStyle=inset, is the only sidebar.
    _c(
      'FrostShell/sidebarStyle=inset',
      () => _shell(),
      envs: [
        ...pageEnvs,
        wide.copyWith(brightness: Brightness.light),
      ],
    ),
    _c('FrostShell/sidebarStyle=inset+initiallyExpanded', () => _shell(initiallyExpanded: true, canGoBack: true)),
    _c(
      'FrostShell/sidebarStyle=inset+secondaryDestinations#open',
      () => _shell(secondary: _secondaryOf(_secondary, selectedIndex: 0)),
      act: _openMore,
      envs: [medium],
    ),
    _c('FrostShell/sidebarStyle=inset+secondaryDestinations', () => _shell(secondary: _secondaryOf(_secondary, selectedIndex: 0))),
    _c('FrostShell/sidebarStyle=inset#hover', () => _shell(), act: _hoverItem, envs: [wide]),

    // The standard geometry, formerly metrics=standard: collapsed 60, expanded
    // 176 for labels that fit, expandable from 1200.
    _c('FrostShell/metrics=standard', () => _shell(), envs: pageEnvs),
    _c('FrostShell/metrics=standard+initiallyExpanded', () => _shell(initiallyExpanded: true)),

    // The expanded width follows the longest label up to 240; past it, labels
    // end in an ellipsis.
    _c('FrostShell/destinations=long', () => _shell(destinations: _long)),
    _c(
      'FrostShell/destinations=long+initiallyExpanded',
      () => _shell(destinations: _long, initiallyExpanded: true),
      envs: [
        wide,
        wide.copyWith(brightness: Brightness.light),
        wide.copyWith(textScale: 2),
      ],
    ),
    _c(
      'FrostShell/destinations=long+secondary+initiallyExpanded',
      () => _shell(destinations: _long, secondary: _secondaryOf(_secondary, selectedIndex: 0), initiallyExpanded: true),
      envs: [wide],
    ),
    _c(
      'FrostShell/destinations=long+initiallyExpanded#toggle',
      () => _shell(destinations: _long, initiallyExpanded: true),
      act: _collapse,
      envs: [wide],
    ),

    // Destinations with badges, tones and progress.
    _c(
      'FrostShell/destinations=badge',
      () => _shell(destinations: _badged),
      envs: [
        ...pageEnvs,
        wide.copyWith(brightness: Brightness.light),
        wide.copyWith(textScale: 2),
      ],
    ),
    _c('FrostShell/destinations=badge+initiallyExpanded', () => _shell(destinations: _badged, initiallyExpanded: true), envs: pageEnvs),
    _c(
      'FrostShell/destinations=badge+secondaryDestinations',
      () => _shell(
        destinations: _badged,
        secondary: _secondaryOf(const [
          FrostNavDestination(icon: baselineIcon, label: 'Downloads', badge: 3, badgeTone: FrostCountBadgeTone.negative, progress: .5),
        ], selectedIndex: 0),
        initiallyExpanded: true,
      ),
    ),
    _c(
      'FrostShell/destinations=builder',
      () => _shell(
        destinations: [
          FrostNavDestination(
            icon: baselineIcon,
            label: 'Home',
            builder: (context, child) => KeyedSubtree(key: const ValueKey('home-anchor'), child: child),
          ),
          _search,
        ],
      ),
      envs: [wide, narrowTouch],
    ),

    // Other optional arguments.
    _c(
      'FrostShell/titleBarContent',
      () => _shell(
        titleBarContent: FrostSearchEntry(placeholder: 'Search everything', shortcutLabel: 'Ctrl K', onPressed: _noop),
      ),
      envs: pageEnvs,
    ),
    _c(
      'FrostShell/titleBarContent#caption',
      () => _shell(
        titleBarContent: FrostSearchEntry(placeholder: 'Search everything', shortcutLabel: 'Ctrl K', onPressed: _noop),
        caption: true,
      ),
    ),
    _c(
      'FrostShell/tabs',
      () => _shell(
        tabs: _tabs(),
        brand: const FrostShellBrand(icon: _brandIcon),
      ),
      envs: [wide, narrowTouch],
    ),
    _c(
      'FrostShell/tabs=baseTab',
      () => _shell(
        tabs: _tabs(base: true),
        brand: const FrostShellBrand(icon: _brandIcon),
        canGoBack: true,
      ),
      envs: [wide, narrowTouch],
    ),
    _c('FrostShell/navigationPlacement=sidebar', () => _shell(navigationPlacement: FrostNavigationPlacement.sidebar), envs: [wide, narrowTouch]),
    _c('FrostShell/navigationPlacement=bottom', () => _shell(navigationPlacement: FrostNavigationPlacement.bottom), envs: [wide, narrow]),
    _c('FrostShell/navigationPlacement=automatic', () => _shell(navigationPlacement: FrostNavigationPlacement.automatic), envs: [wide, narrowTouch]),
    for (final alignment in FrostSidebarAlignment.values)
      _c('FrostShell/sidebarAlignment=${alignment.name}', () => _shell(sidebarAlignment: alignment), envs: [wide, narrowTouch]),
  ]);
}
