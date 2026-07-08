import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {

  /// When true the window can become key/main and the app activates (used for
  /// the settings screen). When false it behaves as a non-activating floating
  /// overlay so dictation never steals focus from the target application.
  private var shouldActivateOnShow: Bool = false

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    configureFloatingPanel()
    RegisterGeneratedPlugins(registry: flutterViewController)
    setupMethodChannel(flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()

    // Start hidden; the Dart side controls visibility on demand.
    self.orderOut(nil)
  }

  private func configureFloatingPanel() {
    self.styleMask = [.borderless]
    self.isOpaque = false
    self.backgroundColor = .clear
    self.hasShadow = true
    self.isMovable = false
    self.level = .floating
    self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
  }

  override var canBecomeKey: Bool { shouldActivateOnShow }
  override var canBecomeMain: Bool { shouldActivateOnShow }

  private func setupMethodChannel(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.whisperbar/window",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "show":
        if let args = call.arguments as? [String: Any] {
          self.shouldActivateOnShow = (args["activate"] as? Bool) ?? false
          if let w = (args["width"] as? NSNumber)?.doubleValue,
             let h = (args["height"] as? NSNumber)?.doubleValue {
            self.setContentSize(NSSize(width: w, height: h))
          }
        }
        self.showPopup()
        result(nil)
      case "hide":
        self.orderOut(nil)
        result(nil)
      case "setSize":
        if let args = call.arguments as? [String: Any],
           let w = (args["width"] as? NSNumber)?.doubleValue,
           let h = (args["height"] as? NSNumber)?.doubleValue {
          self.setContentSize(NSSize(width: w, height: h))
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func showPopup() {
    let screen = NSScreen.screenContainingMouse() ?? NSScreen.main
    guard let visible = screen?.visibleFrame else { return }
    let size = self.frame.size
    let x = visible.midX - size.width / 2
    let y = visible.maxY - size.height - 120
    self.setFrameOrigin(NSPoint(x: x, y: y))

    if shouldActivateOnShow {
      NSApp.activate(ignoringOtherApps: true)
      self.makeKeyAndOrderFront(nil)
    } else {
      self.orderFrontRegardless()
    }
  }
}

extension NSScreen {
  static func screenContainingMouse() -> NSScreen? {
    let mouse = NSEvent.mouseLocation
    return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
      ?? NSScreen.main
  }
}
