import Foundation

public struct LyricWord: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let text: String
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    
    public var isRTL: Bool {
        text.isRightToLeft
    }
    
    public init(id: UUID = UUID(), text: String, startTime: TimeInterval, endTime: TimeInterval) {
        self.id = id
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
    }
    
    public func progress(at time: TimeInterval) -> Double {
        if time < startTime {
            return 0.0
        }
        if time >= endTime {
            return 1.0
        }
        let duration = max(0.05, endTime - startTime)
        return min(max(0.0, (time - startTime) / duration), 1.0)
    }
}

public struct LyricLine: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let startTime: TimeInterval
    public var endTime: TimeInterval
    public let rawText: String
    public var words: [LyricWord]
    
    public init(
        id: UUID = UUID(),
        startTime: TimeInterval,
        endTime: TimeInterval,
        rawText: String,
        words: [LyricWord] = []
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.rawText = rawText
        self.words = words
    }
    
    public var isRTL: Bool {
        rawText.isRightToLeft
    }
    
    public func isActive(at time: TimeInterval) -> Bool {
        return time >= startTime && time < endTime
    }
    
    public func isPast(at time: TimeInterval) -> Bool {
        return time >= endTime
    }
    
    public func isFuture(at time: TimeInterval) -> Bool {
        return time < startTime
    }
}

public struct LyricsPayload: Equatable, Sendable {
    public let lines: [LyricLine]
    public let isInstrumental: Bool
    public let isSynced: Bool
    public let plainLyrics: String?
    
    public init(
        lines: [LyricLine] = [],
        isInstrumental: Bool = false,
        isSynced: Bool = false,
        plainLyrics: String? = nil
    ) {
        self.lines = lines
        self.isInstrumental = isInstrumental
        self.isSynced = isSynced
        self.plainLyrics = plainLyrics
    }
    
    public func activeLineIndex(for time: TimeInterval) -> Int? {
        guard !lines.isEmpty else { return nil }
        
        // Binary search for efficiency across long song lyrics
        var low = 0
        var high = lines.count - 1
        var candidate: Int? = nil
        
        while low <= high {
            let mid = (low + high) / 2
            let line = lines[mid]
            
            if line.startTime <= time {
                candidate = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        
        if let idx = candidate {
            let line = lines[idx]
            if time >= line.startTime && time <= line.endTime + 0.35 {
                return idx
            }
            // If between lines, keep candidate if within 2 seconds of end, or return candidate
            if time < line.endTime + 2.0 {
                return idx
            }
        }
        
        return candidate
    }
    
    /// Retrieves up to `before` non-empty lines preceding `activeIndex`,
    /// and up to `after` non-empty lines following `activeIndex`.
    /// Guarantees that instrumental/blank lines are skipped so no empty voids appear.
    public func surroundingLines(for activeIndex: Int?, before: Int = 2, after: Int = 3) -> (past: [LyricLine], next: [LyricLine]) {
        guard let activeIdx = activeIndex, lines.indices.contains(activeIdx) else {
            return ([], [])
        }
        
        var past: [LyricLine] = []
        var next: [LyricLine] = []
        
        // Walk backwards to gather past non-empty lines
        var p = activeIdx - 1
        while p >= 0 && past.count < before {
            let line = lines[p]
            let trimmed = line.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                past.insert(line, at: 0) // Preserve chronological order
            }
            p -= 1
        }
        
        // Walk forwards to gather upcoming non-empty lines
        var n = activeIdx + 1
        while n < lines.count && next.count < after {
            let line = lines[n]
            let trimmed = line.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                next.append(line)
            }
            n += 1
        }
        
        return (past, next)
    }
    
    public var isRTL: Bool {
        let nonBlankLines = lines.filter { !$0.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !nonBlankLines.isEmpty else {
            return plainLyrics?.isRightToLeft ?? false
        }
        let rtlLinesCount = nonBlankLines.filter { $0.isRTL }.count
        return rtlLinesCount > (nonBlankLines.count / 2)
    }
    
    public static let empty = LyricsPayload(lines: [], isInstrumental: false, isSynced: false, plainLyrics: nil)
    public static let instrumental = LyricsPayload(
        lines: [
            LyricLine(startTime: 0, endTime: 9999, rawText: "♪ Instrumental ♪", words: [])
        ],
        isInstrumental: true,
        isSynced: true,
        plainLyrics: "♪ Instrumental ♪"
    )
}

// MARK: - Unicode Right-to-Left (RTL) Script Detection
extension String {
    /// Determines whether the string is predominantly composed of or starts with a Right-to-Left script
    /// (e.g. Urdu, Arabic, Hebrew, Persian, Syriac, Thaana, Kurdish, Pashto, Sindhi).
    public var isRightToLeft: Bool {
        var rtlCount = 0
        var ltrCount = 0
        var firstStrongIsRTL: Bool? = nil
        
        for scalar in unicodeScalars {
            // Skip common whitespace, punctuation, digits, symbols
            if CharacterSet.whitespacesAndNewlines.contains(scalar) ||
               CharacterSet.punctuationCharacters.contains(scalar) ||
               CharacterSet.decimalDigits.contains(scalar) ||
               CharacterSet.symbols.contains(scalar) {
                continue
            }
            
            let v = scalar.value
            let isRTLChar = (0x0590...0x05FF).contains(v) || // Hebrew
                            (0x0600...0x06FF).contains(v) || // Arabic (Urdu, Persian, Arabic, Pashto, Sindhi)
                            (0x0700...0x074F).contains(v) || // Syriac
                            (0x0750...0x077F).contains(v) || // Arabic Supplement
                            (0x0780...0x07BF).contains(v) || // Thaana
                            (0x07C0...0x07FF).contains(v) || // N'Ko
                            (0x0800...0x085F).contains(v) || // Samaritan, Mandaic
                            (0x0870...0x08FF).contains(v) || // Arabic Extended-A, B, C
                            (0xFB1D...0xFB4F).contains(v) || // Hebrew Presentation Forms
                            (0xFB50...0xFDFF).contains(v) || // Arabic Presentation Forms-A
                            (0xFE70...0xFEFF).contains(v) || // Arabic Presentation Forms-B
                            (0x10800...0x10FFF).contains(v) || // Historical RTL (Aramaic, Phoenician, etc.)
                            (0x1E800...0x1E95F).contains(v)   // Mendé Kikakui, Adlam
            
            if isRTLChar {
                rtlCount += 1
                if firstStrongIsRTL == nil {
                    firstStrongIsRTL = true
                }
            } else if scalar.properties.isAlphabetic {
                ltrCount += 1
                if firstStrongIsRTL == nil {
                    firstStrongIsRTL = false
                }
            }
        }
        
        if let first = firstStrongIsRTL {
            if first { return true }
            return rtlCount > ltrCount
        }
        return false
    }
}
