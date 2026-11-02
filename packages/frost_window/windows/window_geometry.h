#ifndef FROST_WINDOW_GEOMETRY_H_
#define FROST_WINDOW_GEOMETRY_H_
#include <windows.h>
#include <flutter/encodable_value.h>

namespace frost_window {
flutter::EncodableValue WindowEnvironment();
flutter::EncodableValue WindowGeometry(HWND window, bool fullscreen,
                                      const WINDOWPLACEMENT* fullscreen_restore);
bool ApplyWindowPlacement(HWND window, const flutter::EncodableMap& arguments,
                          bool* show_maximized);
}  // namespace frost_window
#endif
