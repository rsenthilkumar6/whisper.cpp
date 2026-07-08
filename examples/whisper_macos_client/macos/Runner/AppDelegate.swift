import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {

  override func applicationDidFinishLaunching(_ notification: Notification) {
    // Run as a menu-bar agent (no Dock icon, only the tray icon).
    NSApp.setActivationPolicy(.accessory)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    // The window is hidden, not closed; keep the agent running in the tray.
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
