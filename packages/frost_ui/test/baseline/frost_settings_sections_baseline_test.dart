import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _noop() {}
void _select(int index) {}

const _labels = ['Appearance', 'Network', 'Storage'];
const _icons = [baselineIcon, baselineIcon, baselineIcon];
const _header = SizedBox(height: 52, child: FrostText('Settings header', tone: FrostTextTone.primary));
const _status = FrostListRow(title: 'Unsaved changes');

// The page-level layouts fill their parent: a fixed height, wide and narrow.
// The layout switches at 612 (navigation 236,
// content inset 32, form 320 and the 24 page inset).
final _wide = BaselineEnv.standard.copyWith(width: 1280);
final _narrow = BaselineEnv.narrow;
final _wideOrNarrow = [_wide, _narrow];
final _builderThreshold = [BaselineEnv.standard.copyWith(width: 611), BaselineEnv.standard.copyWith(width: 612)];

Widget _section(BuildContext context, int index) => CustomScrollView(
  slivers: [
    FrostSliverContentColumn(
      sliver: SliverToBoxAdapter(
        child: FrostGroupedSection(
          header: _labels[index],
          children: [for (var row = 0; row < 3; row++) FrostListRow(title: '${_labels[index]} row $row')],
        ),
      ),
    ),
  ],
);

Widget _compactNavigation(BuildContext context) => ListView(
  padding: const EdgeInsets.all(16),
  children: const [
    FrostGroupedSection(
      children: [
        FrostListRow(title: 'Appearance', subtitle: FrostRowSubtitle('Dark')),
        FrostListRow(title: 'Network', subtitle: FrostRowSubtitle('Proxy on')),
        FrostListRow(title: 'Storage', subtitle: FrostRowSubtitle('4 GB')),
      ],
    ),
  ],
);

const _routedSection = ColoredBox(
  color: Color(0x33888888),
  child: Center(child: FrostText('Routed section page', tone: FrostTextTone.primary)),
);

const _detail = ColoredBox(
  color: Color(0x33888888),
  child: Center(child: FrostText('Detail pane', tone: FrostTextTone.primary)),
);

// The old builder's flat arguments, in the new spelling. A close callback
// without a detail was inert and has no spelling: the detail is omitted.
FrostSettingsSections _builder({
  List<String> labels = _labels,
  int selectedIndex = 0,
  List<FrostIconData>? icons,
  WidgetBuilder? compactNavigationBuilder,
  Widget? header,
  Widget? section,
  ValueChanged<int>? onNavigate,
  Widget? detail,
  VoidCallback? onCloseDetail,
  Widget? status,
}) => FrostSettingsSections(
  labels: labels,
  selectedIndex: selectedIndex,
  onSelected: _select,
  sectionBuilder: _section,
  icons: icons,
  compact: compactNavigationBuilder == null && section == null && onNavigate == null
      ? null
      : FrostSectionsCompact(navigationBuilder: compactNavigationBuilder, section: section, onNavigate: onNavigate),
  header: header,
  detail: detail == null ? null : FrostSectionsDetail(child: detail, onClose: onCloseDetail ?? _noop),
  status: status,
);

Future<void> _tapNetwork(WidgetTester tester, Finder subject) async {
  await tester.tap(find.descendant(of: subject, matching: find.text('Network')));
}

Future<void> _hoverNetwork(WidgetTester tester, Finder subject) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await gesture.moveTo(tester.getCenter(find.descendant(of: subject, matching: find.text('Network'))));
}

void main() {
  baselineGroup('FrostSettingsSections', [
    // .builder
    BaselineCase(
      'FrostSettingsSections.builder/required',
      (_) => _builder(),
      height: 700,
      envs: [..._wideOrNarrow, ..._builderThreshold, BaselineEnv.light, BaselineEnv.largeText.copyWith(width: 1280), BaselineEnv.touch.copyWith(width: 1280)],
    ),
    BaselineCase('FrostSettingsSections.builder/selectedIndex=1', (_) => _builder(selectedIndex: 1), height: 700, envs: _wideOrNarrow),
    BaselineCase('FrostSettingsSections.builder/required#hover', (_) => _builder(), height: 700, act: _hoverNetwork, envs: [_wide]),
    BaselineCase('FrostSettingsSections.builder/required#select', (_) => _builder(), height: 700, act: _tapNetwork, envs: [_wide]),
    BaselineCase('FrostSettingsSections.builder/labels=empty', (_) => _builder(labels: const [], selectedIndex: 0), height: 400, envs: [_wide]),
    BaselineCase('FrostSettingsSections.builder/icons', (_) => _builder(icons: _icons), height: 700, envs: _wideOrNarrow),
    BaselineCase('FrostSettingsSections.builder/header', (_) => _builder(header: _header), height: 700, envs: _wideOrNarrow),
    BaselineCase('FrostSettingsSections.builder/status', (_) => _builder(status: _status), height: 700, envs: _wideOrNarrow),
    BaselineCase(
      'FrostSettingsSections.builder/compactNavigationBuilder',
      (_) => _builder(compactNavigationBuilder: _compactNavigation),
      height: 700,
      envs: _wideOrNarrow,
    ),
    BaselineCase('FrostSettingsSections.builder/section', (_) => _builder(section: _routedSection), height: 700, envs: _wideOrNarrow),
    BaselineCase('FrostSettingsSections.builder/onNavigate', (_) => _builder(onNavigate: _select), height: 700, envs: [_narrow]),
    // Narrow: no section selected shows the navigation, a selected section shows its page.
    BaselineCase(
      'FrostSettingsSections.builder/compactNavigationBuilder+section=null+onNavigate',
      (_) => _builder(compactNavigationBuilder: _compactNavigation, onNavigate: _select),
      height: 700,
      envs: _wideOrNarrow,
    ),
    BaselineCase(
      'FrostSettingsSections.builder/compactNavigationBuilder+section+onNavigate',
      (_) => _builder(compactNavigationBuilder: _compactNavigation, section: _routedSection, onNavigate: _select),
      height: 700,
      envs: _wideOrNarrow,
    ),
    BaselineCase(
      'FrostSettingsSections.builder/header+compactNavigationBuilder+section+onNavigate',
      (_) => _builder(header: _header, compactNavigationBuilder: _compactNavigation, section: _routedSection, onNavigate: _select),
      height: 700,
      envs: _wideOrNarrow,
    ),
    // Wide: detail layers over the selected pane.
    BaselineCase(
      'FrostSettingsSections.builder/detail+onCloseDetail',
      (_) => _builder(detail: _detail, onCloseDetail: _noop),
      height: 700,
      envs: _wideOrNarrow,
    ),
    BaselineCase(
      'FrostSettingsSections.builder/header+detail+onCloseDetail',
      (_) => _builder(header: _header, detail: _detail, onCloseDetail: _noop),
      height: 700,
      envs: [_wide],
    ),
    BaselineCase(
      'FrostSettingsSections.builder/status+detail+onCloseDetail',
      (_) => _builder(status: _status, detail: _detail, onCloseDetail: _noop),
      height: 700,
      envs: [_wide],
    ),
    BaselineCase('FrostSettingsSections.builder/onCloseDetail', (_) => _builder(onCloseDetail: _noop), height: 700, envs: [_wide]),
  ]);
}
