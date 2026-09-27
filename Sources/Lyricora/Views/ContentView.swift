import SwiftUI

public struct ContentView: View {
    @State private var observer = SpotifyObserver.shared
    @State private var lyricsService = LyricsService.shared
    @State private var windowManager = WindowManager.shared
    @State private var touchBarService = TouchBarService.shared
    
    var onModeChange: ((ViewMode) -> Void)?
    var onClose: (() -> Void)?
    
    public init(
        initialMode: ViewMode = .fullOverlay,
        onModeChange: ((ViewMode) -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.onModeChange = onModeChange
        self.onClose = onClose
    }
    
    private var currentMode: ViewMode {
        windowManager.currentMode
    }
    
    public var body: some View {
        ZStack {
            switch currentMode {
            case .miniHUD:
                MiniHUDView(
                    observer: observer,
                    lyricsService: lyricsService,
                    onSwitchMode: switchMode
                )
                
            case .fullOverlay:
                fullOverlayView
                
            case .ambientCanvas:
                AmbientCanvasView(
                    observer: observer,
                    lyricsService: lyricsService,
                    onSwitchMode: switchMode,
                    onClose: onClose
                )
            }
        }
        .frame(
            minWidth: currentMode == .miniHUD ? currentMode.windowSize.width : 380,
            maxWidth: currentMode == .miniHUD ? currentMode.windowSize.width : .infinity,
            minHeight: currentMode == .miniHUD ? currentMode.windowSize.height : 450,
            maxHeight: currentMode == .miniHUD ? currentMode.windowSize.height : .infinity
        )
        .clipShape(RoundedRectangle(cornerRadius: windowManager.isFullScreen ? 0 : 20, style: .continuous))
        .ignoresSafeArea()
        .background {
            // Global Spacebar Play/Pause trigger
            Button(action: {
                observer.togglePlayPause()
            }) {
                EmptyView()
            }
            .keyboardShortcut(.space, modifiers: [])
            .opacity(0)
            .allowsHitTesting(false)
        }
        .onChange(of: observer.currentTrack) { _, newTrack in
            if let track = newTrack {
                lyricsService.loadLyrics(for: track)
            }
        }
        .onAppear {
            if let track = observer.currentTrack {
                lyricsService.loadLyrics(for: track)
            }
        }
        .touchBar {
            if touchBarService.mode != .off {
                TouchBarLyricsView(
                    observer: observer,
                    lyricsService: lyricsService,
                    mode: touchBarService.mode
                )
            }
        }
    }
    
    // MARK: - Mode 2: Full Lyrics Overlay View
    private var fullOverlayView: some View {
        ZStack {
            // Subtle ambient backdrop
            AmbientBackdropView(image: observer.artworkImage, isPlaying: observer.isPlaying)
                .opacity(0.85)
            
            // Ultra-thin glass material overlay
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Glass Header with Artwork & Controls (padded on leading side for macOS traffic lights)
                headerView
                
                Divider()
                    .overlay(Color.white.opacity(0.12))
                
                // Scrolling Lyrics View
                LyricsView(
                    observer: observer,
                    lyricsService: lyricsService,
                    onSeek: { targetTime in
                        observer.seek(to: targetTime)
                    }
                )
                
                // Bottom Floating Glass Transport Controls
                bottomScrubberBar
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1.0)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 24, y: 12)
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 12) {
            // Album Art Thumbnail
            ZStack {
                if let art = observer.artworkImage {
                    Image(nsImage: art)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.white.opacity(0.5))
                        }
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: Color.black.opacity(0.2), radius: 4)
            
            // Song Title & Artist
            VStack(alignment: .leading, spacing: 2) {
                Text(observer.currentTrack?.title ?? "Waiting for Spotify...")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                
                Text(observer.currentTrack?.artist ?? "Connect or play a song in Spotify")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Right Control Cluster: Screen Awake quick toggle + View Mode Segment
            HStack(spacing: 8) {
                // Screen Awake Quick Toggle Button
                Button(action: { SleepPreventerService.shared.toggleScreenAwake() }) {
                    Image(systemName: SleepPreventerService.shared.isScreenAwakeEnabled ? "sun.max.fill" : "sun.min")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(SleepPreventerService.shared.isScreenAwakeEnabled ? Color.yellow : Color.white.opacity(0.45))
                        .padding(6)
                        .background(
                            Circle()
                                .fill(SleepPreventerService.shared.isScreenAwakeEnabled ? Color.yellow.opacity(0.2) : Color.white.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
                .help(SleepPreventerService.shared.isScreenAwakeEnabled ? "Screen Awake: ON" : "Screen Awake: OFF")
                
                // View Mode Selector Segment
                HStack(spacing: 4) {
                    ForEach(ViewMode.allCases) { mode in
                        Button(action: { switchMode(mode) }) {
                            Image(systemName: mode.iconName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(currentMode == mode ? Color.white : Color.white.opacity(0.5))
                                .padding(6)
                                .background(
                                    Circle()
                                        .fill(currentMode == mode ? Color.white.opacity(0.2) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                        .help(mode.rawValue)
                    }
                }
                .padding(4)
                .background(Capsule().fill(Color.white.opacity(0.08)))
            }
        }
        // Padded on leading edge to make space for native macOS traffic light buttons (Close, Minimize, Zoom)
        .padding(.leading, 78)
        .padding(.trailing, 18)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(
            ZStack {
                Color.black.opacity(0.18)
                WindowDragHandle()
            }
        )
    }
    
    // MARK: - Bottom Scrubber & Mini Transport
    private var bottomScrubberBar: some View {
        TimelineView(.animation(paused: !observer.isPlaying)) { _ in
            let currentTime = observer.interpolatedPosition()
            let duration = max(1.0, observer.trackDuration)
            let fraction = min(max(0.0, currentTime / duration), 1.0)
            
            HStack(spacing: 16) {
                // Elapsed Time
                Text(formatDuration(currentTime))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .frame(width: 36, alignment: .trailing)
                
                // Scrubber Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 3)
                        
                        Capsule()
                            .fill(Color.white.opacity(0.85))
                            .frame(width: max(0, geo.size.width * CGFloat(fraction)), height: 3)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                let f = min(max(0, value.location.x / geo.size.width), 1.0)
                                observer.seek(to: f * duration)
                            }
                    )
                }
                .frame(height: 10)
                
                // Transport Buttons
                HStack(spacing: 12) {
                    Button(action: { observer.previousTrack() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { observer.togglePlayPause() }) {
                        Image(systemName: observer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.white)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { observer.nextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.25))
        }
    }
    
    private func switchMode(_ mode: ViewMode) {
        windowManager.transition(to: mode)
        onModeChange?(mode)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
