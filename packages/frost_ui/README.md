# frost_ui

Shared Frost UI components, adaptive layouts, materials and motion. frost_ui,
frost_data and frost_window share one version.

For a window that stays hidden until its first frame, call `prepare` before
`runApp` and `show` after the first rasterized frame. The runner changes each
platform needs are in
[native startup and restoration](../frost_window/README.md#first-window-and-app-owned-restoration).

## Native window integration

`frost_ui` owns `FrostWindowHost`, caption controls, native-button clearance,
theme/transparency integration, focus management and Flutter Back navigation.
The lower-level `frost_window` plugin owns native capabilities and operations;
it does not depend on this UI package. Public window APIs are available through
`package:frost_ui/frost_ui.dart`.

Applications depend on the `main` branch:

```yaml
dependencies:
  frost_ui:
    git:
      url: https://github.com/normalllll/frost_ui.git
      ref: main
      path: packages/frost_ui
```

The relative `../frost_window` dependency resolves to the same repository
commit. For local development, an untracked `pubspec_overrides.yaml` points
each declared Frost package at a local checkout:

```yaml
dependency_overrides:
  frost_ui:
    path: ../frost_ui/packages/frost_ui
```

Install `FrostWindowHost` above the app Navigator and compose `FrostShell` or
shared page headers inside it. Windows/Linux use Flutter client controls with
native window actions; macOS retains AppKit's original traffic lights in a
transparent full-size content title region. `FrostShell` reserves a native-only
drag strip on macOS and places Back and branding below it. Wide mobile layouts
share the sidebar header when no client titlebar is available.

Full-window media headers compose `FrostNativeCaptionPadding` before their
content gutters. `FrostCaptionClearance` prevents nested headers from reserving
native-button space twice. Keep app-runner decoration settings in the plugin.

Linux controls follow GTK's button layout and system symbolic icons, with
Adwaita defaults and limited Breeze hover styling. Missing icons use Frost's
vector fallback. Window dragging, resizing and actions remain native GTK/GDK
operations; arbitrary compositor decoration themes are not reproduced.

Run every package's analysis and tests from the repository root:

```sh
dart tool/affected_tests.dart --all --run
```

No SDK, engine or dependency patches are required.
