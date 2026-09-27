import SwiftUI

public struct MiniHUDView: View {
    @Bindable var observer: SpotifyObserver
    @Bindable var lyricsService: LyricsService
    var onSwitchMode: ((ViewMode) -> Void)?
    
    @State private var isHovering: Bool = false
    @State private var isScrubbing: Bool = false
    @State private var scrubPosition: TimeInterval = 0.0
    
    public init(
        observer: SpotifyObserver,
        lyricsService: LyricsService,
        onSwitchMode: ((ViewMode) -> Void)? = nil
    ) {
        self.observer = observer
        self.lyricsService = lyricsService
        self.onSwitchMode = onSwitchMode
    }
    
    public var body: some View {
        TimelineView(.animation(paused: !observer.isPlaying && !isHovering)) { _ in
            let currentTime = isScrubbing ? scrubPosition : observer.interpolatedPosition()
            let duration = max(1.0, observer.trackDuration)
            let progress = min(max(0.0, currentTime / duration), 1.0)
            
            let lyrics = lyricsService.currentLyrics
            let activeIndex = lyrics.activeLineIndex(for: currentTime)
            let activeLine = activeIndex.flatMap { lyrics.lines.indices.contains($0) ? lyrics.lines[$0] : nil }
            
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Artwork Thumbnail
                    ZStack {
                        if let art = observer.artworkImage {
                            Image(nsImage: art)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.purple.opacity(0.4), Color.blue.opacity(0.4)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay {
                                    Image(systemName: "music.note")
                                        .font(.system(size: 16))
                                        .foregroundStyle(Color.white.opacity(0.7))
                                }
                        }
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 4, y: 2)
                    
                    // Main Content: Lyrics or Track Info + Controls
                    VStack(alignment: .leading, spacing: 3) {
                        if isHovering {
                            // Hovered: Transport controls & Song Info
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(observer.currentTrack?.title ?? "No Song Playing")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Color.white)
                                        .lineLimit(1)
                                    
                                    Text(observer.currentTrack?.artist ?? "Spotify")
                                        .font(.system(size: 11, weight: .regular, design: .rounded))
                                        .foregroundStyle(Color.white.opacity(0.6))
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                // Transport Buttons
                                HStack(spacing: 12) {
                                    Button(action: { observer.previousTrack() }) {
                                        Image(systemName: "backward.fill")
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color.white.opacity(0.85))
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button(action: { observer.togglePlayPause() }) {
                                        Image(systemName: observer.isPlaying ? "pause.fill" : "play.fill")
                                            .font(.system(size: 16))
                                            .foregroundStyle(Color.white)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button(action: { observer.nextTrack() }) {
                                        Image(systemName: "forward.fill")
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color.white.opacity(0.85))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        } else {
                            // Passive: Active Synchronized Lyric Line
                            let isRTL = activeLine?.isRTL ?? false
                            VStack(alignment: isRTL ? .trailing : .leading, spacing: 2) {
                                if let line = activeLine {
                                    if !line.words.isEmpty {
                                        HStack(spacing: 5) {
                                            ForEach(line.words) { word in
                                                let wProg = word.progress(at: currentTime)
                                                KaraokeWordText(
                                                    text: word.text,
                                                    progress: wProg,
                                                    font: .system(size: 14, weight: .bold, design: .rounded),
                                                    baseColor: Color.white.opacity(0.4),
                                                    highlightColor: .white,
                                                    isGlowEnabled: true,
                                                    isRTL: word.isRTL || isRTL
                                                )
                                            }
                                        }
                                        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
                                    } else {
                                        Text(line.rawText)
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                            .foregroundStyle(Color.white)
                                            .lineLimit(1)
                                            .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
                                            .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
                                    }
                                } else {
                                    Text(observer.currentTrack?.title ?? "Waiting for Spotify...")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Color.white.opacity(0.9))
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
                                }
                                
                                Text(observer.currentTrack?.artist ?? "Connect Spotify")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.white.opacity(0.55))
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    
                    // View Mode Switcher
                    Button(action: { onSwitchMode?(.fullOverlay) }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.6))
                            .padding(6)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .help("Expand to Full Lyrics")
                }
                .padding(.leading, 78)
                .padding(.trailing, 14)
                .padding(.top, 10)
                .padding(.bottom, 6)
                
                // Bottom Interactive Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: isHovering ? 4 : 2)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.8), Color.white],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, geo.size.width * CGFloat(progress)), height: isHovering ? 4 : 2)
                            .shadow(color: Color.white.opacity(0.5), radius: 3)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isScrubbing = true
                                let fraction = min(max(0, value.location.x / geo.size.width), 1.0)
                                scrubPosition = fraction * duration
                            }
                            .onEnded { value in
                                let fraction = min(max(0, value.location.x / geo.size.width), 1.0)
                                let targetTime = fraction * duration
                                observer.seek(to: targetTime)
                                isScrubbing = false
                            }
                    )
                }
                .frame(height: isHovering ? 5 : 2.5)
                .padding(.leading, 78)
                .padding(.trailing, 14)
                .padding(.bottom, 8)
            }
            .frame(width: 480, height: 72)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
                    
                    WindowDragHandle()
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color.black.opacity(0.35), radius: 16, y: 8)
            .onHover { hovering in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isHovering = hovering
                }
            }
        }
    }
}
