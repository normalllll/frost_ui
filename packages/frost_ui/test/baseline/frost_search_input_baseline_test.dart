import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/search_input.dart' show FrostSearchInputRegion;

import '../support.dart' show searchContent;
import 'baseline.dart';
import 'controls_support.dart';

void _submitted(String _) {}
void _noop() {}

const _compactButton = FrostButton.icon(icon: baselineIcon, label: 'Filters', size: FrostControlSize.compact, onPressed: _noop);

final _plain = [
  FrostSearchSection(
    children: [
      FrostSearchSuggestionRow(label: 'sunset', onSelected: _noop),
      FrostSearchSuggestionRow(label: 'sunrise', onSelected: _noop),
      FrostSearchSuggestionRow(label: 'sundial', onSelected: _noop),
    ],
  ),
];

// Titles, an action, icons, category dots, details, trailing values and remove
// buttons: every part of a suggestion row.
final _rich = [
  FrostSearchSection(
    title: 'Recent',
    actionLabel: 'Clear',
    onAction: _noop,
    children: [
      FrostSearchSuggestionRow(label: 'sunset', icon: baselineIcon, onSelected: _noop, onRemove: _noop),
      FrostSearchSuggestionRow(label: 'sky', dataColor: 2, detail: '98K posts', value: '98K', onSelected: _noop),
      FrostSearchSuggestionRow(label: 'cloud', detail: 'Soft white shapes in the sky', inlineDetail: true, onSelected: _noop),
    ],
  ),
  FrostSearchSection(
    title: 'Tags',
    children: [FrostSearchSuggestionRow(label: 'ocean', onSelected: _noop)],
  ),
];

Widget _search({
  String text = '',
  VoidCallback? onClear,
  VoidCallback? onDismiss,
  List<Widget> actions = const [],
  bool leadingIcon = false,
  bool autofocus = false,
  FrostControlSize? size,
  FrostFieldAppearance? appearance,
}) => BaselineField(
  text: text,
  builder: (_, controller, focus) => FrostSearchInput(
    controller: controller,
    focusNode: focus,
    placeholder: 'Search',
    onSubmitted: _submitted,
    onClear: onClear,
    onDismiss: onDismiss,
    actions: actions,
    leadingIcon: leadingIcon,
    autofocus: autofocus,
    size: size,
    appearance: appearance,
  ),
);

Widget _suggesting({
  String text = '',
  List<Widget> suggestions = const [],
  bool loading = false,
  String? message,
  FrostSuggestionPlacement placement = FrostSuggestionPlacement.overlay,
}) => BaselineField(
  text: text,
  builder: (_, controller, focus) => FrostSearchInput.suggesting(
    controller: controller,
    focusNode: focus,
    placeholder: 'Search',
    onSubmitted: _submitted,
    content: searchContent(suggestions, loading: loading, message: message),
    placement: placement,
  ),
);

Widget _inline({String text = '', List<Widget> suggestions = const [], bool loading = false, String? message}) =>
    _suggesting(text: text, suggestions: suggestions, loading: loading, message: message, placement: FrostSuggestionPlacement.inline);

// A narrow window, as a phone presents the page.
Widget _narrow(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(size: const Size(390, 700)),
    child: child,
  ),
);

// The page flow without a height: the inline list fits its rows. In a page
// column (FrostSearchInputRegion) the rows keep that column instead of taking
// one of their own.
Widget _unbounded(Widget child) => Column(mainAxisSize: MainAxisSize.min, children: [child]);

Future<void> _highlight(WidgetTester tester, Finder subject) async {
  await baselineFocus(tester, subject);
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
}

void main() {
  baselineGroup('FrostSearchInput', [
    BaselineCase('FrostSearchInput/required', (_) => _search(), envs: BaselineEnv.all),
    BaselineCase('FrostSearchInput/controller=text', (_) => _search(text: 'sunset'), envs: BaselineEnv.themes),
    BaselineCase('FrostSearchInput/onClear', (_) => _search(text: 'sunset', onClear: _noop)),
    BaselineCase('FrostSearchInput/onDismiss', (_) => _search(onDismiss: _noop)),
    BaselineCase('FrostSearchInput/actions', (_) => _search(actions: const [_compactButton]), envs: BaselineEnv.themes),
    BaselineCase('FrostSearchInput/leadingIcon', (_) => _search(leadingIcon: true), envs: BaselineEnv.themes),
    BaselineCase('FrostSearchInput/autofocus', (_) => _search(autofocus: true)),
    for (final size in FrostControlSize.values)
      BaselineCase('FrostSearchInput/size=${size.name}', (_) => _search(size: size), envs: [BaselineEnv.standard, BaselineEnv.touch]),
    for (final appearance in FrostFieldAppearance.values)
      BaselineCase('FrostSearchInput/appearance=${appearance.name}', (_) => _search(appearance: appearance), envs: BaselineEnv.themes),

    // FrostSearchInput.suggesting with the default overlay placement. The ids
    // predate the constructor, when these were arguments of the plain field.
    BaselineCase('FrostSearchInput/suggestions', (_) => _suggesting(text: 'sun', suggestions: _plain)),
    BaselineCase(
      'FrostSearchInput/suggestions#open',
      (_) => _suggesting(text: 'sun', suggestions: _plain),
      act: baselineFocus,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostSearchInput/suggestions#open+touch',
      (_) => _suggesting(text: 'sun', suggestions: _plain),
      act: baselineFocus,
      envs: [BaselineEnv.touch],
    ),
    BaselineCase(
      'FrostSearchInput/suggestions=rich#open',
      (_) => _suggesting(text: 'sun', suggestions: _rich),
      act: baselineFocus,
      envs: [BaselineEnv.standard, BaselineEnv.largeText],
    ),
    BaselineCase(
      'FrostSearchInput/suggestions#highlight',
      (_) => _suggesting(text: 'sun', suggestions: _plain),
      act: _highlight,
    ),
    BaselineCase(
      'FrostSearchInput/suggestions=rich#highlight',
      (_) => _suggesting(text: 'sun', suggestions: _rich),
      act: _highlight,
    ),
    BaselineCase('FrostSearchInput/loading', (_) => _suggesting(text: 'sun', loading: true)),
    BaselineCase(
      'FrostSearchInput/loading#open',
      (_) => _suggesting(text: 'sun', loading: true),
      act: baselineFocus,
      envs: BaselineEnv.themes,
    ),
    BaselineCase('FrostSearchInput/message', (_) => _suggesting(text: 'sun', message: 'No matches')),
    BaselineCase(
      'FrostSearchInput/message#open',
      (_) => _suggesting(text: 'sun', message: 'No matches'),
      act: baselineFocus,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostSearchInput/suggestions+loading#open',
      (_) => _suggesting(text: 'sun', suggestions: _plain, loading: true),
      act: baselineFocus,
    ),
    BaselineCase(
      'FrostSearchInput/suggestions+message#open',
      (_) => _suggesting(text: 'sun', suggestions: _plain, message: 'Showing cached results'),
      act: baselineFocus,
    ),

    // placement: inline. It replaces layoutBuilder, whose cases recorded an
    // App-built page (field above an Expanded list or placeholder text); the
    // inline layout also puts the field in the rows' content column.
    BaselineCase('FrostSearchInput.suggesting/placement=inline', (_) => _inline(text: 'sun', suggestions: _plain), height: 500),
    BaselineCase(
      'FrostSearchInput.suggesting/placement=inline=narrow',
      (_) => _narrow(_inline(text: 'sun', suggestions: _plain)),
      height: 500,
      envs: [BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostSearchInput.suggesting/placement=inline#open',
      (_) => _inline(text: 'sun', suggestions: _plain),
      height: 500,
      act: baselineFocus,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostSearchInput.suggesting/placement=inline=narrow#open',
      (_) => _narrow(_inline(text: 'sun', suggestions: _plain)),
      height: 500,
      act: baselineFocus,
      envs: [
        BaselineEnv.narrow,
        BaselineEnv.narrow.copyWith(brightness: Brightness.light),
        BaselineEnv.narrow.copyWith(input: BaselineInput.touch),
      ],
    ),
    // Adaptive placement is the overlay where a panel fits and inline where
    // panels become sheets: each must match that placement's record.
    BaselineCase(
      'FrostSearchInput.suggesting/placement=adaptive#open',
      (_) => _suggesting(text: 'sun', suggestions: _plain, placement: FrostSuggestionPlacement.adaptive),
      act: baselineFocus,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostSearchInput.suggesting/placement=adaptive=narrow#open',
      (_) => _narrow(_suggesting(text: 'sun', suggestions: _plain, placement: FrostSuggestionPlacement.adaptive)),
      height: 500,
      act: baselineFocus,
      envs: [
        BaselineEnv.narrow,
        BaselineEnv.narrow.copyWith(brightness: Brightness.light),
        BaselineEnv.narrow.copyWith(input: BaselineInput.touch),
      ],
    ),
    BaselineCase(
      'FrostSearchInput.suggesting/placement=inline+suggestions=rich+loading#open',
      (_) => _inline(text: 'sun', suggestions: _rich, loading: true),
      height: 500,
      act: baselineFocus,
    ),
    BaselineCase(
      'FrostSearchInput.suggesting/placement=inline+message#open',
      (_) => _inline(text: 'sun', message: 'No matches'),
      height: 500,
      act: baselineFocus,
    ),
    BaselineCase(
      'FrostSearchInput.suggesting/placement=inline+suggestions=rich+loading=narrow#open',
      (_) => _narrow(_inline(text: 'sun', suggestions: _rich, loading: true)),
      height: 500,
      act: baselineFocus,
      envs: [BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostSearchInput.suggesting/placement=inline+message=narrow#open',
      (_) => _narrow(_inline(text: 'sun', message: 'No matches')),
      height: 500,
      act: baselineFocus,
      envs: [BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostSearchInput.suggesting/placement=inline+unbounded#open',
      (_) => _unbounded(_inline(text: 'sun', suggestions: _plain)),
      act: baselineFocus,
      envs: [BaselineEnv.standard, BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostSearchInput.suggesting/placement=inline+region#open',
      (_) => FrostSearchInputRegion(
        child: _inline(text: 'sun', suggestions: _plain),
      ),
      height: 500,
      act: baselineFocus,
      envs: [BaselineEnv.standard, BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostSearchInput.suggesting/placement=inline#highlight',
      (_) => _inline(text: 'sun', suggestions: _plain),
      height: 500,
      act: _highlight,
    ),

    BaselineCase('FrostSearchInput/required#hover', (_) => _search(), act: baselineHover),
    BaselineCase('FrostSearchInput/required#focus', (_) => _search(), act: baselineFocus, envs: BaselineEnv.themes),
    BaselineCase('FrostSearchInput/controller=text#focus', (_) => _search(text: 'sunset'), act: baselineFocus),
  ]);
}
