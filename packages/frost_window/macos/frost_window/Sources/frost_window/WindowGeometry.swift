import Cocoa

// AppKit uses bottom-left desktop points; placements use logical offsets from
// the work area's top-left. No preference keys or frame autosave are used.
final class FrostWindowGeometryBridge {
  private weak var window: NSWindow?
  private var normalFrame: NSRect
  private var showMaximized = false
  private var normalMaximized = false
  init(_ window: NSWindow) { self.window = window; normalFrame = window.frame }

  private func screenID(_ screen: NSScreen) -> String {
    let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
    guard let id = number?.uint32Value, let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return "screen-\(number?.stringValue ?? "unknown")" }
    return CFUUIDCreateString(nil, uuid) as String
  }
  private func desktopRect(_ rect: NSRect) -> [Double] {
    let top = NSScreen.screens.first?.frame.maxY ?? 0
    return [rect.minX, top - rect.maxY, rect.maxX, top - rect.minY]
  }
  func environment() -> [String: Any] {
    let screens = NSScreen.screens
    let cursor = screens.first { $0.frame.contains(NSEvent.mouseLocation) }
    var result: [String: Any] = ["positionSupported": true,
      "displays": screens.enumerated().map { index, screen in [
        "id": screenID(screen), "bounds": desktopRect(screen.frame), "workArea": desktopRect(screen.visibleFrame),
        "scale": screen.backingScaleFactor, "coordinateScale": 1.0, "primary": index == 0,
      ] as [String: Any] }]
    if let cursor = cursor { result["cursorDisplayId"] = screenID(cursor) }
    return result
  }
  func geometry(fullscreen: Bool, transitioning: Bool) -> [String: Any] {
    guard let window = window, let screen = window.screen ?? NSScreen.screens.first else { return [:] }
    if !fullscreen && !transitioning {
      normalMaximized = window.isZoomed
      if !window.isZoomed && !window.isMiniaturized { normalFrame = window.frame }
    }
    let work = screen.visibleFrame
    func relative(_ rect: NSRect) -> [Double] { [rect.minX-work.minX, work.maxY-rect.maxY, rect.maxX-work.minX, work.maxY-rect.minY] }
    return ["displayId": screenID(screen), "rect": relative(normalFrame), "frame": relative(window.frame),
      "workAreaSize": [0.0, 0.0, work.width, work.height], "displayScale": screen.backingScaleFactor,
      "positionSupported": true, "maximized": fullscreen || transitioning ? normalMaximized : window.isZoomed,
      "minimized": window.isMiniaturized, "fullscreen": fullscreen]
  }
  func apply(_ args: [String: Any]) -> Bool {
    guard let window = window, let id = args["displayId"] as? String,
      let screen = NSScreen.screens.first(where: { screenID($0) == id }),
      let row = args["rect"] as? [NSNumber], row.count == 4,
      row.allSatisfy({ $0.doubleValue.isFinite && abs($0.doubleValue) < 1000000 }),
      let maximized = args["maximized"] as? Bool else { return false }
    let values = row.map { $0.doubleValue }
    guard values[2] > values[0], values[3] > values[1] else { return false }
    if window.isZoomed { window.zoom(nil) }
    let work = screen.visibleFrame
    normalFrame = NSRect(x: work.minX+values[0], y: work.maxY-values[3], width: values[2]-values[0], height: values[3]-values[1])
    window.setFrame(normalFrame, display: false)
    showMaximized = maximized
    if window.isVisible && maximized { window.zoom(nil) }
    return true
  }
  func show() {
    guard let window = window else { return }
    if showMaximized && !window.isZoomed { window.zoom(nil) }
    window.orderFront(nil)
  }
}
