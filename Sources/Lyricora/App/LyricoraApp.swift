import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as a regular application visible in Cmd+Tab / Alt+Tab and Dock
        NSApp.setActivationPolicy(.regular)
        WindowManager.shared.setupFloatingWindow()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        WindowManager.shared.showWindow()
        return true
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        WindowManager.shared.showWindow()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        SleepPreventerService.shared.disableScreenAwake()
    }
}

@main
struct LyricoraApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var observer = SpotifyObserver.shared
    @State private var touchBarService = TouchBarService.shared
    @State private var sleepService = SleepPreventerService.shared
    
    var body: some Scene {
        MenuBarExtra {
            menuBarContent
        } label: {
            HStack(spacing: 4) {
                Image(systemName: observer.isPlaying ? "music.quarternote.3" : "music.note")
                if sleepService.isScreenAwakeEnabled {
                    Image(systemName: "sun.max.fill")
                }
                if let track = observer.currentTrack {
                    Text(track.title)
                        .font(.system(size: 12, design: .rounded))
                        .lineLimit(1)
                }
            }
        }
    }
    
    @ViewBuilder
    private var menuBarContent: some View {
        if let track = observer.currentTrack {
            Section {
                Text(track.title)
                    .font(.headline)
                Text(track.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            Section("Playback") {
                Button(action: { observer.togglePlayPause() }) {
                    Label(
                        observer.isPlaying ? "Pause" : "Play",
                        systemImage: observer.isPlaying ? "pause.fill" : "play.fill"
                    )
                }
                
                Button(action: { observer.nextTrack() }) {
                    Label("Next Track", systemImage: "forward.fill")
                }
                
                Button(action: { observer.previousTrack() }) {
                    Label("Previous Track", systemImage: "backward.fill")
                }
            }
            
            Divider()
        }
        
        Section("Overlay Mode") {
            ForEach(ViewMode.allCases) { mode in
                Button(action: { WindowManager.shared.transition(to: mode) }) {
                    let isCurrent = WindowManager.shared.currentMode == mode
                    Label(
                        isCurrent ? "\(mode.rawValue)  ✓" : mode.rawValue,
                        systemImage: mode.iconName
                    )
                }
            }
        }
        
        Divider()
        
        Section("Touch Bar Lyrics") {
            ForEach(TouchBarLyricsMode.allCases) { mode in
                Button(action: { touchBarService.setMode(mode) }) {
                    let isCurrent = touchBarService.mode == mode
                    Label(
                        isCurrent ? "\(mode.rawValue)  ✓" : mode.rawValue,
                        systemImage: mode.iconName
                    )
                }
            }
        }
        
        Divider()
        
        Section("Power & Display") {
            Toggle(
                sleepService.isScreenAwakeEnabled ? "Keep Screen Awake: ON" : "Keep Screen Awake: OFF",
                isOn: Binding(
                    get: { sleepService.isScreenAwakeEnabled },
                    set: { _ in sleepService.toggleScreenAwake() }
                )
            )
        }
        
        Divider()
        
        Button(action: { WindowManager.shared.toggleWindow() }) {
            Label(
                (WindowManager.shared.panel?.isVisible ?? false) ? "Hide Overlay" : "Show Overlay",
                systemImage: "macwindow"
            )
        }
        
        Divider()
        
        Button("Quit Lyricora") {
            SleepPreventerService.shared.disableScreenAwake()
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
