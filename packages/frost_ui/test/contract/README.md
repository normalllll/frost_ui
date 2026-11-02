# Component contract tests

The uniform behavior every public component must follow. An ordinary widget test checks what a single component does right; here the question is whether it left out something every component should have.

These tests are written by an agent that does not take part in the implementation. When one cannot be made to pass, change the component, not the test; when a test really is wrong, raise it with evidence.

## Files

- `harness.dart`: the runtime environment and the check functions.
- `registry.dart`: the component registry.
- `<family>_contract_test.dart`: the cases of each family, one file per family, so that changing one component does not select all of them.
- `coverage_contract_test.dart`: whether the registry is complete. It does not cover `frost_data`, which has its own suite.
- `harness_self_test.dart`: the control cases for the check functions themselves.

At run time the tests read `../../tool/library_health/public_api.txt` and `allowlist.txt` (the working directory of `flutter test` is `packages/frost_ui`).

## Known failures

On the first run the existing components have many failures; they are recorded in `tool/library_health/allowlist.txt`:

```
contract	<case ID>	-	<check name>	1	<reason>
```

- A failure of that check in that cell is expected, and the test passes.
- When the check in that cell **passes**, the test fails and asks for the line to be deleted, so the list does not stay behind after the fix.
- A failing check without such a line fails the test.
- The gate reports a new `contract` line as growth, so a line cannot be added to get around it.

## Registry

Every `class` line in `public_api.txt` must appear in the registry, either as the cases of one family or with a category stating why it does not apply: `data` (data or values), `controller` (controllers), `style` (style configuration), `scope` (environment components), `layout-helper` (pure layout; no entry needed when it is already in the layout family).

For a class of an interactive family, every public constructor (the `ctor` lines in `public_api.txt`) needs one case, and the case ID is `ClassName.new` or `ClassName.named`. A new export or constructor that is not registered fails `coverage_contract_test.dart`.

Cases use only the public API: `package:frost_ui/frost_ui.dart`, and the sub-entries `media.dart`, `social.dart` and `desktop.dart` where a symbol lives.

The components of `frost_data` are in `packages/frost_data/test/contract/` and reuse the `harness.dart` here. Their case IDs and `contract` lines carry the `frost_data:` prefix, and a `public_api.txt` line whose `file` field begins with `frost_data:` is checked by the `coverage_contract_test.dart` over there.

## Environment

Assemble `FrostApp` with `testFonts`, `testIcons` and the rest of `test/support.dart`. The default window is 1200x800 on a pointer platform (Windows). When touch is needed, use the Android platform.

## Families and checks

### interactive: buttons, switches, inputs, pickers, tappable rows and cards

Each case supplies a build function (which receives the callback to call when activated) and a tappable target.

| Check | Condition to pass |
|---|---|
| `disabled-scope` | Placed in `FrostControlScope(enabled: false)`: tapping, and focusing then pressing Enter or Space, do not trigger the callback |
| `disabled-semantics` | In the same scope, every semantics node with an action inside the component is marked disabled and has no tap, longPress, focus, increase, decrease or setText action |
| `semantics` | When enabled, the semantics node has a non-empty label and a tap action (an input field has a focus action) |
| `keyboard` | Tab can focus it; buttons and switches trigger the callback on Enter or Space |
| `touch-target` | On a touch platform, a tap just inside each of the four corners (inset by 1 pixel) of a 44x44 box centered on the target triggers the callback. A small control pads its hit area to 44 internally |
| `text-scale` | Window 400x800, text at 2x: no exception, no overflow reported, and text not inside a scroll container does not extend beyond the window. Cases use long labels and multi-digit numbers, not content of one or two characters |
| `rtl` | Text direction RTL: no exception, no overflow reported. When a case supplies a leading and a trailing child, their horizontal positions are mirrored about the component's center, within 1 pixel |
| `reduced-motion` | `disableAnimations: true`: after activation, `pump(150ms)` leaves no running animation and no scheduled frame. Control geometry goes straight to the end point, and a modal layer fades for at most 120 ms |

### display: non-interactive display and layout components

| Check | Condition to pass |
|---|---|
| `text-scale` | As above |
| `rtl` | As above |

### all: every case, interactive and display alike

| Check | Condition to pass |
|---|---|
| `intrinsic` | The component placed directly in `IntrinsicWidth` and `IntrinsicHeight` with no fixed size around it: no exception, a measured size greater than 0 when it has content, and not smaller than the natural size of the same content under loose constraints. Components that are themselves a viewport (slivers, lists, tables) are skipped, with the reason stated |
| `no-theme` | With only `WidgetsApp` and no Frost environment: it throws or reports through `FlutterError`, and must not render silently. A component that only lays out its children and never reads the Frost environment is skipped, with the reason stated |

### hiding: components that hide a subtree

At least `FrostSpringReveal`, `FrostLazyIndexedStack` and `FrostTabHost`.

| Check | Condition to pass |
|---|---|
| `hidden-focus` | While hidden, a button in the subtree cannot be focused with Tab |
| `hidden-tap` | While hidden, tapping the original position does not trigger the callback |
| `hidden-ticker` | While hidden, `TickerMode.of` of the subtree is false |

### overlay: dialogs, sheets, confirmation dialogs, form dialogs, menus, popovers

Each case can open the overlay and supplies the `PopScope` inside its content.

| Check | Condition to pass |
|---|---|
| `popscope-esc` | With `canPop: false`, pressing Esc does not close it |
| `popscope-close` | With `canPop: false`, tapping the overlay's own close button does not close it (skipped when there is no close button) |
| `popscope-drag` | With `canPop: false`, a drag-to-dismiss does not close it and it springs back (skipped when it cannot be dragged) |
| `popscope-back` | With `canPop: false`, the system back action does not close it |
| `barrier` | With `barrierDismissible: false`, neither tapping the barrier nor dragging closes it (skipped when there is no such parameter) |
| `back-only-overlay` | System back closes only the overlay, and the page beneath stays |
| `esc-only-overlay` | Placed in `FrostShell` and a nested `Navigator`: Esc closes only the overlay, the shell's back handler is not called, and the page beneath stays |

### decisions: behavior fixed by the owner

Behavior fixed by the owner, one case each:

| Check | Condition to pass |
|---|---|
| `confirm-enter` | Danger confirmation dialog: initial focus is on "Cancel", so pressing Enter then results in cancel; Tab to the confirm button and press Enter results in confirm |
| `menu-enter` | Open a picker menu inside a form dialog and press Enter on the highlighted item: the item is selected, the form is not submitted, and the dialog outside the menu does not enter the loading state |
| `shell-esc` | In `FrostShell` with no overlay, pressing Esc on the page or in an input field does not leave the current page |
| `focus-ring-mouse` | After Tab focuses a button, moving the mouse keeps the focus ring; it is hidden only after a mouse click |
| `no-global-highlight` | After mounting `FrostApp`, `FocusManager.instance.highlightStrategy` is unchanged; the app's own `InkWell` focus highlight is not affected |
| `desktop-selection` | Selection in lists and cards: Ctrl-click selects, after that a plain click opens the item instead of toggling; selection mode ends when the selection becomes empty; on macOS Cmd is equivalent to Ctrl |
| `modal-autofocus` | Opening a sheet or dialog on a touch platform does not autofocus an input field inside it, unless the caller wrote `autofocus` |
| `mouse-drag` | On a pointer platform, dragging `FrostRefreshView` with the mouse neither refreshes nor scrolls |

## Self controls

`harness_self_test.dart` proves the checks can really fail: for each check function it writes one small widget that deliberately violates the rule (ignores the disabled scope, hit area too small, animation never stops, swallows `PopScope`, and so on) and one that complies; the violating one must be judged a failure and the compliant one a pass. Run it together whenever a check function changes.
