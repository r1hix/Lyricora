import Foundation
import Observation

public struct LRCLIBResponse: Codable, Sendable {
    public let id: Int?
    public let name: String?
    public let trackName: String?
    public let artistName: String?
    public let albumName: String?
    public let duration: Double?
    public let instrumental: Bool?
    public let plainLyrics: String?
    public let syncedLyrics: String?
}

@Observable
@MainActor
public final class LyricsService {
    public static let shared = LyricsService()
    
    public private(set) var currentLyrics: LyricsPayload = .empty
    public private(set) var isLoading: Bool = false
    public private(set) var errorMessage: String? = nil
    
    // In-memory cache to save battery and network bandwidth
    private var cache: [String: LyricsPayload] = [:]
    private var currentLoadingTrackId: String?
    
    public init() {}
    
    // MARK: - Public Fetch Method
    public func loadLyrics(for track: Track) {
        let cacheKey = "\(track.artist.lowercased())___\(track.title.lowercased())"
        
        if let cached = cache[cacheKey] {
            self.currentLyrics = cached
            self.isLoading = false
            self.errorMessage = nil
            return
        }
        
        self.isLoading = true
        self.errorMessage = nil
        self.currentLoadingTrackId = track.id
        
        Task { [weak self] in
            guard let self = self else { return }
            let payload = await self.fetchFromLRCLIB(track: track)
            
            // Ensure we are still requesting for the current track
            if self.currentLoadingTrackId == track.id {
                self.cache[cacheKey] = payload
                self.currentLyrics = payload
                self.isLoading = false
            }
        }
    }
    
    // MARK: - API Fetching
    private nonisolated func fetchFromLRCLIB(track: Track) async -> LyricsPayload {
        // Step 1: Try exact match via /api/get
        if let exactPayload = await fetchExactLRCLIB(track: track) {
            return exactPayload
        }
        
        // Step 2: Fallback search via /api/search
        if let searchPayload = await fetchSearchLRCLIB(track: track) {
            return searchPayload
        }
        
        return LyricsPayload(
            lines: [],
            isInstrumental: false,
            isSynced: false,
            plainLyrics: "No synchronized lyrics found for \"\(track.title)\"."
        )
    }
    
    private nonisolated func fetchExactLRCLIB(track: Track) async -> LyricsPayload? {
        var components = URLComponents(string: "https://lrclib.net/api/get")
        components?.queryItems = [
            URLQueryItem(name: "artist_name", value: track.artist),
            URLQueryItem(name: "track_name", value: track.title),
            URLQueryItem(name: "album_name", value: track.album),
            URLQueryItem(name: "duration", value: "\(Int(track.duration))")
        ]
        
        guard let url = components?.url else { return nil }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 6.0
        request.setValue("Lyricora/1.0 (macOS Native)", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                let decoded = try JSONDecoder().decode(LRCLIBResponse.self, from: data)
                return parseLRCLIBResponse(decoded, trackDuration: track.duration)
            }
        } catch {
            // Proceed to fallback
        }
        return nil
    }
    
    private nonisolated func fetchSearchLRCLIB(track: Track) async -> LyricsPayload? {
        let cleanTitle = track.title
            .replacingOccurrences(of: "\\(.*\\)", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\[.*\\]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        var components = URLComponents(string: "https://lrclib.net/api/search")
        components?.queryItems = [
            URLQueryItem(name: "track_name", value: cleanTitle),
            URLQueryItem(name: "artist_name", value: track.artist)
        ]
        
        guard let url = components?.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 6.0
        request.setValue("Lyricora/1.0 (macOS Native)", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                let decodedList = try JSONDecoder().decode([LRCLIBResponse].self, from: data)
                if let bestMatch = decodedList.first(where: { ($0.syncedLyrics != nil && !$0.syncedLyrics!.isEmpty) || $0.instrumental == true }) ?? decodedList.first {
                    return parseLRCLIBResponse(bestMatch, trackDuration: track.duration)
                }
            }
        } catch {
            // Return nil
        }
        return nil
    }
    
    // MARK: - Parsing Engine
    private nonisolated func parseLRCLIBResponse(_ response: LRCLIBResponse, trackDuration: TimeInterval) -> LyricsPayload {
        if response.instrumental == true {
            return .instrumental
        }
        
        if let synced = response.syncedLyrics, !synced.isEmpty {
            let parsedLines = parseLRCContent(synced, trackDuration: trackDuration)
            if !parsedLines.isEmpty {
                return LyricsPayload(
                    lines: parsedLines,
                    isInstrumental: false,
                    isSynced: true,
                    plainLyrics: response.plainLyrics
                )
            }
        }
        
        if let plain = response.plainLyrics, !plain.isEmpty {
            let simpleLines = plain.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .map { text in
                    LyricLine(startTime: 0, endTime: 0, rawText: text, words: [])
                }
            return LyricsPayload(
                lines: simpleLines,
                isInstrumental: false,
                isSynced: false,
                plainLyrics: plain
            )
        }
        
        return .empty
    }
    
    public nonisolated func parseLRCContent(_ lrc: String, trackDuration: TimeInterval) -> [LyricLine] {
        var rawLines: [(time: TimeInterval, rawText: String)] = []
        let timeRegex = try? NSRegularExpression(pattern: #"\[(\d{2}):(\d{2})\.(\d{2,3})\]"#, options: [])
        
        let lines = lrc.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            
            // Skip metadata tags like [ar: Artist], [ti: Title], etc.
            if trimmed.hasPrefix("[ar:") || trimmed.hasPrefix("[ti:") || trimmed.hasPrefix("[al:") || trimmed.hasPrefix("[by:") || trimmed.hasPrefix("[length:") {
                continue
            }
            
            let nsLine = trimmed as NSString
            let matches = timeRegex?.matches(in: trimmed, options: [], range: NSRange(location: 0, length: nsLine.length)) ?? []
            
            if let firstMatch = matches.first {
                let minStr = nsLine.substring(with: firstMatch.range(at: 1))
                let secStr = nsLine.substring(with: firstMatch.range(at: 2))
                let msStr = nsLine.substring(with: firstMatch.range(at: 3))
                
                let mins = Double(minStr) ?? 0.0
                let secs = Double(secStr) ?? 0.0
                let msDiv: Double = msStr.count == 3 ? 1000.0 : 100.0
                let ms = (Double(msStr) ?? 0.0) / msDiv
                
                let timestamp = (mins * 60.0) + secs + ms
                let text = nsLine.substring(from: firstMatch.range.location + firstMatch.range.length)
                    .trimmingCharacters(in: .whitespaces)
                
                if !text.isEmpty {
                    rawLines.append((time: timestamp, rawText: text))
                }
            }
        }
        
        // Sort lines chronologically
        rawLines.sort { $0.time < $1.time }
        
        var result: [LyricLine] = []
        for (i, item) in rawLines.enumerated() {
            let nextTime: TimeInterval
            if i + 1 < rawLines.count {
                nextTime = rawLines[i + 1].time
            } else {
                nextTime = max(item.time + 4.0, trackDuration)
            }
            
            let availableGap = max(0.5, nextTime - item.time)
            let cleanText = cleanDisplayLyric(item.rawText)
            let cleanWords = cleanText.split(separator: " ").map { String($0) }
            let totalChars = cleanWords.reduce(0) { $0 + max(1, $1.count) }
            
            // Estimate natural vocal singing duration (~0.26s base per word + ~0.065s per char + 0.35s final vowel sustain)
            let estimatedVocalDuration = Double(cleanWords.count) * 0.26 + Double(totalChars) * 0.065 + 0.35
            
            // Vocal animation ends when singing naturally completes, but stays within available gap
            let vocalDuration = min(max(0.2, availableGap - 0.2), max(0.8, estimatedVocalDuration))
            let vocalEndTime = item.time + vocalDuration
            
            // Line remains active on screen until the next line arrives
            let lineActiveEndTime = max(vocalEndTime, nextTime)
            
            // Tokenize words using vocalEndTime for the singing reveal
            let words = tokenizeWords(lineText: item.rawText, lineStart: item.time, lineEnd: vocalEndTime)
            
            let line = LyricLine(
                startTime: item.time,
                endTime: lineActiveEndTime,
                rawText: cleanText,
                words: words
            )
            result.append(line)
        }
        
        return result
    }
    
    private nonisolated func cleanDisplayLyric(_ text: String) -> String {
        // Strip any embedded word timestamps like <00:12.34>
        return text.replacingOccurrences(of: #"<\d{2}:\d{2}\.\d{2,3}>"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
    
    private nonisolated func tokenizeWords(lineText: String, lineStart: TimeInterval, lineEnd: TimeInterval) -> [LyricWord] {
        let wordTimeRegex = try? NSRegularExpression(pattern: #"<(\d{2}):(\d{2})\.(\d{2,3})>([^<]+)"#, options: [])
        let nsText = lineText as NSString
        let matches = wordTimeRegex?.matches(in: lineText, options: [], range: NSRange(location: 0, length: nsText.length)) ?? []
        
        if !matches.isEmpty {
            // Enhanced LRC format with explicit word timestamps
            var words: [LyricWord] = []
            for (idx, match) in matches.enumerated() {
                let minStr = nsText.substring(with: match.range(at: 1))
                let secStr = nsText.substring(with: match.range(at: 2))
                let msStr = nsText.substring(with: match.range(at: 3))
                let text = nsText.substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespaces)
                
                let mins = Double(minStr) ?? 0.0
                let secs = Double(secStr) ?? 0.0
                let msDiv: Double = msStr.count == 3 ? 1000.0 : 100.0
                let wordStart = (mins * 60.0) + secs + ((Double(msStr) ?? 0.0) / msDiv)
                
                var wordEnd = wordStart + 0.4
                if idx + 1 < matches.count {
                    let nextMatch = matches[idx + 1]
                    let nMin = Double(nsText.substring(with: nextMatch.range(at: 1))) ?? 0.0
                    let nSec = Double(nsText.substring(with: nextMatch.range(at: 2))) ?? 0.0
                    let nMsStr = nsText.substring(with: nextMatch.range(at: 3))
                    let nMs = (Double(nMsStr) ?? 0.0) / (nMsStr.count == 3 ? 1000.0 : 100.0)
                    wordEnd = (nMin * 60.0) + nSec + nMs
                } else {
                    wordEnd = lineEnd
                }
                
                if !text.isEmpty {
                    words.append(LyricWord(text: text, startTime: wordStart, endTime: wordEnd))
                }
            }
            if !words.isEmpty {
                return words
            }
        }
        
        // Standard LRC: Natural singing timing interpolation across words
        let cleanWords = cleanDisplayLyric(lineText).split(separator: " ").map { String($0) }
        guard !cleanWords.isEmpty else { return [] }
        
        let totalChars = cleanWords.reduce(0) { $0 + max(1, $1.count) }
        let lineDuration = max(0.5, lineEnd - lineStart)
        
        var currentOffset = lineStart
        var words: [LyricWord] = []
        
        for (idx, word) in cleanWords.enumerated() {
            let isLast = (idx == cleanWords.count - 1)
            let weight = Double(max(1, word.count)) + (isLast ? 2.5 : 0.0)
            let adjustedTotal = Double(max(1, totalChars)) + (cleanWords.count > 1 ? 2.5 : 0.0)
            let fraction = weight / adjustedTotal
            let wordDuration = lineDuration * fraction
            let wordEnd = currentOffset + wordDuration
            words.append(LyricWord(text: word, startTime: currentOffset, endTime: wordEnd))
            currentOffset = wordEnd
        }
        
        return words
    }
}
