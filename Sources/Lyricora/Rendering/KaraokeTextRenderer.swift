import SwiftUI

@available(macOS 15.0, *)
public struct KaraokeWordRenderer: TextRenderer {
    public var progress: Double
    public var highlightColor: Color
    public var baseColor: Color
    public var isGlowEnabled: Bool
    public var isRTL: Bool
    
    public init(
        progress: Double,
        highlightColor: Color = .white,
        baseColor: Color = Color.white.opacity(0.35),
        isGlowEnabled: Bool = true,
        isRTL: Bool = false
    ) {
        self.progress = min(max(0.0, progress), 1.0)
        self.highlightColor = highlightColor
        self.baseColor = baseColor
        self.isGlowEnabled = isGlowEnabled
        self.isRTL = isRTL
    }
    
    public func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            for run in line {
                let bounds = run.typographicBounds.rect
                
                // 1. Draw base dimmed text
                var baseContext = context
                baseContext.opacity = 0.38
                baseContext.draw(run)
                
                // 2. Draw highlighted reveal if progress > 0
                if progress > 0.001 {
                    let fillWidth = bounds.width * CGFloat(progress)
                    let clipRect: CGRect
                    if isRTL {
                        // For Right-to-Left scripts (Urdu, Arabic, Hebrew), reveal glyphs from right to left
                        clipRect = CGRect(
                            x: bounds.maxX - fillWidth,
                            y: bounds.minY - 8,
                            width: fillWidth,
                            height: bounds.height + 16
                        )
                    } else {
                        // Standard Left-to-Right reveal
                        clipRect = CGRect(
                            x: bounds.minX,
                            y: bounds.minY - 8,
                            width: fillWidth,
                            height: bounds.height + 16
                        )
                    }
                    
                    if isGlowEnabled && progress < 1.0 {
                        // Dynamic glow bloom on the leading edge of singing
                        var glowContext = context
                        glowContext.addFilter(.blur(radius: 6))
                        glowContext.opacity = 0.75
                        glowContext.clip(to: Path(clipRect))
                        glowContext.draw(run)
                    }
                    
                    var highlightContext = context
                    highlightContext.clip(to: Path(clipRect))
                    highlightContext.draw(run)
                }
            }
        }
    }
}

/// Unified Karaoke Word component supporting TextRenderer on macOS 15+
/// and hardware-accelerated clipping mask on macOS 14.
public struct KaraokeWordText: View {
    public let text: String
    public let progress: Double
    public var font: Font
    public var baseColor: Color
    public var highlightColor: Color
    public var isGlowEnabled: Bool
    public var isRTL: Bool
    
    public init(
        text: String,
        progress: Double,
        font: Font,
        baseColor: Color = Color.white.opacity(0.38),
        highlightColor: Color = .white,
        isGlowEnabled: Bool = true,
        isRTL: Bool? = nil
    ) {
        self.text = text
        self.progress = min(max(0.0, progress), 1.0)
        self.font = font
        self.baseColor = baseColor
        self.highlightColor = highlightColor
        self.isGlowEnabled = isGlowEnabled
        self.isRTL = isRTL ?? text.isRightToLeft
    }
    
    public var body: some View {
        if #available(macOS 15.0, *) {
            Text(text)
                .font(font)
                .textRenderer(
                    KaraokeWordRenderer(
                        progress: progress,
                        highlightColor: highlightColor,
                        baseColor: baseColor,
                        isGlowEnabled: isGlowEnabled,
                        isRTL: isRTL
                    )
                )
        } else {
            // macOS 14 Sonoma fallback using GPU-accelerated frame masking
            Text(text)
                .font(font)
                .foregroundColor(baseColor)
                .overlay(
                    GeometryReader { geo in
                        if progress > 0.001 {
                            let revealWidth = geo.size.width * CGFloat(progress)
                            Text(text)
                                .font(font)
                                .foregroundColor(highlightColor)
                                .shadow(
                                    color: (isGlowEnabled && progress < 1.0) ? highlightColor.opacity(0.6) : .clear,
                                    radius: 6
                                )
                                .mask(
                                    HStack(spacing: 0) {
                                        if isRTL {
                                            Spacer(minLength: 0)
                                            Rectangle()
                                                .frame(width: max(0, revealWidth))
                                        } else {
                                            Rectangle()
                                                .frame(width: max(0, revealWidth))
                                            Spacer(minLength: 0)
                                        }
                                    }
                                )
                        }
                    }
                )
        }
    }
}
