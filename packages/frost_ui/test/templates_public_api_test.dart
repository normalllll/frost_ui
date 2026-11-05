import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

void main() {
  test('page composition APIs compile with only widgets and frost_ui', () {
    final widgets = <Widget>[
      FrostPinnedChrome(
        chrome: const FrostHeaderSections(header: SizedBox(), tabs: SizedBox(), trailing: SizedBox()),
        body: const FrostChromeActiveBody(active: true, child: SizedBox()),
        extent: 100,
      ),
    ];
    final controller = FrostFormDialogController(errorSummary: 'error')..errorSummary = null;
    Future<bool> open(BuildContext context) => showFrostFormDialog(
      context: context,
      title: 'Form',
      sections: const [FrostFormSection(children: [])],
      onSubmit: () => true,
      submitLabel: 'Save',
      cancelLabel: 'Cancel',
      errorSummary: 'error',
      controller: controller,
      size: FrostDialogSize.wide,
    );
    expect(open, isNotNull);
    controller.dispose();
    expect(widgets, hasLength(1));
  });
}
