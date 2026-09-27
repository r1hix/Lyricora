import SwiftUI

public struct LyricsView: View {
    @Bindable var observer: SpotifyObserver
    @Bindable var lyricsService: LyricsService
    
    var onSeek: ((TimeInterval) -> Void)?
    
    @State private var hoveredLineId: UUID?
    @State private var userIsScrolling: Bool = false
    @State private var autoScrollTask: Task<Void, Never>?
    
    public init(
        observer: SpotifyObserver,
        lyricsService: LyricsService,
        onSeek: ((TimeInterval) -> Void)? = nil
    ) {
        self.observer = observer
        self.lyricsService = lyricsService
        self.onSeek = onSeek
    }
    
    public var body: some View {
        TimelineView(.animation(paused: !observer.isPlaying)) { timeline in
            let currentTime = observer.interpolatedPosition()
            let lyrics = lyricsService.currentLyrics
            let activeIndex = lyrics.activeLineIndex(for: currentTime)
            let activeLine = activeIndex.flatMap { lyrics.lines.indices.contains($0) ? lyrics.lines[$0] : nil }
            
            Group {
                if lyricsService.isLoading {
                    loadingView
                } else if lyrics.isInstrumental {
                    instrumentalView(currentTime: currentTime)
                } else if !lyrics.lines.isEmpty {
                    lyricsScrollView(
                        lines: lyrics.lines,
                        activeLine: activeLine,
                        currentTime: currentTime,
                        isRTL: lyrics.isRTL
                    )
                } else if let plain = lyrics.plainLyrics, !plain.isEmpty {
                    plainLyricsView(plain: plain)
                } else {
                    emptyStateView
                }
            }
        }
    }
    
    // MARK: - Scrolling Synchronized Lyrics
    @ViewBuilder
    private func lyricsScrollView(
        lines: [LyricLine],
        activeLine: LyricLine?,
        currentTime: TimeInterval,
        isRTL: Bool
    ) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: isRTL ? .trailing : .leading, spacing: 22) {
                    // Top padding for smooth vertical centering
                    Color.clear.frame(height: 120)
                    
                    ForEach(lines) { line in
                        let isActive = line.id == activeLine?.id
                        let isPast = line.isPast(at: currentTime)
                        let isHovered = hoveredLineId == line.id
                        
                        LyricLineRow(
                            line: line,
                            isActive: isActive,
                            isPast: isPast,
                            isHovered: isHovered,
                            currentTime: currentTime
                        )
                        .id(line.id)
                        .contentShape(Rectangle())
                        .onHover { isHovering in
                            hoveredLineId = isHovering ? line.id : nil
                        }
                        .onTapGesture {
                            onSeek?(line.startTime)
                        }
                    }
                    
                    // Bottom padding
                    Color.clear.frame(height: 200)
                }
                .padding(.horizontal, 28)
            }
            .onChange(of: activeLine?.id) { _, newActiveId in
                guard let newId = newActiveId, !userIsScrolling else { return }
                withAnimation(.smooth(duration: 0.65)) {
                    proxy.scrollTo(newId, anchor: .center)
                }
            }
        }
    }
    
    // MARK: - Lyric Line Row
    private struct LyricLineRow: View {
        let line: LyricLine
        let isActive: Bool
        let isPast: Bool
        let isHovered: Bool
        let currentTime: TimeInterval
        
        var body: some View {
            let isRTL = line.isRTL
            HStack(spacing: 8) {
                // Time indicator on hover (left side for LTR)
                if !isRTL && isHovered {
                    timeIndicator
                }
                
                // Words rendering
                if isActive && !line.words.isEmpty {
                    // Active line: word-by-word reveal
                    WrappingWordView(words: line.words, currentTime: currentTime, isRTL: isRTL)
                } else {
                    // Inactive / past / upcoming line
                    Text(line.rawText)
                        .font(.system(size: isActive ? 26 : 22, weight: isActive ? .bold : .medium, design: .rounded))
                        .foregroundStyle(
                            isPast
                                ? Color.white.opacity(0.35)
                                : (isActive ? Color.white : Color.white.opacity(0.65))
                        )
                        .multilineTextAlignment(isRTL ? .trailing : .leading)
                        .blur(radius: (isPast && !isHovered) ? 0.3 : 0)
                }
                
                // Time indicator on hover (right side for RTL)
                if isRTL && isHovered {
                    timeIndicator
                }
            }
            .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
            .scaleEffect(isActive ? 1.04 : 1.0, anchor: isRTL ? .trailing : .leading)
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isActive)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.white.opacity(0.08) : Color.clear)
            )
        }
        
        private var timeIndicator: some View {
            Text(formatTime(line.startTime))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.5))
                .frame(width: 44, alignment: line.isRTL ? .trailing : .leading)
                .transition(.opacity)
        }
        
        private func formatTime(_ seconds: TimeInterval) -> String {
            let mins = Int(seconds) / 60
            let secs = Int(seconds) % 60
            return String(format: "%d:%02d", mins, secs)
        }
    }
    
    // MARK: - Wrapping Word View for Word-Level Karaoke Reveal
    private struct WrappingWordView: View {
        let words: [LyricWord]
        let currentTime: TimeInterval
        var isRTL: Bool = false
        
        var body: some View {
            // Using Flow-like wrap with bidirectional support
            FlowLayout(spacing: 7, isRTL: isRTL) {
                ForEach(words) { word in
                    let prog = word.progress(at: currentTime)
                    KaraokeWordText(
                        text: word.text,
                        progress: prog,
                        font: .system(size: 26, weight: .bold, design: .rounded),
                        baseColor: Color.white.opacity(0.38),
                        highlightColor: .white,
                        isGlowEnabled: true,
                        isRTL: word.isRTL || isRTL
                    )
                }
            }
        }
    }
    
    // MARK: - Instrumental View
    private func instrumentalView(currentTime: TimeInterval) -> some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Glowing pulsing musical note icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 80, height: 80)
                    .scaleEffect(observer.isPlaying ? 1.08 + sin(currentTime * 2.5) * 0.08 : 1.0)
                
                Image(systemName: "guitars.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.white.opacity(0.4), radius: 10)
            }
            
            Text("♪ Instrumental ♪")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.85))
            
            Text("Enjoy the music")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.45))
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Plain Lyrics View
    private func plainLyricsView(plain: String) -> some View {
        let isRTL = plain.isRightToLeft
        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: isRTL ? .trailing : .leading, spacing: 14) {
                Color.clear.frame(height: 60)
                Text(plain)
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .lineSpacing(8)
                    .multilineTextAlignment(isRTL ? .trailing : .leading)
                    .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
                Color.clear.frame(height: 100)
            }
            .padding(.horizontal, 32)
        }
    }
    
    // MARK: - Loading & Empty States
    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .scaleEffect(0.9)
                .colorInvert()
            Text("Fetching lyrics...")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(Color.white.opacity(0.3))
            Text("No Synchronized Lyrics")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.7))
            Text("Play a song in Spotify to sync lyrics")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Lightweight Modern FlowLayout with BiDirectional Support
public struct FlowLayout: Layout {
    public var spacing: CGFloat
    public var isRTL: Bool
    
    public init(spacing: CGFloat = 8, isRTL: Bool = false) {
        self.spacing = spacing
        self.isRTL = isRTL
    }
    
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalMaxWidth: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalMaxWidth = max(totalMaxWidth, currentX - spacing)
        }
        
        return CGSize(width: min(totalMaxWidth, maxWidth), height: currentY + lineHeight)
    }
    
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        // Group subviews into rows according to bounds.width
        var rows: [[(subview: LayoutSubview, size: CGSize)]] = []
        var currentRow: [(subview: LayoutSubview, size: CGSize)] = []
        var currentRowWidth: CGFloat = 0
        let availableWidth = bounds.width
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let itemWidthWithSpacing = currentRow.isEmpty ? size.width : (spacing + size.width)
            
            if !currentRow.isEmpty && (currentRowWidth + itemWidthWithSpacing > availableWidth) {
                rows.append(currentRow)
                currentRow = [(subview: subview, size: size)]
                currentRowWidth = size.width
            } else {
                currentRow.append((subview: subview, size: size))
                currentRowWidth += itemWidthWithSpacing
            }
        }
        if !currentRow.isEmpty {
            rows.append(currentRow)
        }
        
        var currentY: CGFloat = bounds.minY
        for row in rows {
            let rowHeight = row.map { $0.size.height }.max() ?? 0
            if isRTL {
                // In Right-to-Left, place items starting from the right edge moving leftwards
                var currentX = bounds.maxX
                for item in row {
                    currentX -= item.size.width
                    item.subview.place(
                        at: CGPoint(x: currentX, y: currentY),
                        proposal: ProposedViewSize(width: item.size.width, height: item.size.height)
                    )
                    currentX -= spacing
                }
            } else {
                // In Left-to-Right, place items starting from the left edge moving rightwards
                var currentX = bounds.minX
                for item in row {
                    item.subview.place(
                        at: CGPoint(x: currentX, y: currentY),
                        proposal: ProposedViewSize(width: item.size.width, height: item.size.height)
                    )
                    currentX += item.size.width + spacing
                }
            }
            currentY += rowHeight + spacing
        }
    }
}
