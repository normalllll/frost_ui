import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'controls_support.dart';

void _changed(String _) {}
void _noop() {}

const _clear = FrostButton.icon(icon: baselineIcon, label: 'Clear', size: FrostControlSize.compact, onPressed: _noop);

// A field with text in it, for arguments that show only once there is some.
Widget _filled(Widget Function(TextEditingController controller) field, {String text = 'sunset over the bay'}) =>
    BaselineField(text: text, builder: (_, controller, _) => field(controller));

// Taps the visibility toggle of a secure field.
Future<void> _reveal(WidgetTester tester, Finder subject) async {
  await tester.tap(find.bySemanticsLabel('L.showPassword'));
}

void main() {
  baselineGroup('FrostTextField', [
    BaselineCase('FrostTextField/required', (_) => const FrostTextField(), envs: BaselineEnv.all),
    BaselineCase('FrostTextField/controller', (_) => _filled((c) => FrostTextField(controller: c)), envs: BaselineEnv.themes),
    BaselineCase('FrostTextField/focusNode', (_) => BaselineFocus(builder: (_, focus) => FrostTextField(focusNode: focus))),
    BaselineCase('FrostTextField/label', (_) => const FrostTextField(label: 'Name'), envs: BaselineEnv.all),
    BaselineCase('FrostTextField/placeholder', (_) => const FrostTextField(placeholder: 'Type a name'), envs: BaselineEnv.themes),
    BaselineCase(
      'FrostTextField/help',
      (_) => const FrostTextField(label: 'Name', help: 'Shown on your profile'),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostTextField/error',
      (_) => const FrostTextField(label: 'Name', error: 'A name is required'),
      envs: BaselineEnv.themes,
    ),
    BaselineCase('FrostTextField/leading', (_) => const FrostTextField(leading: baselineIcon, placeholder: 'Search')),
    BaselineCase('FrostTextField/trailing', (_) => const FrostTextField(trailing: _clear, placeholder: 'Search')),
    BaselineCase('FrostTextField/clearable', (_) => _filled((c) => FrostTextField(controller: c, clearable: true))),
    for (final size in FrostControlSize.values)
      BaselineCase(
        'FrostTextField/size=${size.name}',
        (_) => FrostTextField(size: size, placeholder: 'Type a name'),
        envs: [BaselineEnv.standard, BaselineEnv.touch],
      ),
    for (final appearance in FrostFieldAppearance.values)
      BaselineCase(
        'FrostTextField/appearance=${appearance.name}',
        (_) => FrostTextField(appearance: appearance, placeholder: 'Type a name'),
        envs: BaselineEnv.themes,
      ),
    BaselineCase('FrostTextField/monospace', (_) => _filled((c) => FrostTextField(controller: c, monospace: true), text: 'C:/Users/me/Pictures')),
    BaselineCase('FrostTextField/obscureText', (_) => _filled((c) => FrostTextField(controller: c, obscureText: true), text: 'secret')),
    BaselineCase('FrostTextField/readOnly', (_) => _filled((c) => FrostTextField(controller: c, readOnly: true))),
    BaselineCase('FrostTextField/enabled=false', (_) => _filled((c) => FrostTextField(controller: c, enabled: false)), envs: BaselineEnv.themes),
    BaselineCase('FrostTextField/autofocus', (_) => const FrostTextField(autofocus: true, placeholder: 'Type a name')),
    BaselineCase('FrostTextField/minLines', (_) => const FrostTextField(minLines: 3, maxLines: 5, placeholder: 'Write a note')),
    BaselineCase('FrostTextField/maxLines', (_) => _filled((c) => FrostTextField(controller: c, maxLines: 3), text: 'one\ntwo\nthree\nfour\nfive')),
    BaselineCase('FrostTextField/keyboardType', (_) => const FrostTextField(keyboardType: TextInputType.emailAddress, placeholder: 'Email')),
    BaselineCase('FrostTextField/textInputAction', (_) => const FrostTextField(textInputAction: TextInputAction.search, placeholder: 'Search')),
    BaselineCase('FrostTextField/onChanged', (_) => const FrostTextField(onChanged: _changed, placeholder: 'Type a name')),
    BaselineCase('FrostTextField/onSubmitted', (_) => const FrostTextField(onSubmitted: _changed, placeholder: 'Type a name')),
    BaselineCase('FrostTextField/onEditingComplete', (_) => const FrostTextField(onEditingComplete: _noop, placeholder: 'Type a name')),
    BaselineCase('FrostTextField/onTap', (_) => const FrostTextField(onTap: _noop, placeholder: 'Type a name')),
    BaselineCase('FrostTextField/onTapOutside', (_) => FrostTextField(onTapOutside: (_) {}, placeholder: 'Type a name')),
    BaselineCase(
      'FrostTextField/scrollController',
      (_) => BaselineOwned<ScrollController>(
        create: ScrollController.new,
        builder: (_, scroll) => FrostTextField(scrollController: scroll, placeholder: 'Type a name'),
      ),
    ),
    BaselineCase('FrostTextField/placeholder#hover', (_) => const FrostTextField(placeholder: 'Type a name'), act: baselineHover),
    BaselineCase(
      'FrostTextField/placeholder#focus',
      (_) => const FrostTextField(placeholder: 'Type a name'),
      act: baselineFocus,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostTextField/error#focus',
      (_) => const FrostTextField(label: 'Name', error: 'A name is required'),
      act: baselineFocus,
    ),
    BaselineCase('FrostTextField/clearable#focus', (_) => _filled((c) => FrostTextField(controller: c, clearable: true)), act: baselineFocus),
    BaselineCase('FrostTextField/clearable#hover', (_) => _filled((c) => FrostTextField(controller: c, clearable: true)), act: baselineHover),

    BaselineCase('FrostTextField.secure/required', (_) => const FrostTextField.secure(), envs: BaselineEnv.all),
    BaselineCase(
      'FrostTextField.secure/controller',
      (_) => _filled((c) => FrostTextField.secure(controller: c), text: 'secret'),
      envs: BaselineEnv.themes,
    ),
    BaselineCase('FrostTextField.secure/focusNode', (_) => BaselineFocus(builder: (_, focus) => FrostTextField.secure(focusNode: focus))),
    BaselineCase('FrostTextField.secure/label', (_) => const FrostTextField.secure(label: 'Password')),
    BaselineCase('FrostTextField.secure/placeholder', (_) => const FrostTextField.secure(placeholder: 'Password')),
    BaselineCase('FrostTextField.secure/help', (_) => const FrostTextField.secure(label: 'Password', help: 'At least 8 characters')),
    BaselineCase('FrostTextField.secure/error', (_) => const FrostTextField.secure(label: 'Password', error: 'Too short')),
    BaselineCase('FrostTextField.secure/leading', (_) => const FrostTextField.secure(leading: baselineIcon, placeholder: 'Password')),
    BaselineCase('FrostTextField.secure/trailing', (_) => const FrostTextField.secure(trailing: _clear, placeholder: 'Password')),
    for (final size in FrostControlSize.values)
      BaselineCase(
        'FrostTextField.secure/size=${size.name}',
        (_) => FrostTextField.secure(size: size, placeholder: 'Password'),
        envs: [BaselineEnv.standard, BaselineEnv.touch],
      ),
    for (final appearance in FrostFieldAppearance.values)
      BaselineCase(
        'FrostTextField.secure/appearance=${appearance.name}',
        (_) => FrostTextField.secure(appearance: appearance, placeholder: 'Password'),
        envs: BaselineEnv.themes,
      ),
    BaselineCase('FrostTextField.secure/readOnly', (_) => _filled((c) => FrostTextField.secure(controller: c, readOnly: true), text: 'secret')),
    BaselineCase('FrostTextField.secure/enabled=false', (_) => _filled((c) => FrostTextField.secure(controller: c, enabled: false), text: 'secret')),
    BaselineCase('FrostTextField.secure/autofocus', (_) => const FrostTextField.secure(autofocus: true, placeholder: 'Password')),
    BaselineCase('FrostTextField.secure/textInputAction', (_) => const FrostTextField.secure(textInputAction: TextInputAction.done, placeholder: 'Password')),
    BaselineCase('FrostTextField.secure/onChanged', (_) => const FrostTextField.secure(onChanged: _changed, placeholder: 'Password')),
    BaselineCase('FrostTextField.secure/onSubmitted', (_) => const FrostTextField.secure(onSubmitted: _changed, placeholder: 'Password')),
    BaselineCase('FrostTextField.secure/onEditingComplete', (_) => const FrostTextField.secure(onEditingComplete: _noop, placeholder: 'Password')),
    BaselineCase('FrostTextField.secure/onTap', (_) => const FrostTextField.secure(onTap: _noop, placeholder: 'Password')),
    BaselineCase('FrostTextField.secure/onTapOutside', (_) => FrostTextField.secure(onTapOutside: (_) {}, placeholder: 'Password')),
    BaselineCase(
      'FrostTextField.secure/scrollController',
      (_) => BaselineOwned<ScrollController>(
        create: ScrollController.new,
        builder: (_, scroll) => FrostTextField.secure(scrollController: scroll, placeholder: 'Password'),
      ),
    ),
    BaselineCase(
      'FrostTextField.secure/controller#hover',
      (_) => _filled((c) => FrostTextField.secure(controller: c), text: 'secret'),
      act: baselineHover,
    ),
    BaselineCase(
      'FrostTextField.secure/controller#focus',
      (_) => _filled((c) => FrostTextField.secure(controller: c), text: 'secret'),
      act: baselineFocus,
    ),
    BaselineCase(
      'FrostTextField.secure/controller#revealed',
      (_) => _filled((c) => FrostTextField.secure(controller: c), text: 'secret'),
      act: _reveal,
    ),
  ]);
}
