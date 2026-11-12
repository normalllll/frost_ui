// One case per public constructor of an interactive component: buttons,
// toggles, inputs, pickers, and rows or cards that can be clicked.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/desktop.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/media.dart';
import 'package:frost_ui/social.dart';

import '../support.dart' show testFonts, testIcons, testLabels;
import 'harness.dart';

const _noInteraction = {
  'disabled-scope': 'a skeleton placeholder is not interactive',
  'disabled-semantics': 'a skeleton placeholder is not interactive',
  'semantics': 'a skeleton placeholder is not interactive',
  'keyboard': 'a skeleton placeholder is not interactive',
  'touch-target': 'a skeleton placeholder is not interactive',
  'reduced-motion': 'a skeleton placeholder is not interactive',
};

const _needsScope = {'no-theme': 'the case itself has to place a FrostScope above the button to give it a recovery action'};

const _searchPartSkip = {
  'keyboard': 'a search option never takes focus by design: focus stays in the field and its arrow keys move a highlight, so Tab cannot reach the option',
};

final _edit = testIcons.edit, _add = testIcons.add;
const _picture = FrostMediaImage(
  child: SizedBox(height: 120, child: ColoredBox(color: Colors.red)),
);
const _options = [
  FrostPickerOption(value: 'a', label: 'Alpha'),
  FrostPickerOption(value: 'b', label: 'Bravo'),
  FrostPickerOption(value: 'c', label: 'Charlie'),
];

Finder _icon(Type owner) => find.descendant(of: find.byType(owner), matching: find.byType(FrostIcon)).first;
Finder _text(String text) => find.text(text);
Finder _editable(Type owner) => find.descendant(of: find.byType(owner), matching: find.byType(EditableText)).first;
List<FrostMenuEntry> _menu(VoidCallback go) => [FrostMenuAction('Menu item', onSelected: go)];

/// An error that offers a recovery action, so the error button has something to show.
Widget _withErrorAction(VoidCallback go, Widget child) => FrostScope(
  config: FrostConfig(
    palettes: FrostPalettes.pink,
    fonts: testFonts,
    icons: testIcons,
    labels: testLabels,
    errors: FrostErrorPresenter(
      message: (context, error) => 'Message',
      details: (error) => 'Details',
      action: (context, error) => FrostErrorAction(
        label: 'Retry',
        icon: testIcons.refresh,
        onPressed: () async {
          go();
          return true;
        },
      ),
    ),
  ),
  child: child,
);

final interactiveCases = <InteractiveCase>[
  // Buttons
  InteractiveCase(
    'FrostButton.new',
    FrostButton,
    (go) => FrostButton(label: longLabel, icon: _edit, onPressed: go),
    start: _icon(FrostButton),
    end: _text(longLabel),
  ),
  InteractiveCase(
    'FrostButton.prominent',
    FrostButton,
    (go) => FrostButton.prominent(label: longLabel, icon: _edit, onPressed: go),
    start: _icon(FrostButton),
    end: _text(longLabel),
  ),
  InteractiveCase(
    'FrostButton.tinted',
    FrostButton,
    (go) => FrostButton.tinted(label: longLabel, icon: _edit, onPressed: go),
    start: _icon(FrostButton),
    end: _text(longLabel),
  ),
  InteractiveCase(
    'FrostButton.outlined',
    FrostButton,
    (go) => FrostButton.outlined(label: longLabel, icon: _edit, onPressed: go),
    start: _icon(FrostButton),
    end: _text(longLabel),
  ),
  InteractiveCase(
    'FrostButton.plain',
    FrostButton,
    (go) => FrostButton.plain(label: longLabel, icon: _edit, onPressed: go),
    start: _icon(FrostButton),
    end: _text(longLabel),
  ),
  InteractiveCase('FrostButton.quiet', FrostButton, (go) => FrostButton.quiet(label: longLabel, onPressed: go)),
  InteractiveCase('FrostButton.icon', FrostButton, (go) => FrostButton.icon(icon: _edit, label: 'Edit', onPressed: go)),
  InteractiveCase('FrostButton.iconFilled', FrostButton, (go) => FrostButton.iconFilled(icon: _edit, label: 'Edit', onPressed: go)),
  InteractiveCase('FrostButton.iconOnMedia', FrostButton, (go) => FrostButton.iconOnMedia(icon: _edit, label: 'Edit', onPressed: go)),
  // Media buttons are laid out for a video frame (FrostVideoCommandScope), so they are tested inside one.
  InteractiveCase(
    'FrostMediaButton.new',
    FrostMediaButton,
    (go) => _videoFrame(
      controls: [FrostMediaButton(label: '1.5x', onPressed: go)],
    ),
    target: _mediaButton('1.5x'),
    subject: _mediaButton('1.5x'),
    skip: _inVideoFrame,
  ),
  InteractiveCase(
    'FrostMediaButton.icon',
    FrostMediaButton,
    (go) => _videoFrame(onPlayPause: go),
    target: _mediaButton('L.play'),
    subject: _mediaButton('L.play'),
    skip: _inVideoFrame,
  ),
  InteractiveCase(
    'FrostErrorActionButton.new',
    FrostErrorActionButton,
    (go) => _withErrorAction(go, FrostErrorActionButton(error: 'broken', onResolved: () {})),
    skip: _needsScope,
  ),
  InteractiveCase(
    'FrostErrorActionButton.icon',
    FrostErrorActionButton,
    (go) => _withErrorAction(go, FrostErrorActionButton.icon(error: 'broken', onResolved: () {})),
    skip: _needsScope,
  ),
  InteractiveCase('FrostCompactBackButton.new', FrostCompactBackButton, (go) => FrostCompactBackButton(onPressed: go)),
  InteractiveCase(
    'FrostShellTaskButton.new',
    FrostShellTaskButton,
    (go) => hosted(
      width: 200,
      height: 48,
      child: FrostShellTaskButton(icon: _add, label: longLabel, onPressed: go),
    ),
  ),
  InteractiveCase(
    'FrostToolbarMenuButton.new',
    FrostToolbarMenuButton,
    (go) => FrostToolbarMenuButton(label: longLabel, icon: _add, entries: _menu(go)),
    opens: _text('Menu item'),
  ),
  InteractiveCase(
    'FrostTitleMenu.new',
    FrostTitleMenu,
    (go) => FrostTitleMenu(title: longLabel, entries: _menu(go)),
    opens: _text('Menu item'),
  ),
  InteractiveCase(
    'FrostFloatingActionLayer.new',
    FrostFloatingActionLayer,
    (go) => FrostFloatingActionLayer(label: 'Add', icon: _add, onPressed: go, child: const SizedBox(width: 300, height: 300)),
    target: find.descendant(of: find.byType(FrostFloatingActionLayer), matching: find.text('Add')),
    focusTarget: find.byType(FrostFloatingActionLayer),
    skip: const {'intrinsic': 'a page layer: its body and button are all positioned against the area it is given'},
  ),
  InteractiveCase(
    'FrostClickSurface.new',
    FrostClickSurface,
    (go) => FrostClickSurface(
      onTap: go,
      child: SizedBox(width: 120, height: 48, child: Text('Surface')),
    ),
    skip: {'semantics': 'FrostClickSurface is a primitive; its caller names it'},
  ),

  // Toggles
  InteractiveCase(
    'FrostSwitch.new',
    FrostSwitch,
    (go) => FrostSwitch(value: false, onChanged: (_) => go(), semanticLabel: 'Switch'),
    kind: ControlKind.toggle,
  ),
  InteractiveCase(
    'FrostCheckbox.new',
    FrostCheckbox,
    (go) => FrostCheckbox(value: false, onChanged: (_) => go(), semanticLabel: 'Check'),
    kind: ControlKind.toggle,
  ),
  InteractiveCase(
    'FrostCheckboxRow.new',
    FrostCheckboxRow,
    (go) => FrostCheckboxRow(value: false, onChanged: (_) => go(), title: longLabel),
    kind: ControlKind.toggle,
  ),
  InteractiveCase('FrostColorSwatch.new', FrostColorSwatch, (go) => FrostColorSwatch(color: Colors.red, label: 'Red', onPressed: go)),

  // Inputs
  InteractiveCase(
    'FrostTextField.new',
    FrostTextField,
    (go) => FrostTextField(label: longLabel, onChanged: (_) => go()),
    kind: ControlKind.field,
    target: _editable(FrostTextField),
  ),
  InteractiveCase(
    'FrostTextField.secure',
    FrostTextField,
    (go) => FrostTextField.secure(label: longLabel, onChanged: (_) => go()),
    kind: ControlKind.field,
    target: _editable(FrostTextField),
  ),
  InteractiveCase(
    'FrostNumberField.new',
    FrostNumberField,
    (go) => FrostNumberField(value: 5, label: longLabel, onChanged: (_) => go()),
    kind: ControlKind.field,
    target: _editable(FrostNumberField),
  ),
  InteractiveCase(
    'FrostPathField.new',
    FrostPathField,
    (go) => FrostPathField(path: '/tmp/file', label: longLabel, onChoose: () async => go()),
    kind: ControlKind.other,
    target: find.text('L.choose'),
    focusTarget: find.byType(FrostPathField),
  ),
  InteractiveCase(
    'FrostTokenField.new',
    FrostTokenField,
    (go) => FrostTokenField(
      controller: FrostTokenEditingController(rules: const []),
      label: longLabel,
      onChanged: (_) => go(),
    ),
    kind: ControlKind.field,
    target: _editable(FrostTokenField),
  ),
  InteractiveCase(
    'FrostSearchInput.new',
    FrostSearchInput,
    (go) => FrostSearchInput(controller: TextEditingController(), focusNode: FocusNode(), placeholder: 'Search', onSubmitted: (_) => go()),
    kind: ControlKind.field,
    target: _editable(FrostSearchInput),
  ),
  InteractiveCase(
    'FrostSearchInput.suggesting',
    FrostSearchInput,
    (go) => FrostSearchInput.suggesting(
      controller: TextEditingController(),
      focusNode: FocusNode(),
      placeholder: 'Search',
      onSubmitted: (_) => go(),
      content: FrostSearchSection(
        children: [FrostSearchSuggestionRow(label: 'Suggestion', onSelected: () {})],
      ),
    ),
    kind: ControlKind.field,
    target: _editable(FrostSearchInput),
  ),
  // Search dropdown parts: they work only as the content of a focused FrostSearchInput.suggesting.
  InteractiveCase(
    'FrostSearchOption.new',
    FrostSearchOption,
    (go) => searchDropdown(
      FrostSearchOption(
        semanticLabel: 'Option',
        keepsOpen: true,
        onSelected: go,
        child: SizedBox(height: 48, child: Center(child: Text(longLabel))),
      ),
    ),
    kind: ControlKind.other,
    focusTarget: _editable(FrostSearchInput),
    skip: _searchPartSkip,
  ),
  InteractiveCase(
    'FrostSearchSuggestionRow.new',
    FrostSearchSuggestionRow,
    (go) => searchDropdown(FrostSearchSuggestionRow(label: longLabel, detail: 'Detail', value: '12', keepsOpen: true, onSelected: go, onRemove: () {})),
    kind: ControlKind.other,
    focusTarget: _editable(FrostSearchInput),
    skip: _searchPartSkip,
  ),
  InteractiveCase(
    'FrostSearchSection.new',
    FrostSearchSection,
    (go) => searchDropdown(
      FrostSearchSection(
        title: 'History',
        actionLabel: 'Clear',
        onAction: go,
        children: [FrostSearchSuggestionRow(label: 'Suggestion', onSelected: () {})],
      ),
    ),
    kind: ControlKind.other,
    target: _text('Clear'),
    focusTarget: _editable(FrostSearchInput),
    skip: _searchPartSkip,
  ),
  InteractiveCase(
    'FrostCaptionSearch.new',
    FrostCaptionSearch,
    (go) => FrostCaptionSearch(controller: TextEditingController(), focusNode: FocusNode(), placeholder: 'Search', onSubmitted: (_) => go()),
    kind: ControlKind.field,
    target: _editable(FrostCaptionSearch),
  ),
  InteractiveCase('FrostSearchEntry.new', FrostSearchEntry, (go) => FrostSearchEntry(placeholder: 'Search', onPressed: go)),
  InteractiveCase(
    'FrostSlider.new',
    FrostSlider,
    (go) => FrostSlider(value: 0.2, onChanged: (_) => go(), semanticLabel: 'Volume'),
    kind: ControlKind.other,
    action: SemanticsAction.increase,
  ),
  InteractiveCase(
    'FrostStepper.new',
    FrostStepper,
    (go) => FrostStepper(value: 5, onChanged: (_) => go(), semanticLabel: 'Amount'),
    kind: ControlKind.other,
    action: SemanticsAction.increase,
  ),

  // Pickers
  InteractiveCase(
    'FrostPicker.new',
    FrostPicker<String>,
    (go) => FrostPicker<String>(options: _options, value: 'a', onChanged: (_) => go(), label: longLabel),
    kind: ControlKind.other,
  ),
  InteractiveCase(
    'FrostPicker.menu',
    FrostPicker<String>,
    (go) => FrostPicker<String>.menu(options: _options, value: 'a', onChanged: (_) => go(), label: longLabel),
    kind: ControlKind.other,
    opens: _text('Bravo'),
    target: _text('Alpha'),
    focusTarget: find.byType(FrostPicker<String>),
  ),
  InteractiveCase(
    'FrostPicker.segmented',
    FrostPicker<String>,
    (go) => FrostPicker<String>.segmented(options: _options, value: 'a', onChanged: (_) => go(), label: longLabel),
    kind: ControlKind.other,
  ),
  InteractiveCase(
    'FrostPicker.inline',
    FrostPicker<String>,
    (go) => FrostPicker<String>.inline(options: _options, value: 'a', onChanged: (_) => go(), label: longLabel),
    kind: ControlKind.other,
  ),
  InteractiveCase(
    'FrostPicker.palette',
    FrostPicker<String>,
    (go) => FrostPicker<String>.palette(
      options: const [
        FrostPickerOption(value: 'a', label: 'Alpha', color: Colors.red),
        FrostPickerOption(value: 'b', label: 'Bravo', color: Colors.green),
        FrostPickerOption(value: 'c', label: 'Charlie', color: Colors.blue),
      ],
      // The target is the first swatch; picking what's already selected reports nothing.
      value: 'b',
      onChanged: (_) => go(),
      label: longLabel,
    ),
    kind: ControlKind.other,
  ),
  InteractiveCase(
    'FrostDatePicker.new',
    FrostDatePicker,
    (go) => FrostDatePicker(value: DateTime(2026, 11, 2), onChanged: (_) => go(), label: longLabel),
    kind: ControlKind.other,
    opens: _text('November 2026'),
    target: _text('Mon, Nov 2'),
    focusTarget: find.byType(FrostDatePicker),
  ),
  InteractiveCase(
    'FrostDateRangePicker.new',
    FrostDateRangePicker,
    (go) => FrostDateRangePicker(
      value: (start: DateTime(2026, 11, 2), end: DateTime(2026, 11, 5)),
      onChanged: (_) => go(),
      label: longLabel,
    ),
    kind: ControlKind.other,
    opens: _text('November 2026'),
    target: _text('Mon, Nov 2 – Thu, Nov 5'),
    focusTarget: find.byType(FrostDateRangePicker),
  ),
  InteractiveCase(
    'FrostTimePicker.new',
    FrostTimePicker,
    (go) => FrostTimePicker(value: const (hour: 9, minute: 30), onChanged: (_) => go(), label: longLabel),
    kind: ControlKind.field,
    target: _editable(FrostTimePicker),
  ),
  InteractiveCase(
    'FrostSettingsSelectTile.new',
    FrostSettingsSelectTile<String>,
    (go) => FrostSettingsSelectTile<String>(title: longLabel, value: 'a', items: _options, onChanged: (_) => go()),
    kind: ControlKind.other,
    opens: _text('Bravo'),
  ),
  InteractiveCase(
    'FrostSettingsSelectTile.values',
    FrostSettingsSelectTile<String>,
    (go) => FrostSettingsSelectTile<String>.values(title: longLabel, label: (value) => value, value: 'a', values: const ['a', 'b'], onChanged: (_) => go()),
    kind: ControlKind.other,
    opens: _text('b'),
  ),

  // Rows and cards
  InteractiveCase(
    'FrostListRow.new',
    FrostListRow,
    (go) => FrostListRow(title: longLabel, onPressed: go),
    kind: ControlKind.other,
  ),
  InteractiveCase(
    'FrostListRow.toggle',
    FrostListRow,
    (go) => FrostListRow.toggle(title: longLabel, value: false, onChanged: (_) => go()),
    kind: ControlKind.toggle,
  ),
  InteractiveCase(
    'FrostListRow.check',
    FrostListRow,
    (go) => FrostListRow.check(title: longLabel, checked: false, onPressed: go),
    kind: ControlKind.other,
  ),
  InteractiveCase(
    'FrostListRow.skeleton',
    FrostListRow,
    (go) => FrostListRow.skeleton(title: longLabel, icon: true, subtitle: null, value: null),
    kind: ControlKind.other,
    skip: _noInteraction,
  ),
  InteractiveCase(
    'FrostNavigationColumnRow.new',
    FrostNavigationColumnRow,
    (go) => FrostNavigationColumnRow(title: longLabel, onPressed: go),
    kind: ControlKind.other,
  ),
  InteractiveCase(
    'FrostTaskRow.new',
    FrostTaskRow,
    (go) => FrostTaskRow(title: longLabel, status: FrostTaskStatus.running, onPressed: go),
    kind: ControlKind.other,
  ),
  InteractiveCase(
    'FrostMediaCard.new',
    FrostMediaCard,
    (go) => FrostMediaCard(media: _picture, title: longLabel, semanticLabel: 'Card', onPressed: go),
    kind: ControlKind.other,
  ),
  InteractiveCase(
    'FrostMediaCard.skeleton',
    FrostMediaCard,
    (go) => hosted(width: 200, child: FrostMediaCard.skeleton(aspectRatio: 1, footer: 'Footer')),
    kind: ControlKind.other,
    skip: _noInteraction,
  ),
  InteractiveCase(
    'FrostMediaRow.new',
    FrostMediaRow,
    (go) => FrostMediaRow(media: _picture, title: longLabel, onPressed: go),
    kind: ControlKind.other,
  ),
  InteractiveCase(
    'FrostLinkCard.new',
    FrostLinkCard,
    (go) => FrostLinkCard(title: longLabel, url: Uri.parse('https://example.com'), onPressed: go),
    kind: ControlKind.other,
  ),
  InteractiveCase(
    'FrostLinkCard.skeleton',
    FrostLinkCard,
    (go) => FrostLinkCard.skeleton(style: FrostLinkCardStyle.row, image: true, title: longLabel, description: null, host: 'example.com'),
    kind: ControlKind.other,
    skip: _noInteraction,
  ),
  InteractiveCase(
    'FrostTag.new',
    FrostTag,
    (go) => FrostTag(label: longLabel, onPressed: go),
    kind: ControlKind.other,
  ),
  InteractiveCase(
    'FrostTag.skeleton',
    FrostTag,
    (go) => FrostTag.skeleton(label: longLabel),
    kind: ControlKind.other,
    skip: _noInteraction,
  ),
  InteractiveCase(
    'FrostFilterChip.new',
    FrostFilterChip,
    (go) => FrostFilterChip(label: longLabel, onPressed: go),
    kind: ControlKind.other,
  ),
  InteractiveCase(
    'FrostCopyable.new',
    FrostCopyable,
    (go) => const FrostCopyable(text: 'copy me'),
    kind: ControlKind.other,
    target: find.descendant(of: find.byType(FrostCopyable), matching: find.byType(FrostTooltip)),
  ),
  InteractiveCase(
    'FrostThumbnail.new',
    FrostThumbnail,
    (go) => FrostThumbnail(image: _picture, semanticLabel: 'Preview', onPressed: go),
    kind: ControlKind.other,
  ),
  InteractiveCase(
    'FrostNavItem.new',
    FrostNavItem,
    (go) => hosted(
      width: 200,
      height: 48,
      child: FrostNavItem(label: longLabel, icon: _add, selected: false, onTap: go),
    ),
    kind: ControlKind.other,
  ),
  InteractiveCase(
    'FrostPageIndicator.new',
    FrostPageIndicator,
    (go) => FrostPageIndicator(count: 3, current: 0, onSelected: (_) => go()),
    kind: ControlKind.other,
  ),
  InteractiveCase(
    'FrostSectionHeader.new',
    FrostSectionHeader,
    (go) => FrostSectionHeader(title: longLabel, actionLabel: 'More', onAction: go),
    kind: ControlKind.other,
    target: _text('More'),
    focusTarget: find.byType(FrostSectionHeader),
  ),
  InteractiveCase(
    'FrostSectionHeader.collapsible',
    FrostSectionHeader,
    (go) => FrostSectionHeader.collapsible(title: longLabel, expanded: false, onExpansionChanged: (_) => go(), child: const Text('Body')),
    kind: ControlKind.other,
  ),
  InteractiveCase(
    'FrostDisclosure.new',
    FrostDisclosure,
    // Controlled, so the header stays put between the corner taps.
    (go) => FrostDisclosure(title: longLabel, expanded: false, onExpansionChanged: (_) => go(), child: const Text('Body')),
    kind: ControlKind.other,
  ),
  InteractiveCase(
    'FrostTabBar.new',
    FrostTabBar,
    (go) => FrostTabBar(
      tabs: const [
        FrostTab(label: 'One'),
        FrostTab(label: 'Two'),
      ],
      controller: _tabController(),
      onTap: (_) => go(),
    ),
    kind: ControlKind.other,
    target: _text('Two'),
    focusTarget: find.byType(FrostTabBar),
  ),
  InteractiveCase(
    'FrostTabStrip.new',
    FrostTabStrip<String>,
    (go) => hosted(
      height: 44,
      child: FrostTabStrip<String>(
        controller: FrostTabsController<String>(initial: 'a'),
        label: (context, tab) => const FrostTabLabel(title: 'Tab'),
        closeTooltip: 'Close',
        newTabTooltip: 'New tab',
        newTabIcon: _add,
        onNewTab: go,
      ),
    ),
    kind: ControlKind.other,
    target: find.byWidgetPredicate((widget) => widget is FrostTooltip && widget.message == 'New tab'),
  ),
  InteractiveCase(
    'FrostTable.new',
    FrostTable<int>,
    (go) => hosted(
      height: 300,
      width: 400,
      child: FrostTable<int>(
        columns: [FrostTableColumn<int>(label: longLabel, cell: (context, item) => Text('Item $item'))],
        rows: const [1, 2],
        onActivate: (_) => go(),
      ),
    ),
    target: _text('Item 1'),
    focusTarget: find.byType(FrostTable<int>),
    skip: _coveredAsDisplay,
  ),
  // The shell's Back button, which sits in the title bar on desktop.
  InteractiveCase(
    'FrostShell.new',
    FrostShell,
    (go) => FrostShell(
      destinations: [FrostNavDestination(icon: _add, label: 'Home')],
      selectedIndex: 0,
      atDestinationRoot: false,
      onDestinationSelected: (_) {},
      canGoBack: true,
      onBack: go,
      showsMobileNavigation: false,
      child: const SizedBox.expand(),
    ),
    target: find.byKey(const ValueKey('frost-shell-back')),
    subject: find.byKey(const ValueKey('frost-shell-back')),
    skip: _coveredAsDisplay,
  ),
];

const _inVideoFrame = {'intrinsic': 'the button is hosted in a FrostVideoFrame, whose own intrinsic size is checked on FrostVideoFrame'};

const _coveredAsDisplay = {
  'text-scale': 'the layout of the whole component is not what this case is about; it exists for the part named in its target',
  'rtl': 'the layout of the whole component is not what this case is about; it exists for the part named in its target',
  'intrinsic': 'the layout of the whole component is not what this case is about; it exists for the part named in its target',
  'no-theme': 'the layout of the whole component is not what this case is about; it exists for the part named in its target',
  'reduced-motion': 'the layout of the whole component is not what this case is about; it exists for the part named in its target',
};

Finder _mediaButton(String label) => find.byWidgetPredicate((widget) => widget is FrostMediaButton && widget.label == label);

Widget _videoFrame({VoidCallback? onPlayPause, List<Widget> controls = const []}) => hosted(
  height: 240,
  width: 400,
  child: FrostVideoFrame(
    video: const ColoredBox(color: Colors.black),
    state: const FrostVideoState(playing: false, position: Duration.zero, duration: Duration(seconds: 60)),
    onPlayPause: onPlayPause ?? () {},
    onSeek: (_) async {},
    controls: controls,
  ),
);

FrostTabController _tabController() => FrostTabController(length: 2, vsync: const TestVSync());
