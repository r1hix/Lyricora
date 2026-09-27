import XCTest
@testable import Lyricora

@MainActor
final class LyricoraTests: XCTestCase {
    func testLRCParser() {
        let sampleLRC = """
        [00:12.50] Hello darkness, my old friend
        [00:16.80] I've come to talk with you again
        [00:21.00] Because a vision softly creeping
        """
        
        let parser = LyricsService()
        let lines = parser.parseLRCContent(sampleLRC, trackDuration: 180)
        
        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[0].startTime, 12.5)
        XCTAssertEqual(lines[0].rawText, "Hello darkness, my old friend")
        XCTAssertFalse(lines[0].words.isEmpty)
        XCTAssertEqual(lines[1].startTime, 16.8)
    }
    
    func testEnhancedWordLRCParser() {
        let enhancedLRC = """
        [00:05.00] <00:05.00> Never <00:05.50> gonna <00:06.00> give <00:06.50> you <00:07.00> up
        """
        
        let parser = LyricsService()
        let lines = parser.parseLRCContent(enhancedLRC, trackDuration: 180)
        
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].words.count, 5)
        XCTAssertEqual(lines[0].words[0].text, "Never")
        XCTAssertEqual(lines[0].words[0].startTime, 5.0)
        XCTAssertEqual(lines[0].words[1].text, "gonna")
        XCTAssertEqual(lines[0].words[1].startTime, 5.5)
    }
    
    func testClockInterpolation() {
        let word = LyricWord(text: "Hello", startTime: 10.0, endTime: 12.0)
        XCTAssertEqual(word.progress(at: 9.0), 0.0)
        XCTAssertEqual(word.progress(at: 11.0), 0.5)
        XCTAssertEqual(word.progress(at: 13.0), 1.0)
    }
    
    func testRealLRCLIBParsing() {
        let lrc = """
        [00:33.80] Look at the stars
        [00:36.23] Look how they shine for you
        [00:40.43] 
        [00:41.82] And everything you do
        """
        let parser = LyricsService()
        let lines = parser.parseLRCContent(lrc, trackDuration: 267)
        XCTAssertEqual(lines.count, 3) // Empty line omitted
        XCTAssertEqual(lines[0].rawText, "Look at the stars")
        XCTAssertEqual(lines[0].startTime, 33.80)
        XCTAssertEqual(lines[0].words.count, 4)
        XCTAssertEqual(lines[0].words[0].text, "Look")
        XCTAssertEqual(lines[0].words[3].text, "stars")
        
        // Active line lookup
        let payload = LyricsPayload(lines: lines, isInstrumental: false, isSynced: true)
        XCTAssertEqual(payload.activeLineIndex(for: 34.0), 0)
        XCTAssertEqual(payload.activeLineIndex(for: 38.0), 1)
        XCTAssertEqual(payload.activeLineIndex(for: 42.0), 2)
    }
    
    func testSurroundingLines() {
        let lines = [
            LyricLine(startTime: 10, endTime: 15, rawText: "Line 1"),
            LyricLine(startTime: 15, endTime: 20, rawText: "Line 2"),
            LyricLine(startTime: 20, endTime: 25, rawText: "   "), // blank line to skip
            LyricLine(startTime: 25, endTime: 30, rawText: "Line 3 (Active)"),
            LyricLine(startTime: 30, endTime: 35, rawText: ""), // blank line to skip
            LyricLine(startTime: 35, endTime: 40, rawText: "Line 4"),
            LyricLine(startTime: 40, endTime: 45, rawText: "Line 5"),
            LyricLine(startTime: 45, endTime: 50, rawText: "Line 6")
        ]
        let payload = LyricsPayload(lines: lines, isInstrumental: false, isSynced: true)
        
        let (past, next) = payload.surroundingLines(for: 3, before: 2, after: 3)
        // Past should skip blank line index 2 and return Line 1 and Line 2
        XCTAssertEqual(past.count, 2)
        XCTAssertEqual(past[0].rawText, "Line 1")
        XCTAssertEqual(past[1].rawText, "Line 2")
        
        // Next should skip blank line index 4 and return Line 4, Line 5, Line 6
        XCTAssertEqual(next.count, 3)
        XCTAssertEqual(next[0].rawText, "Line 4")
        XCTAssertEqual(next[1].rawText, "Line 5")
        XCTAssertEqual(next[2].rawText, "Line 6")
    }
    
    func testTouchBarModes() {
        let service = TouchBarService.shared
        service.setMode(.off)
        XCTAssertEqual(service.mode, .off)
        XCTAssertNil(service.makeTouchBar())
        
        service.cycleMode()
        XCTAssertEqual(service.mode, .lineByLine)
        XCTAssertNotNil(service.makeTouchBar())
        
        service.cycleMode()
        XCTAssertEqual(service.mode, .wordFill)
        XCTAssertNotNil(service.makeTouchBar())
        
        service.cycleMode()
        XCTAssertEqual(service.mode, .off)
    }
    
    func testRTLScriptDetection() {
        // Urdu lyric from user's screenshot
        let urduLyric = "نَا وَل میں نی، رواں نیں اکھیاں"
        XCTAssertTrue(urduLyric.isRightToLeft)
        
        // Arabic
        let arabic = "حبيبي يا نور العين"
        XCTAssertTrue(arabic.isRightToLeft)
        
        // Hebrew
        let hebrew = "שלום עליכם"
        XCTAssertTrue(hebrew.isRightToLeft)
        
        // Persian
        let persian = "زندگی زیباست"
        XCTAssertTrue(persian.isRightToLeft)
        
        // Timestamped / numbered RTL line
        let numberedUrdu = "01. [00:15.30] نَا وَل میں"
        XCTAssertTrue(numberedUrdu.isRightToLeft)
        
        // English / Latin
        let english = "Never gonna give you up"
        XCTAssertFalse(english.isRightToLeft)
        
        // Spanish
        let spanish = "Despacito, quiero respirar tu cuello"
        XCTAssertFalse(spanish.isRightToLeft)
        
        // Instrumental tag
        let instrumental = "♪ Instrumental ♪"
        XCTAssertFalse(instrumental.isRightToLeft)
        
        // Empty string
        XCTAssertFalse("".isRightToLeft)
    }
    
    func testLyricLineAndPayloadRTL() {
        let urduLine = LyricLine(
            startTime: 10.0,
            endTime: 15.0,
            rawText: "نَا وَل میں نی، رواں نیں اکھیاں",
            words: [
                LyricWord(text: "نَا", startTime: 10.0, endTime: 10.5),
                LyricWord(text: "وَل", startTime: 10.5, endTime: 11.2)
            ]
        )
        XCTAssertTrue(urduLine.isRTL)
        XCTAssertTrue(urduLine.words[0].isRTL)
        XCTAssertTrue(urduLine.words[1].isRTL)
        
        let englishLine = LyricLine(
            startTime: 15.0,
            endTime: 20.0,
            rawText: "Hello world",
            words: [LyricWord(text: "Hello", startTime: 15.0, endTime: 17.0)]
        )
        XCTAssertFalse(englishLine.isRTL)
        XCTAssertFalse(englishLine.words[0].isRTL)
        
        let urduPayload = LyricsPayload(lines: [urduLine], isInstrumental: false, isSynced: true)
        XCTAssertTrue(urduPayload.isRTL)
        
        let englishPayload = LyricsPayload(lines: [englishLine], isInstrumental: false, isSynced: true)
        XCTAssertFalse(englishPayload.isRTL)
    }
    
    func testRGBColorInterpolation() {
        let c1 = RGBColor(r: 0.0, g: 0.2, b: 0.8)
        let c2 = RGBColor(r: 1.0, g: 0.8, b: 0.2)
        
        let mid = c1.lerp(to: c2, t: 0.5)
        XCTAssertEqual(mid.r, 0.5, accuracy: 0.001)
        XCTAssertEqual(mid.g, 0.5, accuracy: 0.001)
        XCTAssertEqual(mid.b, 0.5, accuracy: 0.001)
        
        let start = c1.lerp(to: c2, t: 0.0)
        XCTAssertEqual(start.r, 0.0, accuracy: 0.001)
        
        let end = c1.lerp(to: c2, t: 1.0)
        XCTAssertEqual(end.r, 1.0, accuracy: 0.001)
    }
    
    func testDynamicPaletteFallback() {
        let fallback = DynamicPalette.fallback
        XCTAssertEqual(fallback.primaryRGB.r, 0.14, accuracy: 0.01)
        XCTAssertEqual(fallback.secondaryRGB.g, 0.18, accuracy: 0.01)
    }
    
    func testAmbientTimeTracker() {
        let tracker = AmbientTimeTracker()
        let now = Date()
        
        // Initial tick records base date without advance
        _ = tracker.advance(currentDate: now, isPlaying: true)
        XCTAssertEqual(tracker.time, 0.0)
        
        // Playing tick advances at 1.0x speed
        let tick1 = now.addingTimeInterval(0.05)
        let timeAfterPlay = tracker.advance(currentDate: tick1, isPlaying: true)
        XCTAssertEqual(timeAfterPlay, 0.05, accuracy: 0.001)
        
        // Paused tick advances at gentle 0.22x speed
        let tick2 = tick1.addingTimeInterval(0.05)
        let timeAfterPause = tracker.advance(currentDate: tick2, isPlaying: false)
        XCTAssertEqual(timeAfterPause, 0.05 + 0.05 * 0.22, accuracy: 0.001)
    }
    
    func testColorExtractorWithSyntheticImage() {
        // Create 32x32 vibrant cyan/blue test image
        let size = NSSize(width: 32, height: 32)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemTeal.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        
        let palette = ColorExtractor.extractDominantColors(from: image)
        XCTAssertNotEqual(palette, DynamicPalette.fallback)
        XCTAssertGreaterThan(palette.primaryRGB.g, 0.2)
    }
}

