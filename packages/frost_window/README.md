# frost_window

Native desktop window capabilities and platform operations for Flutter.
This plugin depends only on Flutter; it does not import Frost UI, draw title
controls, select an app theme, or perform Flutter route navigation.

`FrostWindowController` owns registration, state updates, minimum window size,
drag/resize regions, title and appearance, minimize/maximize/close, system
backdrop requests, and native Back event delivery. `FrostWindowState` reports
actual capabilities, decoration mode, native button bounds, symbolic caption
icons and system transparency preference. The controller never infers these
from `Theme.platform`.

- **Windows:** native hit testing, resize borders, Snap Layouts, window menu,
  optional system Mica, and image clipboard transport.
- **Linux:** GTK client decoration capabilities, system button layout/icons,
  and GDK dragging, resizing and window actions from the original input event.
  A compositor window menu is available only when the compositor provides it.
- **macOS:** full-size content and a transparent title area with AppKit's
  original traffic lights. Their bounds follow native layout and full-screen.

The native API baseline is **macOS 12** and **GTK 3.24**, within Flutter 3.47's
[supported platforms](https://docs.flutter.dev/reference/supported-platforms).
Linux binaries also require the build distribution's glibc and media-library ABI.

## Frost UI integration

`FrostWindowHost`, title controls, theme/transparency integration, focus and
Flutter Back handling belong to `frost_ui`. Applications using Frost UI depend
only on `frost_ui` and import its public entry point. Its relative dependency
includes this plugin from the same checkout or Git commit. No overrides or
separate plugin Git ref are needed. The local example follows the same direction.

The plugin can also be consumed independently by non-Frost Flutter apps, which
provide their own widgets and navigation around `FrostWindowController`.

Hidden startup needs changes in both the App's native runner and its Dart
startup order; follow the startup sequence below. Placement persistence stays
in the App, and the App checks the runtime positioning capability before
restoring coordinates.

## macOS package managers

Both Swift Package Manager and CocoaPods compile the same Swift sources under
`macos/frost_window/Sources/frost_window`; the podspec points to that directory.
The deployment minimum remains macOS 12. Flutter 3.47 discovers the SPM manifest
automatically and can mix SPM plugins with CocoaPods-only media dependencies.

For integration checks, build the consuming app once with SPM enabled and once
with project-local `flutter.config.enable-swift-package-manager: false`. Keep
that validation setting in the test copy rather than changing global Flutter
configuration. A mixed build does not establish independence from CocoaPods.

## First window and App-owned restoration

The library never persists window data. Apps supply a `FrostWindowPlacement`
and save `controller.geometry.value?.placement.toMap()` themselves. Query
`queryEnvironment()` for displays/work areas/scales and runtime positioning
capability; `queryGeometry()` returns actual current and normal window frames.
The separate `geometry` listenable defaults to a 200ms trailing debounce.

`recommendFrostWindow` and `validateFrostWindow` are pure functions. Defaults:
16:10, preferred width up to 1280 logical pixels, 90% of each work-area axis,
centered and not maximized. Actual work area wins over minimum size; minimum
size wins over margin. Explicit preferred sizes retain their own aspect ratio.
Positions are logical offsets from a display's work-area top-left. Display
desktop rectangles retain native desktop coordinate units (`coordinateScale`
converts them); this avoids ambiguous mixed-DPI absolute coordinates.

For flicker-free startup, the native runner must remain hidden. On Windows,
remove the first-frame `Show` callback, keep `CreateWindow` free of `WS_VISIBLE`,
and run initial child `SetFocus` only if the window is already foreground.
Initialize Flutter binding, read App-owned data,
`await controller.prepare(saved: saved)`, then `runApp`; after
`binding.waitUntilFirstFrameRasterized`, call `await controller.show()`.
The Windows example includes the runner changes. macOS must disable visible
at launch/early order-front and frame autosave; GTK must omit early/first-frame
window show. Existing Apps do not opt into hidden startup automatically.

On Wayland the actual GDK backend reports
`FrostWindowPositionSupport.compositorControlled`: position is null, validation
reports `positionIgnoredUnsupported`, and only size/maximize are applied.
Monitor information remains available. X11 positioning is a request to the
window manager, not a guarantee. Handle the typed validation adjustments instead
of assuming that every desktop can restore an absolute position.

Windows native acceptance (the tool writes evidence, the library does not):

```powershell
cd packages/frost_window/example
flutter build windows --debug --target lib/placement_probe.dart
cd ../../..
python packages/frost_window/test/native_placement_windows.py --automation-skill <skill-directory> --output <new-evidence-directory>
```

The dedicated probe suppresses startup framework focus; never substitute the
normal entrypoint. Capture uses flutter-ui-automation's independent WGC HWND/PID
backend and checks an exact presentation marker. Maximize runs on an inactive
desktop without switching the user's desktop; its state checks are separate
from native presentation evidence.

## Caption contract checks

```sh
sh packages/frost_window/test/check_linux_caption.sh /path/to/app/linux/flutter/ephemeral
sh packages/frost_window/test/check_macos_caption.sh /path/to/FlutterMacOS.xcframework/macos-arm64_x86_64
```

Run from the repository root with the platform compiler/display session. Linux
checks need GTK 3.24 development libraries and an installed symbolic icon theme.
Controller checks live in this package; widget integration checks live in
`packages/frost_ui/test/window_host_test.dart`.
