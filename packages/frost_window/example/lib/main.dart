import 'package:flutter/material.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_window/frost_window.dart';

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
    refresh: FrostIconData.glyph(Icons.refresh),
    copy: FrostIconData.glyph(Icons.copy),
    search: FrostIconData.glyph(Icons.search),
    check: FrostIconData.glyph(Icons.check),
    success: FrostIconData.glyph(Icons.check_circle),
    info: FrostIconData.glyph(Icons.info_outline),
    warning: FrostIconData.glyph(Icons.warning_amber),
    error: FrostIconData.glyph(Icons.error_outline),
    empty: FrostIconData.glyph(Icons.inbox_outlined),
    sidebarExpand: FrostIconData.glyph(Icons.keyboard_double_arrow_right),
    sidebarCollapse: FrostIconData.glyph(Icons.keyboard_double_arrow_left),
  ),
  labels: (context) => const FrostLabels(
    retry: 'Retry',
    error: 'Error',
    errorDetails: 'Details',
    copyDetails: 'Copy',
    detailsCopied: 'Copied',
    loading: 'Loading',
    loadFailed: 'Could not load',
    noMoreItems: 'Nothing more',
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
    clearText: 'Clear',
    search: 'Search',
    dismiss: 'Dismiss',
  ),
  errors: FrostErrorPresenter(message: (context, error) => 'Something went wrong', details: (error) => '$error'),
);

final _window = FrostWindowController(minimumSize: const Size(480, 360), diagnosticWriter: (diagnostic) async => debugPrint('frost_window: $diagnostic'));

void main() => runApp(const ExampleApp());

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  ThemeMode _mode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    ThemeData theme(Brightness brightness) => FrostTheme.build(config: _config, brightness: brightness, platform: platform, locale: const Locale('en'));
    return FrostScope(
      config: _config,
      child: MaterialApp(
        title: 'frost_window example',
        debugShowCheckedModeBanner: false,
        theme: theme(Brightness.light),
        darkTheme: theme(Brightness.dark),
        themeMode: _mode,
        builder: (context, child) => FrostInputFeedback(
          child: FrostAmbientBackdropHost(
            image: null,
            child: FrostWindowFrame(
              controller: _window,
              title: 'Test bench',
              leading: Text('frost_window', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
              labels: const FrostWindowLabels(minimize: 'Minimize', maximize: 'Maximize', restore: 'Restore', close: 'Close', retry: 'Retry window setup'),
              child: child!,
            ),
          ),
        ),
        home: _HomePage(onToggleTheme: () => setState(() => _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark)),
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({required this.onToggleTheme});

  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    return Scaffold(
      // Desktop scroll behaviour adds the scrollbar at the right window edge.
      body: SizedBox.expand(
        child: ListView(
          padding: const EdgeInsets.all(FrostMetrics.pageInset),
          children: [
            ValueListenableBuilder(
              valueListenable: _window,
              builder: (context, state, _) => FrostSurface(
                role: FrostSurfaceRole.glassPanel,
                child: Padding(
                  padding: FrostMetrics.panelPadding,
                  child: Text(
                    'ready: ${_window.ready}  failed: ${_window.failed} ${_window.failureCode ?? ''}\n'
                    'active: ${state.active}  maximized: ${state.maximized}  revision: ${state.revision}',
                    style: TextStyle(color: tokens.textPrimary),
                  ),
                ),
              ),
            ),
            const SizedBox(height: FrostMetrics.itemGap),
            Wrap(
              spacing: FrostMetrics.compactGap,
              runSpacing: FrostMetrics.compactGap,
              children: [
                OutlinedButton(onPressed: () => _window.toggleMaximized(), child: const Text('Maximize / restore')),
                OutlinedButton(onPressed: () => _window.showSystemMenu(), child: const Text('System menu')),
                OutlinedButton(onPressed: onToggleTheme, child: const Text('Toggle dark')),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const _DetailPage())),
                  child: const Text('Push page (then Alt+Left / mouse back)'),
                ),
              ],
            ),
            const SizedBox(height: FrostMetrics.itemGap),
            const TextField(decoration: InputDecoration(hintText: 'Type here, including IME input')),
            const SizedBox(height: FrostMetrics.sectionGap),
            for (var index = 0; index < 60; index++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text('Row $index: drag the scrollbar at the right window edge', style: TextStyle(color: tokens.textSecondary)),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailPage extends StatelessWidget {
  const _DetailPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FrostSurface(
          role: FrostSurfaceRole.glassPanel,
          child: Padding(
            padding: FrostMetrics.panelPadding,
            child: Text('Detail page. Alt+Left or the mouse back button returns.', style: TextStyle(color: FrostThemeTokens.of(context).textPrimary)),
          ),
        ),
      ),
    );
  }
}
