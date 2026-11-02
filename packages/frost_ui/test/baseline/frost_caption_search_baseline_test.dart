import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'controls_support.dart';

void _submitted(String _) {}
void _noop() {}

final _suggestions = [
  FrostSearchSuggestionGroup(
    items: [
      FrostSearchSuggestion(label: 'sunset', onSelected: _noop),
      FrostSearchSuggestion(label: 'sunrise', onSelected: _noop),
    ],
  ),
];

// The caption gives the search a bounded slot; 360 is its resting width.
Widget _caption({
  double width = 360,
  String text = '',
  ValueChanged<String>? onSubmittedInNewTab,
  List<FrostSearchSuggestionGroup> suggestions = const [],
  bool loading = false,
  String? message,
}) => BaselineField(
  text: text,
  builder: (_, controller, focus) => SizedBox(
    width: width,
    height: 48,
    child: FrostCaptionSearch(
      controller: controller,
      focusNode: focus,
      placeholder: 'Search',
      onSubmitted: _submitted,
      onSubmittedInNewTab: onSubmittedInNewTab,
      suggestions: suggestions,
      loading: loading,
      message: message,
    ),
  ),
);

void main() {
  baselineGroup('FrostCaptionSearch', [
    BaselineCase('FrostCaptionSearch/required', (_) => _caption(), envs: BaselineEnv.all),
    BaselineCase('FrostCaptionSearch/required+width=60', (_) => _caption(width: 60)),
    BaselineCase('FrostCaptionSearch/required+width=200', (_) => _caption(width: 200)),
    BaselineCase('FrostCaptionSearch/controller=text', (_) => _caption(text: 'sunset')),
    BaselineCase('FrostCaptionSearch/onSubmittedInNewTab', (_) => _caption(onSubmittedInNewTab: _submitted)),
    BaselineCase('FrostCaptionSearch/suggestions', (_) => _caption(text: 'sun', suggestions: _suggestions)),
    BaselineCase(
      'FrostCaptionSearch/suggestions#open',
      (_) => _caption(text: 'sun', suggestions: _suggestions),
      act: baselineFocus,
      envs: BaselineEnv.themes,
    ),
    BaselineCase('FrostCaptionSearch/loading#open', (_) => _caption(text: 'sun', loading: true), act: baselineFocus),
    BaselineCase(
      'FrostCaptionSearch/message#open',
      (_) => _caption(text: 'sun', message: 'No matches'),
      act: baselineFocus,
    ),
    BaselineCase(
      'FrostCaptionSearch/suggestions+loading#open',
      (_) => _caption(text: 'sun', suggestions: _suggestions, loading: true),
      act: baselineFocus,
    ),
    BaselineCase('FrostCaptionSearch/required#hover', (_) => _caption(), act: baselineHover),
    BaselineCase('FrostCaptionSearch/required#focus', (_) => _caption(), act: baselineFocus),
  ]);
}
