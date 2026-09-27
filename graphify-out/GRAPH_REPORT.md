# Graph Report - lyrics-app  (2026-09-28)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 340 nodes · 736 edges · 16 communities (11 shown, 5 thin omitted)
- Extraction: 91% EXTRACTED · 9% INFERRED · 0% AMBIGUOUS · INFERRED: 68 edges (avg confidence: 0.82)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `1811a5e8`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- String
- SpotifyObserver
- WindowManager
- LyricsView
- AmbientBackdropView
- ViewMode
- SwiftUI
- TouchBarService
- AmbientCanvasView
- SleepPreventerService
- KaraokeWordText
- build_app.sh
- Package.swift
- NSEvent
- TimeInterval
- Void

## God Nodes (most connected - your core abstractions)
1. `SpotifyObserver` - 33 edges
2. `LyricsService` - 26 edges
3. `TouchBarService` - 25 edges
4. `LyricLine` - 24 edges
5. `WindowManager` - 21 edges
6. `AmbientCanvasView` - 21 edges
7. `LyricsPayload` - 20 edges
8. `LyricsView` - 20 edges
9. `LyricWord` - 18 edges
10. `Track` - 18 edges

## Surprising Connections (you probably didn't know these)
- `.body` --calls--> `KaraokeWordText`  [INFERRED]
  Sources/Lyricora/Views/AmbientCanvasView.swift → Sources/Lyricora/Rendering/KaraokeTextRenderer.swift
- `.body` --calls--> `KaraokeWordText`  [INFERRED]
  Sources/Lyricora/Views/LyricsView.swift → Sources/Lyricora/Rendering/KaraokeTextRenderer.swift
- `.body` --calls--> `KaraokeWordText`  [INFERRED]
  Sources/Lyricora/Views/MiniHUDView.swift → Sources/Lyricora/Rendering/KaraokeTextRenderer.swift
- `.centerLyricsView` --calls--> `KaraokeWordText`  [INFERRED]
  Sources/Lyricora/Views/TouchBarLyricsView.swift → Sources/Lyricora/Rendering/KaraokeTextRenderer.swift
- `.body` --calls--> `FlowLayout`  [INFERRED]
  Sources/Lyricora/Views/AmbientCanvasView.swift → Sources/Lyricora/Views/LyricsView.swift

## Import Cycles
- None detected.

## Communities (16 total, 5 thin omitted)

### Community 0 - "String"
Cohesion: 0.07
Nodes (36): Codable, Foundation, Hashable, Lyricora, LyricLine, .isRTL, LyricsPayload, .isRTL (+28 more)

### Community 1 - "SpotifyObserver"
Cohesion: 0.09
Nodes (20): NSEvent, SpotifyObserver, .isPlaying, Bool, Notification, NSImage, TimeInterval, URL (+12 more)

### Community 2 - "WindowManager"
Cohesion: 0.09
Nodes (19): NSApplication, NSApplicationDelegate, NSObject, NSRect, NSWindow, NSWindowDelegate, AppDelegate, Bool (+11 more)

### Community 3 - "LyricsView"
Cohesion: 0.12
Nodes (23): CGRect, Layout, ProposedViewSize, FlowLayout, LyricLineRow, .body, .timeIndicator, LyricsView (+15 more)

### Community 4 - "AmbientBackdropView"
Cohesion: 0.15
Nodes (17): CGPoint, Date, Equatable, Sendable, AmbientBackdropView, .body, AmbientTimeTracker, ColorExtractor (+9 more)

### Community 5 - "ViewMode"
Cohesion: 0.09
Nodes (23): CaseIterable, Identifiable, CGSize, TouchBarLyricsMode, .iconName, .id, lineByLine, off (+15 more)

### Community 6 - "SwiftUI"
Cohesion: 0.12
Nodes (13): AppKit, Combine, Context, NSView, NSViewRepresentable, Observation, QuartzCore, DragNSView (+5 more)

### Community 7 - "TouchBarService"
Cohesion: 0.16
Nodes (8): NSCustomTouchBarItem, NSTouchBarDelegate, NSTouchBarItem, Bool, NSTouchBar, TouchBarService, .mode, TouchBarLyricsMode

### Community 8 - "AmbientCanvasView"
Cohesion: 0.15
Nodes (13): Any, Content, AmbientCanvasView, .body, AnyTransition, BlurTransitionModifier, Bool, CGFloat (+5 more)

### Community 9 - "SleepPreventerService"
Cohesion: 0.15
Nodes (11): App, IOKit.pwr_mgt, IOPMAssertionID, Scene, LyricoraApp, .body, .menuBarContent, View (+3 more)

### Community 10 - "KaraokeWordText"
Cohesion: 0.26
Nodes (10): Font, KaraokeWordRenderer, KaraokeWordText, .body, Bool, Color, Double, GraphicsContext (+2 more)

## Knowledge Gaps
- **36 isolated node(s):** `Lyricora`, `XCTest`, `.isRTL`, `.isRTL`, `.isRightToLeft` (+31 more)
  These have ≤1 connection - possible missing edges. (Counts symbols only; 95 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `SpotifyObserver` connect `SpotifyObserver` to `String`, `LyricsView`, `ViewMode`, `SwiftUI`, `AmbientCanvasView`?**
  _High betweenness centrality (0.151) - this node is a cross-community bridge._
- **Why does `String` connect `String` to `SpotifyObserver`, `LyricsView`, `ViewMode`, `AmbientCanvasView`, `KaraokeWordText`?**
  _High betweenness centrality (0.122) - this node is a cross-community bridge._
- **Why does `.body` connect `AmbientCanvasView` to `SpotifyObserver`, `WindowManager`, `LyricsView`, `AmbientBackdropView`, `SwiftUI`, `SleepPreventerService`, `KaraokeWordText`?**
  _High betweenness centrality (0.116) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `LyricsService` (e.g. with `.testEnhancedWordLRCParser()` and `.testLRCParser()`) actually correct?**
  _`LyricsService` has 3 INFERRED edges - model-reasoned connections that need verification._
- **Are the 3 inferred relationships involving `LyricLine` (e.g. with `.isRTL` and `.testLyricLineAndPayloadRTL()`) actually correct?**
  _`LyricLine` has 3 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Lyricora`, `XCTest`, `.isRTL` to the rest of the system?**
  _36 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `String` be split into smaller, more focused modules?**
  _Cohesion score 0.06584723441615452 - nodes in this community are weakly interconnected._