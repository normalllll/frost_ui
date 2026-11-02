import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'controls_support.dart';

bool _accept() => true;
Future<bool> _reject() async => false;

const _fields = [FrostTextField(label: 'Name'), FrostTextField(label: 'Email')];
const _invalid = [FrostTextField(label: 'Name', error: 'A name is required'), FrostTextField(label: 'Email')];

// Focus the first field and submit it: a rejected form focuses the first field
// that shows an error.
Future<void> _submit(WidgetTester tester, Finder subject) async {
  await baselineFocus(tester, subject);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

void main() {
  baselineGroup('FrostForm', [
    BaselineCase(
      'FrostForm/required',
      (_) => const FrostForm(onSubmit: _accept, children: _fields),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostForm/children=sections',
      (_) => const FrostForm(
        onSubmit: _accept,
        children: [
          FrostFormSection(title: 'Profile', children: _fields),
          FrostFormSection(
            title: 'Security',
            children: [FrostTextField.secure(label: 'Password')],
          ),
        ],
      ),
    ),
    BaselineCase(
      'FrostForm/children=mixed',
      (_) => const FrostForm(
        onSubmit: _accept,
        children: [
          FrostTextField(label: 'Name'),
          FrostFormSection(
            title: 'Details',
            children: [FrostTextField(label: 'City')],
          ),
          FrostTextField(label: 'Notes'),
        ],
      ),
    ),
    BaselineCase(
      'FrostForm/controller',
      (_) => BaselineOwned<FrostFormController>(
        create: FrostFormController.new,
        builder: (_, controller) => FrostForm(controller: controller, onSubmit: _accept, children: _fields),
      ),
    ),
    BaselineCase(
      'FrostForm/errorSummary',
      (_) => const FrostForm(errorSummary: 'Fix the highlighted fields', onSubmit: _accept, children: _invalid),
      envs: BaselineEnv.themes,
    ),
    BaselineCase('FrostForm/onSubmit=async', (_) => const FrostForm(onSubmit: _reject, children: _fields)),
    BaselineCase(
      'FrostForm/onSubmit#rejected',
      (_) => const FrostForm(onSubmit: _reject, children: _invalid),
      act: _submit,
    ),
    BaselineCase(
      'FrostForm/errorSummary#rejected',
      (_) => const FrostForm(errorSummary: 'Fix the highlighted fields', onSubmit: _reject, children: _invalid),
      act: _submit,
    ),
  ]);
}
