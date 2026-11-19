#ifndef FROST_WINDOW_GEOMETRY_H_
#define FROST_WINDOW_GEOMETRY_H_
#include <windows.h>
#include <flutter/encodable_value.h>

namespace frost_window {
flutter::EncodableValue WindowEnvironment();
// `occluded` is the plugin's last evaluation of whether other windows cover
// the window; it is not recomputed here because geometry is read often.
flutter::EncodableValue WindowGeometry(HWND window, bool fullscreen,
                                      const WINDOWPLACEMENT* fullscreen_restore,
                                      bool occluded);
bool ApplyWindowPlacement(HWND window, const flutter::EncodableMap& arguments,
                          bool* show_maximized);
// Places the outer frame given as {rect, displayId?} in the same
// work-area-relative logical coordinates as ApplyWindowPlacement. Without a
// displayId the display currently holding the window is used.
bool ApplyWindowFrame(HWND window, const flutter::EncodableMap& arguments,
                      bool* show_maximized);
}  // namespace frost_window
#endif
