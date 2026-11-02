#ifndef FROST_GTK_WINDOW_GEOMETRY_H_
#define FROST_GTK_WINDOW_GEOMETRY_H_
#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

FlValue* frost_window_environment(GtkWindow* window);
FlValue* frost_window_geometry(GtkWindow* window, GdkRectangle* normal, gboolean* normal_maximized, bool fullscreen, bool transitioning);
bool frost_apply_placement(GtkWindow* window, FlValue* args, GdkRectangle* normal);
#endif
