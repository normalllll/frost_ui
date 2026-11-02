import 'package:flutter/material.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'controls_support.dart';

void _changed(String _) {}
void _noop() {}

const _clear = FrostButton.icon(icon: baselineIcon, label: 'Clear', size: FrostControlSize.compact, onPressed: _noop);

final _sky = FrostTokenRule(pattern: RegExp('^sky'), tone: FrostTokenTone.accent);

// A token controller whose text has one completed word per rule.
Widget _tokens(Widget Function(FrostTokenEditingController controller) field, {String text = 'sky cloud ', List<FrostTokenRule>? rules}) =>
    BaselineOwned<FrostTokenEditingController>(
      create: () => FrostTokenEditingController(text: text, rules: rules ?? [_sky]),
      builder: (_, controller) => field(controller),
    );

void main() {
  baselineGroup('FrostTokenField', [
    BaselineCase(
      'FrostTokenField/required',
      (_) => _tokens(
        (c) => FrostTokenField(controller: c),
        text: '',
        rules: const [],
      ),
      envs: BaselineEnv.all,
    ),
    BaselineCase('FrostTokenField/controller', (_) => _tokens((c) => FrostTokenField(controller: c)), envs: BaselineEnv.themes),
    for (final tone in FrostTokenTone.values)
      BaselineCase(
        'FrostTokenField/controller=tone.${tone.name}',
        (_) => _tokens(
          (c) => FrostTokenField(controller: c),
          text: 'word ',
          rules: [FrostTokenRule(pattern: RegExp('^word'), tone: tone)],
        ),
        envs: BaselineEnv.themes,
      ),
    BaselineCase(
      'FrostTokenField/focusNode',
      (_) => BaselineFocus(
        builder: (_, focus) => _tokens((c) => FrostTokenField(controller: c, focusNode: focus)),
      ),
    ),
    BaselineCase('FrostTokenField/label', (_) => _tokens((c) => FrostTokenField(controller: c, label: 'Tags'))),
    BaselineCase(
      'FrostTokenField/placeholder',
      (_) => _tokens(
        (c) => FrostTokenField(controller: c, placeholder: 'Add tags'),
        text: '',
        rules: const [],
      ),
    ),
    BaselineCase('FrostTokenField/help', (_) => _tokens((c) => FrostTokenField(controller: c, label: 'Tags', help: 'Separate with spaces'))),
    BaselineCase('FrostTokenField/error', (_) => _tokens((c) => FrostTokenField(controller: c, label: 'Tags', error: 'Unknown tag'))),
    BaselineCase('FrostTokenField/leading', (_) => _tokens((c) => FrostTokenField(controller: c, leading: baselineIcon))),
    BaselineCase('FrostTokenField/trailing', (_) => _tokens((c) => FrostTokenField(controller: c, trailing: _clear))),
    BaselineCase('FrostTokenField/clearable', (_) => _tokens((c) => FrostTokenField(controller: c, clearable: true))),
    for (final size in FrostControlSize.values)
      BaselineCase(
        'FrostTokenField/size=${size.name}',
        (_) => _tokens((c) => FrostTokenField(controller: c, size: size)),
        envs: [BaselineEnv.standard, BaselineEnv.touch],
      ),
    BaselineCase('FrostTokenField/monospace', (_) => _tokens((c) => FrostTokenField(controller: c, monospace: true))),
    BaselineCase('FrostTokenField/obscureText', (_) => _tokens((c) => FrostTokenField(controller: c, obscureText: true))),
    BaselineCase('FrostTokenField/readOnly', (_) => _tokens((c) => FrostTokenField(controller: c, readOnly: true))),
    BaselineCase('FrostTokenField/enabled=false', (_) => _tokens((c) => FrostTokenField(controller: c, enabled: false))),
    BaselineCase('FrostTokenField/autofocus', (_) => _tokens((c) => FrostTokenField(controller: c, autofocus: true))),
    BaselineCase('FrostTokenField/minLines', (_) => _tokens((c) => FrostTokenField(controller: c, minLines: 3, maxLines: 4))),
    BaselineCase('FrostTokenField/maxLines', (_) => _tokens((c) => FrostTokenField(controller: c, maxLines: 2), text: 'sky\ncloud\nsun ')),
    BaselineCase('FrostTokenField/keyboardType', (_) => _tokens((c) => FrostTokenField(controller: c, keyboardType: TextInputType.text))),
    BaselineCase('FrostTokenField/textInputAction', (_) => _tokens((c) => FrostTokenField(controller: c, textInputAction: TextInputAction.search))),
    BaselineCase('FrostTokenField/onChanged', (_) => _tokens((c) => FrostTokenField(controller: c, onChanged: _changed))),
    BaselineCase('FrostTokenField/onSubmitted', (_) => _tokens((c) => FrostTokenField(controller: c, onSubmitted: _changed))),
    BaselineCase('FrostTokenField/onEditingComplete', (_) => _tokens((c) => FrostTokenField(controller: c, onEditingComplete: _noop))),
    BaselineCase('FrostTokenField/onTap', (_) => _tokens((c) => FrostTokenField(controller: c, onTap: _noop))),
    BaselineCase('FrostTokenField/onTapOutside', (_) => _tokens((c) => FrostTokenField(controller: c, onTapOutside: (_) {}))),
    BaselineCase(
      'FrostTokenField/scrollController',
      (_) => BaselineOwned<ScrollController>(
        create: ScrollController.new,
        builder: (_, scroll) => _tokens((c) => FrostTokenField(controller: c, scrollController: scroll)),
      ),
    ),
    BaselineCase('FrostTokenField/controller#hover', (_) => _tokens((c) => FrostTokenField(controller: c)), act: baselineHover),
    BaselineCase('FrostTokenField/controller#focus', (_) => _tokens((c) => FrostTokenField(controller: c)), act: baselineFocus),
  ]);
}
