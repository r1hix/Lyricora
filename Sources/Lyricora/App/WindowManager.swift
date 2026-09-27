import SwiftUI
import AppKit
import Observation

// Custom NSWindow with proper key/main status and clean native titlebar integration
final class LyricoraWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    
    override func makeTouchBar() -> NSTouchBar? {
        TouchBarService.shared.makeTouchBar()
    }
    
    override func keyDown(with event: NSEvent) {
        // Spacebar keycode 49
        if event.keyCode == 49 {
            SpotifyObserver.shared.togglePlayPause()
            return
        }
        super.keyDown(with: event)
    }
}

@Observable
@MainActor
public final class WindowManager: NSObject, NSWindowDelegate {
    public static let shared = WindowManager()
    
    public private(set) var window: NSWindow?
    public var panel: NSWindow? { window }
    public var currentMode: ViewMode = .fullOverlay
    public var isFullScreen: Bool = false
    private var previousModeBeforeFullscreen: ViewMode = .fullOverlay
    
    private override init() {
        super.init()
    }
    
    public func setupFloatingWindow() {
        guard window == nil else { return }
        
        let initialSize = currentMode.windowSize
        let initialRect = NSRect(
            x: 100,
            y: 200,
            width: initialSize.width,
            height: initialSize.height
        )
        
        // Use LyricoraWindow with native titlebar controls for Mission Control and aligned Traffic Lights
        let window = LyricoraWindow(
            contentRect: initialRect,
            styleMask: [
                .titled,
                .closable,
                .miniaturizable,
                .resizable,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )
        
        window.isReleasedWhenClosed = false
        window.delegate = self
        
        // Managed window behavior ensures visibility in Mission Control and proper WindowServer management
        window.collectionBehavior = [.managed, .participatesInCycle, .fullScreenPrimary]
        window.isMovable = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        
        // Center or position on the main screen
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.maxX - initialSize.width - 40
            let y = screenRect.maxY - initialSize.height - 40
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        let contentView = ContentView(
            onModeChange: { [weak self] newMode in
                self?.transition(to: newMode)
            },
            onClose: { [weak self] in
                self?.hideWindow()
            }
        )
        
        window.contentView = NSHostingView(rootView: contentView)
        window.touchBar = TouchBarService.shared.makeTouchBar()
        self.window = window
        
        // Activate app so it appears at front of Command+Tab MRU switcher
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
    
    public func toggleWindow() {
        guard let window = window else {
            setupFloatingWindow()
            return
        }
        
        if window.isVisible {
            window.orderOut(nil)
        } else {
            showWindow()
        }
    }
    
    public func showWindow() {
        guard let window = window else {
            setupFloatingWindow()
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        TouchBarService.shared.updateTouchBarPresence()
    }
    
    public func hideWindow() {
        window?.orderOut(nil)
        TouchBarService.shared.updateTouchBarPresence()
    }
    
    public func transition(to mode: ViewMode) {
        guard let window = window else { return }
        self.currentMode = mode
        
        // If currently in native fullscreen, macOS handles window size
        guard !window.styleMask.contains(.fullScreen) else { return }
        
        let newSize = mode.windowSize
        var newFrame = window.frame
        let oldHeight = newFrame.size.height
        
        newFrame.size = newSize
        // Anchor top-left so window expands downward/inward
        newFrame.origin.y += (oldHeight - newSize.height)
        
        // Native crash-proof frame animation
        window.setFrame(newFrame, display: true, animate: true)
    }
    
    public func toggleFullScreen() {
        window?.toggleFullScreen(nil)
    }
    
    // MARK: - NSWindowDelegate
    public func windowWillEnterFullScreen(_ notification: Notification) {
        isFullScreen = true
        previousModeBeforeFullscreen = currentMode
        currentMode = .ambientCanvas
    }
    
    public func windowDidEnterFullScreen(_ notification: Notification) {
        if let window = window {
            window.touchBar = TouchBarService.shared.makeTouchBar()
        }
        TouchBarService.shared.updateTouchBarPresence()
    }
    
    public func windowDidExitFullScreen(_ notification: Notification) {
        isFullScreen = false
        currentMode = previousModeBeforeFullscreen
        if let window = window {
            window.touchBar = TouchBarService.shared.makeTouchBar()
        }
        TouchBarService.shared.updateTouchBarPresence()
    }
    
    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}
