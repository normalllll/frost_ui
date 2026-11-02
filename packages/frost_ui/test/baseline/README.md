# Constructor baselines

This folder holds one test file per public component. Every case renders in
each of its environments and fails if the constructor throws or the layout
overflows. Nothing is recorded; widget tests check layout and semantics.

- Harness: `baseline.dart` (`baselineGroup`, `BaselineCase`, `BaselineEnv`,
  `baselineHover` / `baselinePress` / `baselineTap` / `baselineFocus`,
  `baselineIcon`). Example: `frost_button_baseline_test.dart`.
- File per component: `<snake_case_name>_baseline_test.dart` calling
  `baselineGroup('<ComponentName>', [...])`.
- Case ids: `Constructor/summary`. `required` for the call with only required
  arguments; `param` or `param=value` for one varied argument; `a+b` for a
  listed combination; `#state` suffix for an interaction state
  (`#hover`, `#press`, `#focus`, `#open`, `#running`, `#done`).
- Which cases:
  - each constructor: one `required` case;
  - each optional argument varied once on its own;
  - the combinations a caller commonly writes together;
  - no full permutations.
- Environments: `BaselineEnv.standard` (dark, 1×, pointer, width 720) unless the
  argument depends on another dimension. `required` cases of visual components
  use `BaselineEnv.all`. Page-level components that fill their parent pass
  `height:` and use widths such as `BaselineEnv.standard.copyWith(width: 1280)`
  plus `BaselineEnv.narrow`.
- Run: `flutter test test/baseline/<file>`. Never run `flutter test` without
  named test files.

## Notes

- The environment width is the parent's maximum width; the test window stays
  at least 1280 wide. Widgets that read the window size (`MediaQuery`), such
  as the shell, size classes, tables, sheets and search suggestions, need a
  case that overrides `MediaQuery.size` or shrinks the view inside `act`
  (see `nav_overlay_support.dart` and `controls_support.dart`).
- `imageCache` lives for the whole file: a case that needs an image still
  loading uses a provider that never resolves, and a loaded image is decoded
  inside `tester.runAsync` before the first frame.
- Settling advances fake time but not plain timers; cases that wait on a
  `Timer` pump the duration in `act`.
- A bare `Text` outside a Material ancestor renders the debug style; use
  `FrostText` for sample content.
- Name test files literally on the command line (a glob works); the hook
  cannot see file names inside a shell variable.
