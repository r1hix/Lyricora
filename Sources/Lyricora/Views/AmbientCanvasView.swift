import SwiftUI
import AppKit

public struct AmbientCanvasView: View {
    @Bindable var observer: SpotifyObserver
    @Bindable var lyricsService: LyricsService
    var onSwitchMode: ((ViewMode) -> Void)?
    var onClose: (() -> Void)?
    
    @State private var showControls: Bool = false
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var isScrubbing: Bool = false
    @State private var scrubPosition: TimeInterval = 0.0
    @State private var albumBreatheScale: CGFloat = 1.0
    @State private var mouseMonitor: Any?
    
    public init(
        observer: SpotifyObserver,
        lyricsService: LyricsService,
        onSwitchMode: ((ViewMode) -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.observer = observer
        self.lyricsService = lyricsService
        self.onSwitchMode = onSwitchMode
        self.onClose = onClose
    }
    
    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let isLarge = size.width > 950 || size.height > 750 || WindowManager.shared.isFullScreen
            
            // Responsive sizing parameters to fill the canvas beautifully without overflow
            let artSize: CGFloat = isLarge ? min(size.height * 0.44, 420.0) : 260.0
            
            TimelineView(.animation(paused: !observer.isPlaying && !showControls)) { _ in
                let currentTime = isScrubbing ? scrubPosition : observer.interpolatedPosition()
                let duration = max(1.0, observer.trackDuration)
                let lyrics = lyricsService.currentLyrics
                let activeIndex = lyrics.activeLineIndex(for: currentTime)
                let activeLine: LyricLine? = activeIndex.flatMap { lyrics.lines.indices.contains($0) ? lyrics.lines[$0] : nil }
                
                // Adaptive typography: scale active line based on screen dimensions and character length
                let rawLength = activeLine?.rawText.count ?? 0
                let isLongActive = rawLength > 55
                
                let baseActiveSize: CGFloat = isLarge ? min(max(56.0, size.height * 0.075), 74.0) : 34.0
                let activeFontSize: CGFloat = {
                    guard isLarge else { return 34.0 }
                    if rawLength <= 24 { return baseActiveSize }
                    if rawLength <= 45 { return baseActiveSize * 0.88 }
                    if rawLength <= 70 { return baseActiveSize * 0.76 }
                    return baseActiveSize * 0.65
                }()
                
                let previewFontSize: CGFloat = isLarge ? min(max(30.0, size.width * 0.024), 38.0) : 22.0
                let subPreviewFontSize: CGFloat = isLarge ? min(max(24.0, size.width * 0.018), 28.0) : 17.0
                let contextFontSize: CGFloat = isLarge ? min(max(19.0, size.width * 0.015), 22.0) : 15.0
                
                // Retrieve non-empty surrounding lines (prevents empty gaps between verses)
                let surrounding = lyrics.surroundingLines(
                    for: activeIndex,
                    before: isLongActive ? 1 : 2,
                    after: isLongActive ? 2 : 3
                )
                let pastLines = surrounding.past
                let nextLines = surrounding.next
                
                ZStack {
                    // Layer 1: Ambient Mesh Backdrop
                    AmbientBackdropView(image: observer.artworkImage, isPlaying: observer.isPlaying)
                    
                    // Layer 2: Main Layout (Top Chrome with Traffic Light clearance + Centered Stage)
                    VStack(spacing: 0) {
                        // Top Bar: Safe clearance for native macOS traffic lights (x: 9..69) on left, controls on right
                        HStack(alignment: .center) {
                            Spacer()
                                .frame(width: 80)
                            
                            Spacer()
                            
                            // Mode Switcher & Quick Toggles
                            HStack(spacing: 8) {
                                // Keep Screen Awake Toggle
                                Button(action: { SleepPreventerService.shared.toggleScreenAwake() }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: SleepPreventerService.shared.isScreenAwakeEnabled ? "sun.max.fill" : "sun.min")
                                            .font(.system(size: 11, weight: .medium))
                                        Text(SleepPreventerService.shared.isScreenAwakeEnabled ? "Awake: ON" : "Awake: OFF")
                                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                    }
                                    .foregroundStyle(SleepPreventerService.shared.isScreenAwakeEnabled ? Color.yellow : Color.white.opacity(0.6))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .help(SleepPreventerService.shared.isScreenAwakeEnabled ? "Screen Awake: ON" : "Screen Awake: OFF")
                                
                                Button(action: { onSwitchMode?(.miniHUD) }) {
                                    Image(systemName: "capsule")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.85))
                                        .padding(8)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .help("Switch to Mini HUD")
                                
                                Button(action: { onSwitchMode?(.fullOverlay) }) {
                                    Image(systemName: "quote.bubble.fill")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.85))
                                        .padding(8)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .help("Switch to Full Lyrics")
                                
                                Button(action: { WindowManager.shared.toggleFullScreen() }) {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color.white.opacity(0.85))
                                        .padding(8)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .help("Toggle Fullscreen")
                            }
                        }
                        .padding(.horizontal, isLarge ? 48 : 28)
                        .padding(.top, 16)
                        .padding(.bottom, isLarge ? 12 : 6)
                        
                        Spacer(minLength: 0)
                        
                        // Main Stage: Left Column Artwork & Right Column Living Lyrics Stream
                        HStack(spacing: isLarge ? 72 : 44) {
                            // Left Column: Album Artwork & Metadata
                            VStack(alignment: .leading, spacing: 20) {
                                ZStack {
                                    if let art = observer.artworkImage {
                                        Image(nsImage: art)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } else {
                                        RoundedRectangle(cornerRadius: 24)
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color.purple.opacity(0.5), Color.indigo.opacity(0.6)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .overlay {
                                                Image(systemName: "music.note")
                                                    .font(.system(size: isLarge ? 84 : 54))
                                                    .foregroundStyle(Color.white.opacity(0.6))
                                            }
                                    }
                                }
                                .frame(width: artSize, height: artSize)
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1.0)
                                )
                                .scaleEffect(albumBreatheScale)
                                .shadow(color: Color.black.opacity(0.55), radius: 36, y: 18)
                                
                                // Track Title, Artist, Album metadata
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(observer.currentTrack?.title ?? "No Song Playing")
                                        .font(.system(size: isLarge ? 26 : 20, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color.white)
                                        .lineLimit(2)
                                    
                                    Text(observer.currentTrack?.artist ?? "Spotify")
                                        .font(.system(size: isLarge ? 18 : 15, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color.white.opacity(0.72))
                                        .lineLimit(1)
                                    
                                    if let album = observer.currentTrack?.album, !album.isEmpty {
                                        Text(album)
                                            .font(.system(size: isLarge ? 14 : 12, weight: .regular, design: .rounded))
                                            .foregroundStyle(Color.white.opacity(0.45))
                                            .lineLimit(1)
                                    }
                                }
                                .frame(maxWidth: artSize, alignment: .leading)
                            }
                            .frame(width: artSize)
                            
                            // Right Column: Multi-Line Living Karaoke Lyrics Stream
                                let isRTL = activeLine?.isRTL ?? lyrics.isRTL
                                VStack(alignment: isRTL ? .trailing : .leading, spacing: 0) {
                                Spacer(minLength: 0)
                                
                                if lyrics.isInstrumental {
                                    VStack(alignment: .leading, spacing: 14) {
                                        HStack(spacing: 14) {
                                            Image(systemName: "guitars.fill")
                                                .font(.system(size: isLarge ? 46 : 32))
                                                .foregroundStyle(Color.white.opacity(0.85))
                                            Text("♪ Instrumental ♪")
                                                .font(.system(size: isLarge ? 48 : 34, weight: .bold, design: .rounded))
                                                .foregroundStyle(Color.white.opacity(0.9))
                                        }
                                        Text("Enjoy the music")
                                            .font(.system(size: isLarge ? 22 : 16, weight: .medium, design: .rounded))
                                            .foregroundStyle(Color.white.opacity(0.45))
                                    }
                                } else if let line = activeLine {
                                    let lineIsRTL = line.isRTL
                                    VStack(alignment: lineIsRTL ? .trailing : .leading, spacing: isLarge ? 22 : 16) {
                                        // 1. Past Lines (dimmed, floating upward with subtle blur)
                                        ForEach(Array(pastLines.enumerated()), id: \.element.id) { index, pastLine in
                                            let isOldest = pastLines.count > 1 && index == 0
                                            Text(pastLine.rawText)
                                                .font(.system(size: isOldest ? contextFontSize : subPreviewFontSize, weight: .medium, design: .rounded))
                                                .foregroundStyle(Color.white.opacity(isOldest ? 0.20 : 0.35))
                                                .blur(radius: isOldest ? 1.0 : 0.5)
                                                .lineLimit(2)
                                                .multilineTextAlignment(lineIsRTL ? .trailing : .leading)
                                                .frame(maxWidth: .infinity, alignment: lineIsRTL ? .trailing : .leading)
                                                .transition(.opacity.combined(with: .offset(y: -10)))
                                        }
                                        
                                        // 2. Active Singing Line with Carousel vertical slide and blur exit transition
                                        ZStack(alignment: lineIsRTL ? .trailing : .leading) {
                                            if !line.words.isEmpty {
                                                FlowLayout(spacing: isLarge ? 14 : 10, isRTL: lineIsRTL) {
                                                    ForEach(line.words) { word in
                                                        let prog = word.progress(at: currentTime)
                                                        KaraokeWordText(
                                                            text: word.text,
                                                            progress: prog,
                                                            font: .system(size: activeFontSize, weight: .bold, design: .rounded),
                                                            baseColor: Color.white.opacity(0.35),
                                                            highlightColor: .white,
                                                            isGlowEnabled: true,
                                                            isRTL: word.isRTL || lineIsRTL
                                                        )
                                                    }
                                                }
                                            } else {
                                                Text(line.rawText)
                                                    .font(.system(size: activeFontSize, weight: .bold, design: .rounded))
                                                    .foregroundStyle(Color.white)
                                                    .multilineTextAlignment(lineIsRTL ? .trailing : .leading)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: lineIsRTL ? .trailing : .leading)
                                        .id(line.id)
                                        .transition(
                                            .asymmetric(
                                                insertion: .offset(y: 35)
                                                    .combined(with: .opacity)
                                                    .combined(with: .scale(scale: 0.96)),
                                                removal: .offset(y: -35)
                                                    .combined(with: .opacity)
                                                    .combined(with: .blur(radius: 12))
                                            )
                                        )
                                        
                                        // 3. Upcoming Lines (preview with staggered hierarchy)
                                        ForEach(Array(nextLines.enumerated()), id: \.element.id) { index, nextLine in
                                            let (fSize, opacity, weight): (CGFloat, Double, Font.Weight) = {
                                                switch index {
                                                case 0:
                                                    return (previewFontSize, 0.55, .semibold)
                                                case 1:
                                                    return (subPreviewFontSize, 0.35, .medium)
                                                default:
                                                    return (contextFontSize, 0.20, .regular)
                                                }
                                            }()
                                            
                                            Text(nextLine.rawText)
                                                .font(.system(size: fSize, weight: weight, design: .rounded))
                                                .foregroundStyle(Color.white.opacity(opacity))
                                                .lineLimit(2)
                                                .multilineTextAlignment(lineIsRTL ? .trailing : .leading)
                                                .frame(maxWidth: .infinity, alignment: lineIsRTL ? .trailing : .leading)
                                                .transition(.opacity)
                                        }
                                    }
                                    .animation(.spring(response: 0.55, dampingFraction: 0.8), value: activeLine?.id)
                                } else {
                                    Text(observer.currentTrack?.title ?? "Waiting for Spotify...")
                                        .font(.system(size: isLarge ? 48 : 34, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color.white.opacity(0.75))
                                }
                                
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
                            .padding(isRTL ? .leading : .trailing, isLarge ? 60 : 20)
                        }
                        .padding(.horizontal, isLarge ? 80 : 44)
                        .padding(.bottom, isLarge ? 28 : 16)
                        
                        Spacer(minLength: 0)
                    }
                    
                    // Layer 3: Floating Bottom Transport Controls (revealed on mouse hover/movement)
                    VStack {
                        Spacer()
                        if showControls {
                            bottomTransportBar(currentTime: currentTime, duration: duration, isLarge: isLarge)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }
                .background(WindowDragHandle())
                .onAppear {
                    startBreathingAnimation()
                    setupMouseMonitor()
                }
                .onDisappear {
                    removeMouseMonitor()
                }
                .onChange(of: observer.isPlaying) { _, isPlaying in
                    if isPlaying {
                        startBreathingAnimation()
                    }
                }
            }
        }
    }
    
    // MARK: - Mouse Movement Monitor
    private func setupMouseMonitor() {
        removeMouseMonitor()
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown]) { event in
            triggerControlsVisibility()
            return event
        }
    }
    
    private func removeMouseMonitor() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
    }
    
    // MARK: - Breathing Album Cover Animation
    private func startBreathingAnimation() {
        guard observer.isPlaying else {
            withAnimation(.easeOut(duration: 0.6)) {
                albumBreatheScale = 1.0
            }
            return
        }
        withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true)) {
            albumBreatheScale = 1.035
        }
    }
    
    // MARK: - Bottom Transport Bar
    private func bottomTransportBar(currentTime: TimeInterval, duration: TimeInterval, isLarge: Bool) -> some View {
        VStack(spacing: 12) {
            // Interactive Scrubber Slider
            HStack(spacing: 12) {
                Text(formatDuration(currentTime))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .frame(width: 48, alignment: .trailing)
                
                GeometryReader { geo in
                    let fraction = min(max(0.0, currentTime / max(1.0, duration)), 1.0)
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.18))
                            .frame(height: 5)
                        
                        Capsule()
                            .fill(Color.white)
                            .frame(width: max(0, geo.size.width * CGFloat(fraction)), height: 5)
                            .shadow(color: Color.white.opacity(0.6), radius: 6)
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 14, height: 14)
                            .shadow(color: Color.black.opacity(0.3), radius: 4)
                            .offset(x: max(0, min(geo.size.width * CGFloat(fraction) - 7, geo.size.width - 14)))
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isScrubbing = true
                                let f = min(max(0, value.location.x / geo.size.width), 1.0)
                                scrubPosition = f * duration
                                triggerControlsVisibility()
                            }
                            .onEnded { value in
                                let f = min(max(0, value.location.x / geo.size.width), 1.0)
                                observer.seek(to: f * duration)
                                isScrubbing = false
                                triggerControlsVisibility()
                            }
                    )
                }
                .frame(height: 14)
                
                Text("-" + formatDuration(max(0, duration - currentTime)))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .frame(width: 48, alignment: .leading)
            }
            .frame(maxWidth: isLarge ? 680 : 540)
            
            // Transport Action Buttons
            HStack(spacing: 32) {
                Button(action: { observer.previousTrack(); triggerControlsVisibility() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
                .buttonStyle(.plain)
                
                Button(action: { observer.togglePlayPause(); triggerControlsVisibility() }) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 52, height: 52)
                            .shadow(color: Color.white.opacity(0.35), radius: 12)
                        
                        Image(systemName: observer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color.black)
                    }
                }
                .buttonStyle(.plain)
                
                Button(action: { observer.nextTrack(); triggerControlsVisibility() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.4), radius: 24, y: 12)
        .padding(.bottom, isLarge ? 36 : 24)
    }
    
    private func triggerControlsVisibility() {
        if !showControls {
            withAnimation(.easeOut(duration: 0.25)) {
                showControls = true
            }
        }
        hideControlsTask?.cancel()
        hideControlsTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.5)) {
                showControls = false
            }
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Carousel Blur Transition Modifier
struct BlurTransitionModifier: ViewModifier {
    let radius: CGFloat
    
    func body(content: Content) -> some View {
        content.blur(radius: radius)
    }
}

extension AnyTransition {
    static func blur(radius: CGFloat) -> AnyTransition {
        .modifier(
            active: BlurTransitionModifier(radius: radius),
            identity: BlurTransitionModifier(radius: 0)
        )
    }
}
