import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:frost_ui/frost_ui.dart';

// Manual test bench for the native window: caption drag and double-click,
// edge and corner resizing (including over the right-edge scrollbar), Snap
// Layouts on the maximize button, the system menu (right-click, Alt+Space),
// Back (Alt+Left, mouse back button) and keyboard/IME input in a text field.

final _config = FrostConfig(
  palettes: FrostPalettes.pink,
  fonts: const FrostFonts(japanese: 'Yu Gothic UI', simplifiedChinese: 'Microsoft YaHei UI', defaultScript: FrostContentScript.japanese),
  icons: const FrostIconSet(
    back: FrostIconData.glyph(Icons.arrow_back),
    close: FrostIconData.glyph(Icons.close),
    more: FrostIconData.glyph(Icons.more_horiz),
    expand: FrostIconData.glyph(Icons.expand_more),
    collapse: FrostIconData.glyph(Icons.expand_less),
    chevronLeft: FrostIconData.glyph(Icons.chevron_left),
    chevronRight: FrostIconData.glyph(Icons.chevron_right),
    chevronDown: FrostIconData.glyph(Icons.keyboard_arrow_down),
    arrowDown: FrostIconData.glyph(Icons.arrow_downward),
    refresh: FrostIconData.glyph(Icons.refresh),
    copy: FrostIconData.glyph(Icons.copy),
    search: FrostIconData.glyph(Icons.search),
    check: FrostIconData.glyph(Icons.check),
    success: FrostIconData.glyph(Icons.check_circle),
    info: FrostIconData.glyph(Icons.info_outline),

    error: FrostIconData.glyph(Icons.error_outline),
    empty: FrostIconData.glyph(Icons.inbox_outlined),
    sidebarExpand: FrostIconData.glyph(Icons.keyboard_double_arrow_right),
    sidebarCollapse: FrostIconData.glyph(Icons.keyboard_double_arrow_left),
    forward: FrostIconData.glyph(Icons.arrow_forward),
    chevronUp: FrostIconData.glyph(Icons.keyboard_arrow_up),
    chevronUpDown: FrostIconData.glyph(Icons.unfold_more),
    externalLink: FrostIconData.glyph(Icons.open_in_new),
    link: FrostIconData.glyph(Icons.link),
    share: FrostIconData.glyph(Icons.share),
    download: FrostIconData.glyph(Icons.download),
    upload: FrostIconData.glyph(Icons.upload),
    delete: FrostIconData.glyph(Icons.delete_outline),
    edit: FrostIconData.glyph(Icons.edit_outlined),
    add: FrostIconData.glyph(Icons.add),
    remove: FrostIconData.glyph(Icons.remove),
    filter: FrostIconData.glyph(Icons.filter_list),
    sort: FrostIconData.glyph(Icons.sort),
    dragHandle: FrostIconData.glyph(Icons.drag_handle),
    play: FrostIconData.glyph(Icons.play_arrow),
    pause: FrostIconData.glyph(Icons.pause),
    repeat: FrostIconData.glyph(Icons.repeat),
    volumeOn: FrostIconData.glyph(Icons.volume_up),
    volumeOff: FrostIconData.glyph(Icons.volume_off),
    fullscreen: FrostIconData.glyph(Icons.fullscreen),
    exitFullscreen: FrostIconData.glyph(Icons.fullscreen_exit),
    zoomIn: FrostIconData.glyph(Icons.zoom_in),
    zoomOut: FrostIconData.glyph(Icons.zoom_out),
    image: FrostIconData.glyph(Icons.image_outlined),
    imageError: FrostIconData.glyph(Icons.broken_image_outlined),
    multiPage: FrostIconData.glyph(Icons.collections),
    minimize: FrostIconData.glyph(Icons.minimize),
    maximize: FrostIconData.glyph(Icons.crop_square),
    restore: FrostIconData.glyph(Icons.filter_none),
    calendar: FrostIconData.glyph(Icons.calendar_today),
    clock: FrostIconData.glyph(Icons.schedule),
    folder: FrostIconData.glyph(Icons.folder_outlined),
    eye: FrostIconData.glyph(Icons.visibility),
    eyeOff: FrostIconData.glyph(Icons.visibility_off),
    user: FrostIconData.glyph(Icons.person_outline),
    textFormat: FrostIconData.glyph(Icons.text_fields),
  ),
  labels: (context) => const FrostLabels(
    retry: 'Retry window setup',
    retryAfter: _retryAfter,
    error: 'Error',
    errorDetails: 'Details',
    copyDetails: 'Copy',
    copied: 'Copied',
    loading: 'Loading',
    actionSucceeded: 'Action succeeded',
    actionFailed: 'Action failed',
    loadFailed: 'Could not load',
    noMoreItems: 'Nothing more',
    noItems: 'No items',
    pullToRefresh: 'Pull to refresh',
    releaseToRefresh: 'Release to refresh',
    refreshing: 'Refreshing',
    refreshComplete: 'Updated',
    refreshFailed: 'Refresh failed',
    previous: 'Previous',
    next: 'Next',
    back: 'Back',
    more: 'More',
    expandNavigation: 'Expand',
    collapseNavigation: 'Collapse',
    navigationStatus: _navigationStatus,
    clearText: 'Clear',
    search: 'Search',
    noResults: _noResults,
    clearSearch: 'Clear search',
    dismiss: 'Dismiss',
    expandText: 'expandText',
    collapseText: 'collapseText',
    showAll: 'showAll',
    copy: 'copy',
    clearAll: 'clearAll',
    showPassword: 'showPassword',
    hidePassword: 'hidePassword',
    chooseDate: 'chooseDate',
    chooseTime: 'chooseTime',
    increment: 'increment',
    decrement: 'decrement',
    reorderHandle: 'reorderHandle',
    sortAscending: 'sortAscending',
    sortDescending: 'sortDescending',
    play: 'play',
    pause: 'pause',
    loop: 'Loop',
    mute: 'mute',
    unmute: 'unmute',
    fullscreen: 'fullscreen',
    exitFullscreen: 'exitFullscreen',
    minimize: 'Minimize',
    maximize: 'Maximize',
    restore: 'Restore',
    close: 'Close',
    cancel: 'Cancel',
    apply: 'Apply',
    clear: 'Clear',
    choose: 'Choose…',
    showInFolder: 'Show in folder',
    selectedCount: _selectedCount,
    pageOf: _pageOf,
    selectAll: 'Select all',
    done: 'Done',
    itemPosition: _itemPosition,
    tableDimensions: _tableDimensions,
    taskQueued: 'Queued',
    taskRunning: 'Running',
    taskPaused: 'Paused',
    taskCompleted: 'Completed',
    taskFailed: 'Failed',
    taskCancelled: 'Cancelled',
    remove: 'Remove',
    seek: 'Playback position',
    showReplies: _showReplies,
    moreMedia: _moreMedia,
  ),
  errors: FrostErrorPresenter(message: (context, error) => 'Something went wrong', details: (error) => '$error'),
);

final _window = FrostWindowController(minimumSize: const Size(480, 360), diagnosticWriter: (diagnostic) async => debugPrint('frost_window: $diagnostic'));

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  await _window.prepare();
  runApp(const ExampleApp());
  // The runner stays hidden; never show its template rectangle for one frame.
  await binding.waitUntilFirstFrameRasterized;
  await _window.show();
}

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  FrostThemeMode _mode = FrostThemeMode.light;
  bool _mica = true;
  int _selected = 0;
  final _homeKey = GlobalKey<_HomePageState>();
  late final _delegate = _ExampleRouter((context) => _HomePage(key: _homeKey, settings: _settings()));
  late final _router = RouterConfig<Object>(routerDelegate: _delegate);

  void _change(VoidCallback change) {
    setState(change);
    _delegate.refresh();
  }

  void _back() {
    final navigator = _delegate.navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
    } else {
      _homeKey.currentState?._back();
    }
  }

  Widget _settings() => Wrap(
    spacing: FrostGap.related,
    runSpacing: FrostGap.related,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      FrostButton(
        label: 'Toggle light and dark',
        size: FrostControlSize.compact,
        onPressed: () => _change(() => _mode = _mode == FrostThemeMode.dark ? FrostThemeMode.light : FrostThemeMode.dark),
      ),
      FrostButton(label: _mica ? 'Mica: on' : 'Mica: off', size: FrostControlSize.compact, onPressed: () => _change(() => _mica = !_mica)),
    ],
  );

  @override
  void dispose() {
    _delegate.dispose();
    _window.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FrostApp.router(
    config: _config,
    title: 'Frost shell',
    routerConfig: _router,
    density: FrostDensity.compact,
    appearance: FrostAppearance(mode: _mode, lightAccent: _config.palettes.accentPresets.first, darkAccent: _config.palettes.accentPresets.first),
    builder: (context, child) => FrostWindowHost(
      backdrop: _mica ? FrostWindowBackdrop.mica : FrostWindowBackdrop.none,
      controller: _window,
      title: 'Frost shell · native window check',
      child: FrostShell(
        destinations: const [
          FrostNavDestination(icon: FrostIconData.glyph(Icons.home_outlined), label: 'Home'),
          FrostNavDestination(icon: FrostIconData.glyph(Icons.search), label: 'Search'),
          FrostNavDestination(icon: FrostIconData.glyph(Icons.download_outlined), label: 'Downloads'),
          FrostNavDestination(icon: FrostIconData.glyph(Icons.settings_outlined), label: 'Settings'),
        ],
        selectedIndex: _selected,
        atDestinationRoot: true,
        onDestinationSelected: (value) => setState(() => _selected = value),
        canGoBack: true,
        onBack: _back,
        showsMobileNavigation: true,
        initiallyExpanded: true,
        brand: const FrostShellBrand(expanded: FrostText('Frost', role: FrostTextRole.headline)),
        child: child!,
      ),
    ),
  );
}

class _ExampleRouter extends RouterDelegate<Object> with ChangeNotifier, PopNavigatorRouterDelegateMixin<Object> {
  _ExampleRouter(this.builder);
  void refresh() => notifyListeners();
  final WidgetBuilder builder;
  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  @override
  Future<void> setNewRoutePath(Object configuration) async {}
  @override
  Widget build(BuildContext context) => Navigator(
    key: navigatorKey,
    pages: [
      MaterialPage<void>(
        child: FrostShellDestination(child: Builder(builder: builder)),
      ),
    ],
    onDidRemovePage: (_) {},
  );
}

class _HomePage extends StatefulWidget {
  const _HomePage({required this.settings, super.key});
  final Widget settings;
  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  // The header uses the same input base for plain text and completed tokens.
  final _search = FrostTokenEditingController(
    rules: [FrostTokenRule(pattern: RegExp(r'^#'), tone: FrostTokenTone.accent)],
  );
  final _searchFocus = FocusNode();
  final _scroll = ScrollController();
  int _backs = 0;
  int _source = 0;
  static const _sourceNames = ['Primary source · public works library', 'Fallback source · local works library'];
  int _mode = 0;
  String _period = 'This week';
  String _feedback = 'Drag the top blank area or the brand; the header and input area must not drag the window.';

  void _report(String message) {
    if (mounted) setState(() => _feedback = message);
  }

  void _back() => setState(() {
    _backs++;
    _feedback = 'Back requests received: $_backs (Alt+Left / mouse back)';
  });
  Future<void> _systemMenu() async {
    try {
      await _window.showSystemMenu();
    } on FrostWindowFailure {
      _report('System menu unavailable; retry window setup');
    }
  }

  Future<void> _push() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const _DetailPage()));
    if (mounted) _report('Returned from the detail page');
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Actions(
    actions: {
      FrostBackIntent: CallbackAction<FrostBackIntent>(
        onInvoke: (_) {
          _back();
          return null;
        },
      ),
    },
    child: Focus(
      autofocus: true,
      child: FrostPinnedChrome(
        chrome: FrostPageHeader(
          title: FrostTitleMenu(
            title: _sourceNames[_source],
            entries: [
              FrostMenuSection(
                header: 'Source',
                entries: [for (var i = 0; i < 2; i++) FrostMenuAction(_sourceNames[i], checked: _source == i, onSelected: () => setState(() => _source = i))],
              ),
            ],
          ),
          middle: FrostSearchInput(controller: _search, focusNode: _searchFocus, placeholder: 'Search', onSubmitted: (value) => _report('Search submitted: $value')),
          collapsedMiddle: FrostButton.icon(label: 'Search', icon: _config.icons.search, onPressed: () => _report('Narrow window search entry')),
          actions: [
            FrostToolbarItem.picker(
              choices: const [
                FrostPickerOption(value: 0, label: 'Latest'),
                FrostPickerOption(value: 1, label: 'Popular'),
                FrostPickerOption(value: 2, label: 'History'),
              ],
              value: _mode,
              onChanged: (value) => setState(() => _mode = value),
              label: 'Browse mode',
            ),
            FrostToolbarItem.menu(
              label: _period,
              entries: [
                FrostMenuSection(
                  header: 'Time range',
                  entries: [
                    for (final period in ['Today', 'This week', 'This month'])
                      FrostMenuAction(period, checked: _period == period, onSelected: () => setState(() => _period = period)),
                  ],
                ),
                const FrostMenuDivider(),
                FrostMenuAction('Choose date…', leading: FrostGlyph.icon(_config.icons.calendar), onSelected: () => _report('Opened the date picker entry (sample message)')),
              ],
            ),
            FrostToolbarItem.action(icon: _config.icons.refresh, label: 'Refresh content', showsLabel: true, onPressed: () => _report('Content refreshed')),
            FrostToolbarItem.action(icon: _config.icons.forward, label: 'Open detail page', priority: FrostToolbarPriority.high, onPressed: () => unawaited(_push())),
            FrostToolbarItem.action(icon: _config.icons.download, label: 'Downloads', priority: FrostToolbarPriority.low, onPressed: () => _report('Sample download action')),
          ],
        ),
        body: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: Scrollbar(
            controller: _scroll,
            thumbVisibility: true,
            child: CustomScrollView(
              controller: _scroll,
              slivers: [
                const FrostChromeSpacer(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: FrostGap.of(context).page),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        widget.settings,
                        const SizedBox(height: FrostGap.related),
                        const FrostText('Header and native window check', role: FrostTextRole.title2),
                        const SizedBox(height: FrostGap.related),
                        Semantics(
                          liveRegion: true,
                          child: FrostText(_feedback, role: FrostTextRole.footnote, tone: FrostTextTone.secondary, maxLines: 2),
                        ),
                        ValueListenableBuilder(
                          valueListenable: _window,
                          builder: (context, state, _) => FrostText(
                            'backdrop: ${state.backdropActive} · solid: ${state.reduceTransparency} · ready: ${_window.ready} · failed: ${_window.failed} ${_window.failureCode ?? ''} · active: ${state.active} · maximized: ${state.maximized} · dpr: ${MediaQuery.devicePixelRatioOf(context)} · revision: ${state.revision}',
                            role: FrostTextRole.caption,
                            tone: FrostTextTone.tertiary,
                            maxLines: 2,
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: FrostButton.plain(label: 'System menu', size: FrostControlSize.compact, onPressed: () => unawaited(_systemMenu())),
                        ),
                        const TextField(
                          decoration: InputDecoration(labelText: 'Keyboard and IME input', hintText: 'Type here, including CJK IME input'),
                        ),
                        const SizedBox(height: FrostGap.related),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.only(
                    left: FrostGap.of(context).page,
                    right: FrostGap.of(context).page,
                    bottom: FrostGap.of(context).page + MediaQuery.paddingOf(context).bottom,
                  ),
                  sliver: SliverList.builder(
                    itemCount: 60,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: FrostGap.related),
                      child: FrostText('Row ${index + 1} · drag the scrollbar on the right and check that the resize border stays out of the content', tone: FrostTextTone.secondary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _DetailPage extends StatelessWidget {
  const _DetailPage();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FrostPageHeader(
        title: const Text('Detail page'),
        actions: [
          FrostToolbarItem.action(icon: _config.icons.copy, label: 'Copy', onPressed: () => FrostToast.info('Sample copy triggered')),
          FrostToolbarItem.action(icon: _config.icons.info, label: 'Info', onPressed: () => FrostToast.info('Plain title with two actions')),
        ],
      ),
      const Expanded(child: Center(child: FrostText('Alt+Left or mouse back returns; the title row stays usable.'))),
    ],
  );
}

String _selectedCount(int count) => 'Selected $count';
String _noResults(String query) => 'No results for “$query”';
String _pageOf(int page, int total) => '$page of $total';

String _itemPosition(int position, int total) => '$position / $total';

String _tableDimensions(int rows, int columns) => '$rows × $columns';

String _showReplies(int count) => 'Show $count replies';
String _moreMedia(int count) => '+$count';

String _navigationStatus(int count, int? progressPercent) => [if (count > 0) '$count items', if (progressPercent != null) '$progressPercent%'].join(', ');

String _retryAfter(int seconds) => 'Retry in ${seconds}s';
