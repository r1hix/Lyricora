import SwiftUI
import AppKit
import Observation

@Observable
@MainActor
public final class TouchBarService: NSObject, NSTouchBarDelegate {
    public static let shared = TouchBarService()
    
    private let modeKey = "lyricora.touchbar.lyrics.mode"
    private let systemItemIdentifier = NSTouchBarItem.Identifier("com.lyricora.touchbar.system")
    private let mainItemIdentifier = NSTouchBarItem.Identifier("com.lyricora.touchbar.main")
    
    public var mode: TouchBarLyricsMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: modeKey)
            removeSystemTrayItem()
            updateTouchBarPresence()
        }
    }
    
    private var systemTrayItem: NSCustomTouchBarItem?
    private var currentTouchBar: NSTouchBar?
    private var isModalPresented: Bool = false
    
    // Function signatures for private AppKit and DFRFoundation APIs
    private typealias DFRShowsCloseBoxFunc = @convention(c) (Bool) -> Void
    private typealias DFRElementFunc = @convention(c) (CFString, Bool) -> Void
    private typealias PresentSystemModalFunc = @convention(c) (AnyClass, Selector, NSTouchBar, Int64, NSTouchBarItem.Identifier) -> Void
    private typealias DismissSystemModalFunc = @convention(c) (AnyClass, Selector, NSTouchBar) -> Void
    
    private override init() {
        if let saved = UserDefaults.standard.string(forKey: modeKey),
           let parsed = TouchBarLyricsMode(rawValue: saved) {
            self.mode = parsed
        } else {
            // Default to Word Fill with Shaders for the best interactive experience on Apple Silicon
            self.mode = .wordFill
        }
        super.init()
        
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFocusStateChange),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFocusStateChange),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFocusStateChange),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFocusStateChange),
            name: NSWindow.didResignKeyNotification,
            object: nil
        )
    }
    
    @objc private func handleFocusStateChange() {
        DispatchQueue.main.async { [weak self] in
            self?.updateTouchBarPresence()
        }
    }
    
    public func setMode(_ newMode: TouchBarLyricsMode) {
        self.mode = newMode
    }
    
    public func cycleMode() {
        switch mode {
        case .off:
            setMode(.lineByLine)
        case .lineByLine:
            setMode(.wordFill)
        case .wordFill:
            setMode(.off)
        }
    }
    
    public func setupTouchBar() {
        DispatchQueue.main.async { [weak self] in
            self?.updateTouchBarPresence()
        }
    }
    
    public func makeTouchBar() -> NSTouchBar? {
        guard mode != .off else { return nil }
        
        let touchBar = NSTouchBar()
        touchBar.delegate = self
        touchBar.defaultItemIdentifiers = [mainItemIdentifier]
        self.currentTouchBar = touchBar
        return touchBar
    }
    
    // MARK: - NSTouchBarDelegate
    public func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        if identifier == mainItemIdentifier {
            let item = NSCustomTouchBarItem(identifier: identifier)
            let view = TouchBarLyricsView(
                observer: SpotifyObserver.shared,
                lyricsService: LyricsService.shared,
                mode: mode,
                isCompact: false
            )
            let hostingView = NSHostingView(rootView: view)
            hostingView.setContentHuggingPriority(.defaultLow, for: .horizontal)
            hostingView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            item.view = hostingView
            return item
        }
        return nil
    }
    
    // MARK: - AppKit Control Strip & System Modal Integration
    private func setCloseBoxVisible(_ visible: Bool) {
        let handle = dlopen(nil, RTLD_NOW)
        if let sym = dlsym(handle, "DFRSystemModalShowsCloseBoxWhenFrontMost") {
            let fn = unsafeBitCast(sym, to: DFRShowsCloseBoxFunc.self)
            fn(visible)
        }
    }
    
    private func setControlStripPresence(_ present: Bool) {
        let handle = dlopen(nil, RTLD_NOW)
        if let sym = dlsym(handle, "DFRElementSetControlStripPresenceForIdentifier") {
            let fn = unsafeBitCast(sym, to: DFRElementFunc.self)
            fn(systemItemIdentifier.rawValue as CFString, present)
        }
    }
    
    private func presentModalTouchBar() {
        guard !isModalPresented else { return }
        guard let touchBar = makeTouchBar() else { return }
        
        let sel = NSSelectorFromString("presentSystemModalTouchBar:placement:systemTrayItemIdentifier:")
        if let method = class_getClassMethod(NSTouchBar.self, sel) {
            let imp = method_getImplementation(method)
            let fn = unsafeBitCast(imp, to: PresentSystemModalFunc.self)
            // placement: 1 disables the Control Strip entirely, dedicating 100% of the Touch Bar to lyrics
            fn(NSTouchBar.self, sel, touchBar, 1, systemItemIdentifier)
            self.isModalPresented = true
        }
    }
    
    private func dismissModalTouchBar() {
        guard isModalPresented, let touchBar = currentTouchBar else { return }
        
        let minSel = NSSelectorFromString("minimizeSystemModalTouchBar:")
        let disSel = NSSelectorFromString("dismissSystemModalTouchBar:")
        
        if let mm = class_getClassMethod(NSTouchBar.self, minSel) {
            let fn = unsafeBitCast(method_getImplementation(mm), to: DismissSystemModalFunc.self)
            fn(NSTouchBar.self, minSel, touchBar)
        } else if let dm = class_getClassMethod(NSTouchBar.self, disSel) {
            let fn = unsafeBitCast(method_getImplementation(dm), to: DismissSystemModalFunc.self)
            fn(NSTouchBar.self, disSel, touchBar)
        }
        self.isModalPresented = false
    }
    
    private func ensureSystemTrayItemRegistered() {
        guard systemTrayItem == nil else { return }
        
        let item = NSCustomTouchBarItem(identifier: systemItemIdentifier)
        let compactView = TouchBarLyricsView(
            observer: SpotifyObserver.shared,
            lyricsService: LyricsService.shared,
            mode: mode,
            isCompact: true
        )
        let hostingView = NSHostingView(rootView: compactView)
        hostingView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        hostingView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        item.view = hostingView
        
        let addSel = NSSelectorFromString("addSystemTrayItem:")
        if NSTouchBarItem.responds(to: addSel) {
            NSTouchBarItem.perform(addSel, with: item)
            self.systemTrayItem = item
        }
    }
    
    private func removeSystemTrayItem() {
        if let existing = systemTrayItem {
            let removeSel = NSSelectorFromString("removeSystemTrayItem:")
            if NSTouchBarItem.responds(to: removeSel) {
                NSTouchBarItem.perform(removeSel, with: existing)
            }
            systemTrayItem = nil
        }
    }
    
    public func updateTouchBarPresence() {
        guard mode != .off else {
            dismissModalTouchBar()
            removeSystemTrayItem()
            setControlStripPresence(false)
            WindowManager.shared.window?.touchBar = nil
            return
        }
        
        // Ensure system tray item is registered so macOS has the anchor identifier
        ensureSystemTrayItemRegistered()
        
        let isFocused = NSApp.isActive
        
        if isFocused {
            // Disable the Control Strip on the touchbar entirely when the app is focused in
            setCloseBoxVisible(false)
            presentModalTouchBar()
            setControlStripPresence(false)
        } else {
            // Restore normal Touch Bar for other apps when in background,
            // while keeping our compact lyrics visible in the Control Strip
            dismissModalTouchBar()
            setControlStripPresence(true)
        }
        
        // Update the active window's touchbar
        if let window = WindowManager.shared.window {
            window.touchBar = makeTouchBar()
        }
    }
}
