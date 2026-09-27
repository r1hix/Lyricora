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
    private var previousNonAmbientFrame: NSRect?
    
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
            if currentMode == .ambientCanvas {
                let x = max(screenRect.minX, screenRect.minX + (screenRect.width - initialSize.width) / 2.0)
                let y = max(screenRect.minY, screenRect.minY + (screenRect.height - initialSize.height) / 2.0)
                window.setFrameOrigin(NSPoint(x: x, y: y))
            } else {
                let x = screenRect.maxX - initialSize.width - 40
                let y = screenRect.maxY - initialSize.height - 40
                window.setFrameOrigin(NSPoint(x: x, y: y))
            }
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
        let oldMode = self.currentMode
        self.currentMode = mode
        
        // If currently in native fullscreen, macOS handles window size
        guard !window.styleMask.contains(.fullScreen) else { return }
        
        let newSize = mode.windowSize
        let targetScreen = window.screen ?? NSScreen.main
        let screenRect = targetScreen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        
        var newFrame: NSRect
        
        if mode == .ambientCanvas {
            // Save non-ambient position so we can restore it when returning
            if oldMode != .ambientCanvas {
                previousNonAmbientFrame = window.frame
            }
            // Bring the window to the center of the screen
            let x = max(screenRect.minX, screenRect.minX + (screenRect.width - newSize.width) / 2.0)
            let y = max(screenRect.minY, screenRect.minY + (screenRect.height - newSize.height) / 2.0)
            newFrame = NSRect(
                x: x,
                y: y,
                width: min(newSize.width, screenRect.width),
                height: min(newSize.height, screenRect.height)
            )
        } else if oldMode == .ambientCanvas, let prevFrame = previousNonAmbientFrame, targetScreen?.frame.intersects(prevFrame) == true {
            // Returning from ambient mode on the same display: restore previous non-ambient position
            // Anchor to top-left of previous frame in case target mode size differs from saved frame
            let prevTop = prevFrame.maxY
            let prevLeft = prevFrame.minX
            newFrame = NSRect(
                x: prevLeft,
                y: prevTop - newSize.height,
                width: newSize.width,
                height: newSize.height
            )
        } else {
            let oldHeight = window.frame.size.height
            var frame = window.frame
            frame.size = newSize
            // Anchor top-left so window expands downward/inward
            frame.origin.y += (oldHeight - newSize.height)
            newFrame = frame
        }
        
        // Ensure window remains completely within visible screen bounds
        if newFrame.maxX > screenRect.maxX {
            newFrame.origin.x = screenRect.maxX - newFrame.width
        }
        if newFrame.minX < screenRect.minX {
            newFrame.origin.x = screenRect.minX
        }
        if newFrame.maxY > screenRect.maxY {
            newFrame.origin.y = screenRect.maxY - newFrame.height
        }
        if newFrame.minY < screenRect.minY {
            newFrame.origin.y = screenRect.minY
        }
        
        // Avoid redundant animations if frame is already matching
        if window.frame.equalTo(newFrame) { return }
        
        // Native crash-proof frame animation
        let shouldAnimate = window.isVisible
        window.setFrame(newFrame, display: true, animate: shouldAnimate)
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
