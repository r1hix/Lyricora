import SwiftUI
import AppKit

@MainActor
public struct TouchBarLyricsView: View {
    @Bindable var observer: SpotifyObserver
    @Bindable var lyricsService: LyricsService
    var mode: TouchBarLyricsMode
    var isCompact: Bool = false
    
    public init(
        observer: SpotifyObserver,
        lyricsService: LyricsService,
        mode: TouchBarLyricsMode,
        isCompact: Bool = false
    ) {
        self.observer = observer
        self.lyricsService = lyricsService
        self.mode = mode
        self.isCompact = isCompact
    }
    
    public init(
        mode: TouchBarLyricsMode,
        isCompact: Bool = false
    ) {
        self.init(
            observer: SpotifyObserver.shared,
            lyricsService: LyricsService.shared,
            mode: mode,
            isCompact: isCompact
        )
    }
    
    public var body: some View {
        HStack(spacing: isCompact ? 6 : 10) {
            // Left: Album Artwork & Track Info (clickable to bring window to front)
            Button(action: { WindowManager.shared.showWindow() }) {
                HStack(spacing: 5) {
                    ZStack {
                        if let art = observer.artworkImage {
                            Image(nsImage: art)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.15))
                                .overlay {
                                    Image(systemName: "music.note")
                                        .font(.system(size: 9))
                                        .foregroundStyle(Color.white.opacity(0.6))
                                }
                        }
                    }
                    .frame(width: isCompact ? 18 : 22, height: isCompact ? 18 : 22)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    
                    if !isCompact {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(observer.currentTrack?.title ?? "Spotify")
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.white)
                                .lineLimit(1)
                            
                            Text(observer.currentTrack?.artist ?? "")
                                .font(.system(size: 8, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.6))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: 80, alignment: .leading)
                    }
                }
            }
            .buttonStyle(.plain)
            
            // Center/Main: Pure Synchronized Lyrics across the entire Touch Bar width!
            centerLyricsView
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 6)
        .frame(minWidth: isCompact ? 640 : 760, idealWidth: isCompact ? 840 : 1000, maxWidth: .infinity, minHeight: 30, maxHeight: 30)
    }
    
    // MARK: - Center Lyrics View
    @ViewBuilder
    private var centerLyricsView: some View {
        let lyrics = lyricsService.currentLyrics
        
        switch mode {
        case .off:
            Text("Touch Bar Lyrics Off")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.35))
                .lineLimit(1)
            
        case .lineByLine:
            // Line-by-Line: Realtime synchronized line updates with auto-scaling to prevent truncation
            TimelineView(.animation(paused: !observer.isPlaying)) { _ in
                let currentTime = observer.interpolatedPosition()
                let activeIndex = lyrics.activeLineIndex(for: currentTime)
                let activeLine = activeIndex.flatMap { lyrics.lines.indices.contains($0) ? lyrics.lines[$0] : nil }
                
                if lyrics.isInstrumental {
                    Text("♪ Instrumental ♪")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.75))
                        .lineLimit(1)
                } else if let line = activeLine {
                    let isRTL = line.isRTL
                    Text(line.rawText)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
                        .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
                } else {
                    Text(observer.currentTrack?.title ?? "Waiting for Spotify...")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
            
        case .wordFill:
            // Word Fill with Shaders: Each word uses fixed horizontal sizing to prevent per-word ellipsis truncation
            TimelineView(.animation(paused: !observer.isPlaying)) { _ in
                let currentTime = observer.interpolatedPosition()
                let activeIndex = lyrics.activeLineIndex(for: currentTime)
                let activeLine = activeIndex.flatMap { lyrics.lines.indices.contains($0) ? lyrics.lines[$0] : nil }
                
                if lyrics.isInstrumental {
                    HStack(spacing: 6) {
                        Image(systemName: "guitars.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.white.opacity(0.8))
                        Text("♪ Instrumental ♪")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.85))
                    }
                } else if let line = activeLine {
                    let isRTL = line.isRTL
                    if !line.words.isEmpty {
                        // Find current active singing word to keep it in view for long lines
                        let activeWordId = line.words.first(where: { word in
                            let p = word.progress(at: currentTime)
                            return p > 0.0 && p < 1.0
                        })?.id ?? line.words.last(where: { $0.progress(at: currentTime) >= 1.0 })?.id ?? line.words.first?.id
                        
                        ScrollViewReader { scrollProxy in
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 5) {
                                    ForEach(line.words) { word in
                                        let prog = word.progress(at: currentTime)
                                        KaraokeWordText(
                                            text: word.text,
                                            progress: prog,
                                            font: .system(size: 12.5, weight: .bold, design: .rounded),
                                            baseColor: Color.white.opacity(0.38),
                                            highlightColor: .white,
                                            isGlowEnabled: true,
                                            isRTL: word.isRTL || isRTL
                                        )
                                        // Essential: Prevent SwiftUI from truncating each word individually with an ellipsis
                                        .fixedSize(horizontal: true, vertical: false)
                                        .id(word.id)
                                    }
                                }
                                .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
                                .padding(isRTL ? .leading : .trailing, 16)
                            }
                            .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
                            .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
                            .onChange(of: activeWordId) { _, targetId in
                                if let id = targetId {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        scrollProxy.scrollTo(id, anchor: .center)
                                    }
                                }
                            }
                        }
                    } else {
                        Text(line.rawText)
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
                            .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
                    }
                } else {
                    Text(observer.currentTrack?.title ?? "Waiting for Spotify...")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
        }
    }
}
