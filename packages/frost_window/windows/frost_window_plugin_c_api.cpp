#include "include/frost_window/frost_window_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "frost_window_plugin.h"

void FrostWindowPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  frost_window::FrostWindowPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
