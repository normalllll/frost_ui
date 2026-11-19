#include "window_geometry.h"

#include <shellscalingapi.h>
#include <algorithm>
#include <cmath>
#include <string>
#include <vector>

namespace frost_window {
namespace {
using Value = flutter::EncodableValue;
using Map = flutter::EncodableMap;
using List = flutter::EncodableList;

struct Display {
  HMONITOR monitor;
  MONITORINFOEXW info;
  std::string id;
  double scale;
};

std::string Utf8(const wchar_t* value) {
  const int length = WideCharToMultiByte(CP_UTF8, 0, value, -1, nullptr, 0, nullptr, nullptr);
  if (length <= 1) return "";
  std::string text(static_cast<size_t>(length), '\0');
  WideCharToMultiByte(CP_UTF8, 0, value, -1, text.data(), length, nullptr, nullptr);
  text.pop_back();
  return text;
}

Display ReadDisplay(HMONITOR monitor) {
  Display display{};
  display.monitor = monitor;
  display.info.cbSize = sizeof(MONITORINFOEXW);
  GetMonitorInfoW(monitor, &display.info);
  DISPLAY_DEVICEW device{};
  device.cb = sizeof(device);
  // Monitor interface paths survive enumeration-order changes; the adapter's
  // DISPLAY1 name alone does not reliably identify a disconnected display.
  display.id = EnumDisplayDevicesW(display.info.szDevice, 0, &device, EDD_GET_DEVICE_INTERFACE_NAME) && device.DeviceID[0]
      ? Utf8(device.DeviceID) : Utf8(display.info.szDevice);
  UINT x = 96, y = 96;
  if (FAILED(GetDpiForMonitor(monitor, MDT_EFFECTIVE_DPI, &x, &y))) x = 96;
  display.scale = static_cast<double>(x) / 96.0;
  return display;
}

BOOL CALLBACK Collect(HMONITOR monitor, HDC, LPRECT, LPARAM data) {
  reinterpret_cast<std::vector<Display>*>(data)->push_back(ReadDisplay(monitor));
  return TRUE;
}

Value RectValue(const RECT& rect, double scale = 1, LONG x = 0, LONG y = 0) {
  return Value(List{Value((rect.left - x) / scale), Value((rect.top - y) / scale),
                    Value((rect.right - x) / scale), Value((rect.bottom - y) / scale)});
}

double Number(const Value& value) {
  if (const auto* n = std::get_if<double>(&value)) return *n;
  if (const auto* n = std::get_if<int32_t>(&value)) return *n;
  if (const auto* n = std::get_if<int64_t>(&value)) return static_cast<double>(*n);
  return NAN;
}
}  // namespace

Value WindowEnvironment() {
  std::vector<Display> displays;
  EnumDisplayMonitors(nullptr, nullptr, Collect, reinterpret_cast<LPARAM>(&displays));
  POINT cursor{};
  const auto cursor_monitor = GetCursorPos(&cursor) ? MonitorFromPoint(cursor, MONITOR_DEFAULTTONEAREST) : nullptr;
  List values;
  std::string cursor_id;
  for (const auto& display : displays) {
    if (display.monitor == cursor_monitor) cursor_id = display.id;
    values.emplace_back(Map{
      {Value("id"), Value(display.id)}, {Value("bounds"), RectValue(display.info.rcMonitor)},
      {Value("workArea"), RectValue(display.info.rcWork)}, {Value("scale"), Value(display.scale)},
      {Value("coordinateScale"), Value(display.scale)},
      {Value("primary"), Value((display.info.dwFlags & MONITORINFOF_PRIMARY) != 0)},
    });
  }
  return Value(Map{{Value("displays"), Value(values)}, {Value("cursorDisplayId"), Value(cursor_id)},
                   {Value("positionSupported"), Value(true)}});
}

Value WindowGeometry(HWND window, bool fullscreen, const WINDOWPLACEMENT* fullscreen_restore, bool occluded) {
  RECT frame{};
  GetWindowRect(window, &frame);
  WINDOWPLACEMENT placement{sizeof(WINDOWPLACEMENT)};
  GetWindowPlacement(window, &placement);
  if (fullscreen && fullscreen_restore != nullptr) placement = *fullscreen_restore;
  RECT normal = placement.rcNormalPosition;
  auto display = ReadDisplay(MonitorFromRect(&normal, MONITOR_DEFAULTTONEAREST));
  // WINDOWPLACEMENT uses workspace coordinates, unlike GetWindowRect. Apply
  // only the work-area offset; never scale the absolute desktop origin.
  OffsetRect(&normal, display.info.rcWork.left - display.info.rcMonitor.left,
                     display.info.rcWork.top - display.info.rcMonitor.top);
  if (!fullscreen && !IsIconic(window) && !IsZoomed(window)) normal = frame;
  display = ReadDisplay(MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST));
  const auto& work = display.info.rcWork;
  const double scale = display.scale;
  return Value(Map{
    {Value("displayId"), Value(display.id)}, {Value("rect"), RectValue(normal, scale, work.left, work.top)},
    {Value("frame"), RectValue(frame, scale, work.left, work.top)},
    {Value("workAreaSize"), Value(List{Value(0.0), Value(0.0), Value((work.right-work.left)/scale), Value((work.bottom-work.top)/scale)})},
    {Value("displayScale"), Value(scale)}, {Value("positionSupported"), Value(true)},
    {Value("maximized"), Value(fullscreen ? placement.showCmd == SW_SHOWMAXIMIZED :
        IsZoomed(window) != FALSE || (IsIconic(window) && (placement.flags & WPF_RESTORETOMAXIMIZED) != 0))},
    {Value("minimized"), Value(IsIconic(window) != FALSE)}, {Value("fullscreen"), Value(fullscreen)},
    {Value("alwaysOnTop"), Value((GetWindowLongPtr(window, GWL_EXSTYLE) & WS_EX_TOPMOST) != 0)},
    {Value("occluded"), Value(occluded)},
  });
}

namespace {
// Reads a validated rectangle row [left, top, right, bottom].
bool ReadRow(const Value& value, double (&out)[4]) {
  const auto* row = std::get_if<List>(&value);
  if (!row || row->size() != 4) return false;
  for (int i = 0; i < 4; ++i) {
    out[i] = Number((*row)[i]);
    if (!std::isfinite(out[i]) || std::abs(out[i]) > 1000000) return false;
  }
  return out[2] > out[0] && out[3] > out[1];
}

bool FindDisplay(const std::string& id, Display* found) {
  std::vector<Display> displays;
  EnumDisplayMonitors(nullptr, nullptr, Collect, reinterpret_cast<LPARAM>(&displays));
  const auto display = std::find_if(displays.begin(), displays.end(), [&](const auto& d) { return d.id == id; });
  if (display == displays.end()) return false;
  *found = *display;
  return true;
}

// Moves a window to a work-area-relative logical rectangle on `display`.
bool PlaceOnDisplay(HWND window, const Display& display, const double (&values)[4]) {
  const auto& work = display.info.rcWork;
  const double scale = display.scale;
  RECT normal{static_cast<LONG>(std::lround(work.left + values[0] * scale)),
              static_cast<LONG>(std::lround(work.top + values[1] * scale)),
              static_cast<LONG>(std::lround(work.left + values[2] * scale)),
              static_cast<LONG>(std::lround(work.top + values[3] * scale))};
  if (IsWindowVisible(window) && (IsZoomed(window) || IsIconic(window))) ShowWindow(window, SW_RESTORE);
  // Hidden startup never shows even a single frame at the runner's template
  // size. show() applies the maximize target as its first visible state.
  return SetWindowPos(window, nullptr, normal.left, normal.top, normal.right-normal.left, normal.bottom-normal.top,
                      SWP_NOZORDER | SWP_NOACTIVATE | SWP_NOOWNERZORDER) != FALSE;
}
}  // namespace

bool ApplyWindowPlacement(HWND window, const Map& arguments, bool* show_maximized) {
  const auto id = arguments.find(Value("displayId"));
  const auto rect = arguments.find(Value("rect"));
  const auto maximized = arguments.find(Value("maximized"));
  if (id == arguments.end() || rect == arguments.end() || maximized == arguments.end()) return false;
  const auto* name = std::get_if<std::string>(&id->second);
  const auto* zoomed = std::get_if<bool>(&maximized->second);
  double values[4];
  Display display{};
  if (!name || !zoomed || !ReadRow(rect->second, values) || !FindDisplay(*name, &display)) return false;
  if (!PlaceOnDisplay(window, display, values)) return false;
  *show_maximized = *zoomed;
  if (IsWindowVisible(window) && *zoomed) ShowWindow(window, SW_MAXIMIZE);
  return true;
}

bool ApplyWindowFrame(HWND window, const Map& arguments, bool* show_maximized) {
  const auto rect = arguments.find(Value("rect"));
  if (rect == arguments.end()) return false;
  double values[4];
  if (!ReadRow(rect->second, values)) return false;
  Display display{};
  if (const auto id = arguments.find(Value("displayId")); id != arguments.end()) {
    const auto* name = std::get_if<std::string>(&id->second);
    if (!name || !FindDisplay(*name, &display)) return false;
  } else {
    display = ReadDisplay(MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST));
  }
  if (!PlaceOnDisplay(window, display, values)) return false;
  *show_maximized = false;
  return true;
}
}  // namespace frost_window
