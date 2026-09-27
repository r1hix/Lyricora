import SwiftUI
import AppKit

// MARK: - RGB Color Helper for Smooth Interpolation
public struct RGBColor: Equatable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double
    
    public init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }
    
    public var color: Color {
        Color(red: r, green: g, blue: b)
    }
    
    public func lerp(to target: RGBColor, t: Double) -> RGBColor {
        let factor = max(0.0, min(1.0, t))
        return RGBColor(
            r: r + (target.r - r) * factor,
            g: g + (target.g - g) * factor,
            b: b + (target.b - b) * factor
        )
    }
}

// MARK: - Dynamic Palette
public struct DynamicPalette: Equatable, Sendable {
    public let primary: Color
    public let secondary: Color
    public let tertiary: Color
    public let quaternary: Color
    public let highlight: Color
    
    public let primaryRGB: RGBColor
    public let secondaryRGB: RGBColor
    public let tertiaryRGB: RGBColor
    public let quaternaryRGB: RGBColor
    public let highlightRGB: RGBColor
    
    public init(
        primary: Color,
        secondary: Color,
        tertiary: Color,
        quaternary: Color? = nil,
        highlight: Color? = nil,
        primaryRGB: RGBColor = RGBColor(r: 0.14, g: 0.08, b: 0.32),
        secondaryRGB: RGBColor = RGBColor(r: 0.06, g: 0.18, b: 0.42),
        tertiaryRGB: RGBColor = RGBColor(r: 0.30, g: 0.06, b: 0.24),
        quaternaryRGB: RGBColor? = nil,
        highlightRGB: RGBColor? = nil
    ) {
        self.primary = primary
        self.secondary = secondary
        self.tertiary = tertiary
        self.quaternary = quaternary ?? secondary
        self.highlight = highlight ?? primary
        
        self.primaryRGB = primaryRGB
        self.secondaryRGB = secondaryRGB
        self.tertiaryRGB = tertiaryRGB
        self.quaternaryRGB = quaternaryRGB ?? secondaryRGB
        self.highlightRGB = highlightRGB ?? primaryRGB
    }
    
    public static let fallback = DynamicPalette(
        primary: Color(red: 0.14, green: 0.08, blue: 0.32),
        secondary: Color(red: 0.06, green: 0.18, blue: 0.42),
        tertiary: Color(red: 0.30, green: 0.06, blue: 0.24),
        quaternary: Color(red: 0.08, green: 0.24, blue: 0.38),
        highlight: Color(red: 0.28, green: 0.18, blue: 0.52),
        primaryRGB: RGBColor(r: 0.14, g: 0.08, b: 0.32),
        secondaryRGB: RGBColor(r: 0.06, g: 0.18, b: 0.42),
        tertiaryRGB: RGBColor(r: 0.30, g: 0.06, b: 0.24),
        quaternaryRGB: RGBColor(r: 0.08, g: 0.24, b: 0.38),
        highlightRGB: RGBColor(r: 0.28, g: 0.18, b: 0.52)
    )
}

// MARK: - Color Extractor
public enum ColorExtractor {
    public static func extractDominantColors(from nsImage: NSImage) -> DynamicPalette {
        guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return .fallback
        }
        
        let targetSize = CGSize(width: 36, height: 36)
        let width = Int(targetSize.width)
        let height = Int(targetSize.height)
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        var rawData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return .fallback
        }
        
        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        struct SampledColor {
            let hue: Double
            let saturation: Double
            let brightness: Double
            let r: Double
            let g: Double
            let b: Double
            let weight: Double
        }
        
        var candidates: [SampledColor] = []
        var fallbackCandidates: [SampledColor] = []
        
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * bytesPerPixel
                let r = Double(rawData[offset]) / 255.0
                let g = Double(rawData[offset + 1]) / 255.0
                let b = Double(rawData[offset + 2]) / 255.0
                let a = Double(rawData[offset + 3]) / 255.0
                
                guard a > 0.5 else { continue }
                
                let nsColor = NSColor(red: r, green: g, blue: b, alpha: 1.0)
                let hue = Double(nsColor.hueComponent)
                let sat = Double(nsColor.saturationComponent)
                let bri = Double(nsColor.brightnessComponent)
                
                // High vibrancy candidates: optimal saturation and brightness
                if sat > 0.16 && bri > 0.15 && bri < 0.95 {
                    let weight = sat * 1.6 + (1.0 - abs(bri - 0.6))
                    candidates.append(SampledColor(hue: hue, saturation: sat, brightness: bri, r: r, g: g, b: b, weight: weight))
                }
                
                // Monochromatic / muted fallback candidates
                if bri > 0.12 && bri < 0.90 {
                    fallbackCandidates.append(SampledColor(hue: hue, saturation: sat, brightness: bri, r: r, g: g, b: b, weight: bri))
                }
            }
        }
        
        let pool = !candidates.isEmpty ? candidates : fallbackCandidates
        guard !pool.isEmpty else {
            return .fallback
        }
        
        let sorted = pool.sorted { $0.weight > $1.weight }
        
        let c1 = sorted[0]
        let c2 = sorted.first(where: { abs($0.hue - c1.hue) > 0.12 }) ?? sorted[min(sorted.count / 4, sorted.count - 1)]
        let c3 = sorted.first(where: { abs($0.hue - c1.hue) > 0.22 && abs($0.hue - c2.hue) > 0.12 }) ?? sorted[min(sorted.count / 2, sorted.count - 1)]
        let c4 = sorted.first(where: { abs($0.hue - c1.hue) > 0.08 && abs($0.hue - c2.hue) > 0.08 && abs($0.hue - c3.hue) > 0.08 }) ?? sorted[min(3 * sorted.count / 4, sorted.count - 1)]
        
        // Ensure colors have rich presence without blowing out text readability
        func tune(color: SampledColor, minSat: Double = 0.35, maxBri: Double = 0.78) -> RGBColor {
            let nsColor = NSColor(
                hue: color.hue,
                saturation: max(color.saturation, minSat),
                brightness: min(max(color.brightness, 0.35), maxBri),
                alpha: 1.0
            )
            return RGBColor(r: Double(nsColor.redComponent), g: Double(nsColor.greenComponent), b: Double(nsColor.blueComponent))
        }
        
        let rgb1 = tune(color: c1, minSat: 0.40, maxBri: 0.80)
        let rgb2 = tune(color: c2, minSat: 0.35, maxBri: 0.75)
        let rgb3 = tune(color: c3, minSat: 0.35, maxBri: 0.72)
        let rgb4 = tune(color: c4, minSat: 0.30, maxBri: 0.70)
        
        // Highlight color: luminous accent tint
        let highlightNS = NSColor(
            hue: c1.hue,
            saturation: max(0.25, c1.saturation * 0.8),
            brightness: min(0.92, max(0.55, c1.brightness + 0.20)),
            alpha: 1.0
        )
        let rgbHighlight = RGBColor(
            r: Double(highlightNS.redComponent),
            g: Double(highlightNS.greenComponent),
            b: Double(highlightNS.blueComponent)
        )
        
        return DynamicPalette(
            primary: rgb1.color,
            secondary: rgb2.color,
            tertiary: rgb3.color,
            quaternary: rgb4.color,
            highlight: rgbHighlight.color,
            primaryRGB: rgb1,
            secondaryRGB: rgb2,
            tertiaryRGB: rgb3,
            quaternaryRGB: rgb4,
            highlightRGB: rgbHighlight
        )
    }
}

// MARK: - Animation Time Accumulator
@MainActor
final class AmbientTimeTracker {
    private var lastDate: Date?
    private(set) var time: Double = 0.0
    
    func advance(currentDate: Date, isPlaying: Bool) -> Double {
        defer { lastDate = currentDate }
        guard let last = lastDate else {
            return time
        }
        let rawDelta = currentDate.timeIntervalSince(last)
        let dt = max(0.0, min(rawDelta, 0.1))
        
        // When playing, fluid energetic drift (1.0x); when paused, gentle relaxing drift (0.22x)
        let speedMultiplier: Double = isPlaying ? 1.0 : 0.22
        time += dt * speedMultiplier
        return time
    }
}

// MARK: - Ambient Backdrop View
public struct AmbientBackdropView: View {
    public let image: NSImage?
    public let isPlaying: Bool
    
    @State private var palette: DynamicPalette = .fallback
    @State private var previousPalette: DynamicPalette = .fallback
    @State private var crossfadeProgress: Double = 1.0
    @State private var timeTracker = AmbientTimeTracker()
    
    public init(image: NSImage?, isPlaying: Bool) {
        self.image = image
        self.isPlaying = isPlaying
    }
    
    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            
            ZStack {
                // Base deep dark canvas
                Color(red: 0.035, green: 0.035, blue: 0.065)
                    .ignoresSafeArea()
                
                // Living, fluid undulating mesh canvas
                TimelineView(.animation) { timeline in
                    let currentTime = timeTracker.advance(currentDate: timeline.date, isPlaying: isPlaying)
                    
                    // Smoothly interpolate RGB between previous and current palette on song change
                    let t = crossfadeProgress
                    let pRGB = previousPalette.primaryRGB.lerp(to: palette.primaryRGB, t: t)
                    let sRGB = previousPalette.secondaryRGB.lerp(to: palette.secondaryRGB, t: t)
                    let tRGB = previousPalette.tertiaryRGB.lerp(to: palette.tertiaryRGB, t: t)
                    let qRGB = previousPalette.quaternaryRGB.lerp(to: palette.quaternaryRGB, t: t)
                    let hRGB = previousPalette.highlightRGB.lerp(to: palette.highlightRGB, t: t)
                    
                    Canvas { context, canvasSize in
                        let w = canvasSize.width
                        let h = canvasSize.height
                        guard w > 0, h > 0 else { return }
                        
                        let maxDim = max(w, h)
                        let animTime = currentTime
                        
                        // Orb 1: Primary Dominant Fluid Surge (wanders across upper-left & center)
                        let t1 = animTime * 0.30
                        let p1 = CGPoint(
                            x: w * (0.34 + 0.22 * sin(t1) + 0.08 * cos(t1 * 1.5)),
                            y: h * (0.36 + 0.18 * cos(t1 * 0.9) + 0.07 * sin(t1 * 1.3))
                        )
                        let r1 = maxDim * (0.58 + 0.08 * sin(t1 * 1.1))
                        drawRadialOrb(context: &context, center: p1, radius: r1, color: pRGB.color, opacity: 0.72)
                        
                        // Orb 2: Secondary Vibrant Wave (drifts across bottom-right & center)
                        let t2 = animTime * 0.24 + 1.8
                        let p2 = CGPoint(
                            x: w * (0.70 - 0.24 * cos(t2) - 0.09 * sin(t2 * 1.4)),
                            y: h * (0.64 - 0.20 * sin(t2 * 0.85) + 0.08 * cos(t2 * 1.2))
                        )
                        let r2 = maxDim * (0.52 + 0.07 * cos(t2 * 1.05))
                        drawRadialOrb(context: &context, center: p2, radius: r2, color: sRGB.color, opacity: 0.68)
                        
                        // Orb 3: Tertiary Harmonic Swirl (diagonal weave through canvas)
                        let t3 = animTime * 0.36 + 3.2
                        let p3 = CGPoint(
                            x: w * (0.50 + 0.26 * sin(t3 * 0.8) + 0.08 * cos(t3 * 1.9)),
                            y: h * (0.44 - 0.22 * cos(t3 * 0.75) - 0.07 * sin(t3 * 1.6))
                        )
                        let r3 = maxDim * (0.48 + 0.08 * sin(t3 * 0.95))
                        drawRadialOrb(context: &context, center: p3, radius: r3, color: tRGB.color, opacity: 0.62)
                        
                        // Orb 4: Quaternary Warm Accent (sweeps bottom-left and center)
                        let t4 = animTime * 0.21 + 4.5
                        let p4 = CGPoint(
                            x: w * (0.24 + 0.20 * cos(t4 * 1.1) - 0.06 * sin(t4 * 0.6)),
                            y: h * (0.72 + 0.16 * sin(t4 * 0.9) + 0.08 * cos(t4 * 1.3))
                        )
                        let r4 = maxDim * (0.45 + 0.06 * cos(t4 * 1.2))
                        drawRadialOrb(context: &context, center: p4, radius: r4, color: qRGB.color, opacity: 0.58)
                        
                        // Orb 5: Luminous Core Pulse (illuminates lyrics active stage)
                        let t5 = animTime * 0.42 + 0.6
                        let p5 = CGPoint(
                            x: w * (0.58 + 0.16 * cos(t5 * 0.7) - 0.08 * sin(t5 * 1.3)),
                            y: h * (0.38 + 0.14 * sin(t5 * 0.65) + 0.06 * cos(t5 * 1.4))
                        )
                        let r5 = maxDim * (0.40 + 0.07 * sin(t5 * 1.3))
                        drawRadialOrb(context: &context, center: p5, radius: r5, color: hRGB.color, opacity: 0.48)
                    }
                }
                .blur(radius: 75)
                .ignoresSafeArea()
                
                // Subtle dark vignette to ensure perfect lyric contrast
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.12),
                        Color.black.opacity(0.52)
                    ]),
                    center: .center,
                    startRadius: min(size.width, size.height) * 0.28,
                    endRadius: max(size.width, size.height) * 0.88
                )
                .ignoresSafeArea()
            }
            .onAppear {
                updatePalette(with: image)
            }
            .onChange(of: image) { _, newImage in
                updatePalette(with: newImage)
            }
        }
    }
    
    private func drawRadialOrb(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        color: Color,
        opacity: Double
    ) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: color.opacity(opacity), location: 0.0),
                    .init(color: color.opacity(opacity * 0.70), location: 0.40),
                    .init(color: color.opacity(opacity * 0.22), location: 0.75),
                    .init(color: color.opacity(0.0), location: 1.0)
                ]),
                center: center,
                startRadius: 0,
                endRadius: radius
            )
        )
    }
    
    private func updatePalette(with img: NSImage?) {
        guard let img = img else {
            transitionTo(palette: .fallback)
            return
        }
        Task.detached(priority: .userInitiated) {
            let extracted = ColorExtractor.extractDominantColors(from: img)
            await MainActor.run {
                self.transitionTo(palette: extracted)
            }
        }
    }
    
    private func transitionTo(palette newPalette: DynamicPalette) {
        self.previousPalette = self.palette
        self.palette = newPalette
        self.crossfadeProgress = 0.0
        withAnimation(.easeInOut(duration: 1.4)) {
            self.crossfadeProgress = 1.0
        }
    }
}

