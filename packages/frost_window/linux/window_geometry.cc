#include "window_geometry.h"
#include <cmath>
#include <string>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

namespace {
bool position_supported(GdkDisplay* display) {
#ifdef GDK_WINDOWING_X11
  return GDK_IS_X11_DISPLAY(display);
#else
  return false;
#endif
}
std::string monitor_id(GdkMonitor* monitor, int index) {
  const char* make = gdk_monitor_get_manufacturer(monitor);
  const char* model = gdk_monitor_get_model(monitor);
  std::string id = std::string(make ? make : "") + ":" + (model ? model : "");
#ifdef GDK_WINDOWING_X11
  if (GDK_IS_X11_MONITOR(monitor)) return id + ":" + std::to_string(gdk_x11_monitor_get_output(monitor));
#endif
  // GTK3 Wayland has no connector/EDID identity API. Ordinals distinguish
  // identical screens within the current topology; they are not durable IDs.
  return id + ":" + std::to_string(index);
}
FlValue* rectangle(const GdkRectangle& rect, int x = 0, int y = 0) {
  auto* row = fl_value_new_list();
  for (int v : {rect.x-x, rect.y-y, rect.x+rect.width-x, rect.y+rect.height-y}) fl_value_append_take(row, fl_value_new_float(v));
  return row;
}
double number(FlValue* value) {
  if (!value) return NAN;
  if (fl_value_get_type(value) == FL_VALUE_TYPE_FLOAT) return fl_value_get_float(value);
  if (fl_value_get_type(value) == FL_VALUE_TYPE_INT) return static_cast<double>(fl_value_get_int(value));
  return NAN;
}
int index_of(GdkDisplay* display, GdkMonitor* monitor) {
  for (int i=0; i<gdk_display_get_n_monitors(display); ++i) if (gdk_display_get_monitor(display, i) == monitor) return i;
  return 0;
}
}

FlValue* frost_window_environment(GtkWindow* window) {
  auto* display = gtk_widget_get_display(GTK_WIDGET(window));
  auto* result = fl_value_new_map();
  auto* list = fl_value_new_list();
  const bool positions = position_supported(display);
  fl_value_set_string_take(result, "positionSupported", fl_value_new_bool(positions));
  for (int i=0; i<gdk_display_get_n_monitors(display); ++i) {
    auto* monitor = gdk_display_get_monitor(display, i);
    GdkRectangle bounds{}, work{};
    gdk_monitor_get_geometry(monitor, &bounds);
    gdk_monitor_get_workarea(monitor, &work);
    auto* item = fl_value_new_map();
    fl_value_set_string_take(item, "id", fl_value_new_string(monitor_id(monitor, i).c_str()));
    fl_value_set_string_take(item, "bounds", rectangle(bounds));
    fl_value_set_string_take(item, "workArea", rectangle(work));
    fl_value_set_string_take(item, "scale", fl_value_new_float(gdk_monitor_get_scale_factor(monitor)));
    fl_value_set_string_take(item, "coordinateScale", fl_value_new_float(1));
    fl_value_set_string_take(item, "primary", fl_value_new_bool(monitor == gdk_display_get_primary_monitor(display)));
    fl_value_append_take(list, item);
  }
  if (positions) {
    auto* seat = gdk_display_get_default_seat(display);
    auto* pointer = seat ? gdk_seat_get_pointer(seat) : nullptr;
    if (pointer) {
      int x=0, y=0;
      gdk_device_get_position(pointer, nullptr, &x, &y);
      auto* monitor = gdk_display_get_monitor_at_point(display, x, y);
      if (monitor) fl_value_set_string_take(result, "cursorDisplayId", fl_value_new_string(monitor_id(monitor, index_of(display, monitor)).c_str()));
    }
  }
  fl_value_set_string_take(result, "displays", list);
  return result;
}

FlValue* frost_window_geometry(GtkWindow* window, GdkRectangle* normal, gboolean* normal_maximized, bool fullscreen, bool transitioning) {
  auto* display = gtk_widget_get_display(GTK_WIDGET(window));
  auto* native = gtk_widget_get_window(GTK_WIDGET(window));
  auto* monitor = native ? gdk_display_get_monitor_at_window(display, native) : gdk_display_get_primary_monitor(display);
  if (!monitor) monitor = gdk_display_get_monitor(display, 0);
  GdkRectangle work{}, frame{};
  if (monitor) gdk_monitor_get_workarea(monitor, &work);
  const bool positions = position_supported(display);
  if (positions) gtk_window_get_position(window, &frame.x, &frame.y);
  gtk_window_get_size(window, &frame.width, &frame.height);
  const auto state = native ? gdk_window_get_state(native) : static_cast<GdkWindowState>(0);
  if (!fullscreen && !transitioning && !(state & GDK_WINDOW_STATE_ICONIFIED)) {
    *normal_maximized = gtk_window_is_maximized(window);
    if (!*normal_maximized) *normal = frame;
  }
  if (normal->width <= 0 || normal->height <= 0) *normal = frame;
  auto* result = fl_value_new_map();
  fl_value_set_string_take(result, "displayId", fl_value_new_string(monitor ? monitor_id(monitor, index_of(display, monitor)).c_str() : "unknown"));
  fl_value_set_string_take(result, "rect", rectangle(*normal, positions ? work.x : 0, positions ? work.y : 0));
  fl_value_set_string_take(result, "frame", rectangle(frame, positions ? work.x : 0, positions ? work.y : 0));
  fl_value_set_string_take(result, "workAreaSize", rectangle(GdkRectangle{0, 0, work.width, work.height}));
  fl_value_set_string_take(result, "displayScale", fl_value_new_float(monitor ? gdk_monitor_get_scale_factor(monitor) : 1));
  fl_value_set_string_take(result, "positionSupported", fl_value_new_bool(positions));
  fl_value_set_string_take(result, "maximized", fl_value_new_bool(*normal_maximized));
  fl_value_set_string_take(result, "minimized", fl_value_new_bool((state & GDK_WINDOW_STATE_ICONIFIED) != 0));
  fl_value_set_string_take(result, "fullscreen", fl_value_new_bool(fullscreen));
  return result;
}

bool frost_apply_placement(GtkWindow* window, FlValue* args, GdkRectangle* normal) {
  if (!args || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) return false;
  auto* id = fl_value_lookup_string(args, "displayId");
  auto* rect = fl_value_lookup_string(args, "rect");
  auto* max = fl_value_lookup_string(args, "maximized");
  if (!id || fl_value_get_type(id) != FL_VALUE_TYPE_STRING || !rect || fl_value_get_type(rect) != FL_VALUE_TYPE_LIST || fl_value_get_length(rect) != 4 || !max || fl_value_get_type(max) != FL_VALUE_TYPE_BOOL) return false;
  double v[4];
  for (int i=0; i<4; ++i) { v[i] = number(fl_value_get_list_value(rect, i)); if (!std::isfinite(v[i]) || std::abs(v[i]) > 1000000) return false; }
  if (v[2]<=v[0] || v[3]<=v[1]) return false;
  auto* display = gtk_widget_get_display(GTK_WIDGET(window));
  GdkMonitor* target = nullptr;
  for (int i=0; i<gdk_display_get_n_monitors(display); ++i) {
    auto* monitor = gdk_display_get_monitor(display, i);
    if (monitor_id(monitor, i) == fl_value_get_string(id)) target = monitor;
  }
  if (!target) return false;
  GdkRectangle work{};
  gdk_monitor_get_workarea(target, &work);
  *normal = {work.x+static_cast<int>(std::round(v[0])), work.y+static_cast<int>(std::round(v[1])), static_cast<int>(std::round(v[2]-v[0])), static_cast<int>(std::round(v[3]-v[1]))};
  if (gtk_window_is_maximized(window)) gtk_window_unmaximize(window);
  gtk_window_set_default_size(window, normal->width, normal->height);
  gtk_window_resize(window, normal->width, normal->height);
  if (position_supported(display)) gtk_window_move(window, normal->x, normal->y);
  if (fl_value_get_bool(max)) gtk_window_maximize(window);
  return true;
}
