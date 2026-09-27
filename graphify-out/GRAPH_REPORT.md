# Graph Report - lyrics-app  (2026-09-27)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 332 nodes · 734 edges · 15 communities (12 shown, 3 thin omitted)
- Extraction: 91% EXTRACTED · 9% INFERRED · 0% AMBIGUOUS · INFERRED: 68 edges (avg confidence: 0.82)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- String
- SpotifyObserver
- SwiftUI
- TouchBarService
- LyricsView
- WindowManager
- AmbientBackdropView
- AmbientCanvasView
- ViewMode
- KaraokeWordText
- WindowDragHandle
- SleepPreventerService
- LyricoraTests.swift
- build_app.sh
- Package.swift

## God Nodes (most connected - your core abstractions)
1. `SpotifyObserver` - 33 edges
2. `LyricsService` - 26 edges
3. `TouchBarService` - 25 edges
4. `LyricLine` - 24 edges
5. `AmbientCanvasView` - 21 edges
6. `ViewMode` - 21 edges
7. `LyricsPayload` - 20 edges
8. `LyricsView` - 20 edges
9. `WindowManager` - 20 edges
10. `LyricWord` - 18 edges

## Surprising Connections (you probably didn't know these)
- `.body` --calls--> `WindowDragHandle`  [INFERRED]
  Sources/Lyricora/Views/AmbientCanvasView.swift → Sources/Lyricora/Views/WindowDragHandle.swift
- `.headerView` --calls--> `WindowDragHandle`  [INFERRED]
  Sources/Lyricora/Views/ContentView.swift → Sources/Lyricora/Views/WindowDragHandle.swift
- `.body` --calls--> `WindowDragHandle`  [INFERRED]
  Sources/Lyricora/Views/MiniHUDView.swift → Sources/Lyricora/Views/WindowDragHandle.swift
- `.body` --calls--> `TouchBarLyricsView`  [INFERRED]
  Sources/Lyricora/Views/ContentView.swift → Sources/Lyricora/Views/TouchBarLyricsView.swift
- `.body` --calls--> `FlowLayout`  [INFERRED]
  Sources/Lyricora/Views/AmbientCanvasView.swift → Sources/Lyricora/Views/LyricsView.swift

## Import Cycles
- None detected.

## Communities (15 total, 3 thin omitted)

### Community 0 - "String"
Cohesion: 0.10
Nodes (24): Equatable, Hashable, Identifiable, Sendable, LyricLine, .isRTL, LyricsPayload, .isRTL (+16 more)

### Community 1 - "SpotifyObserver"
Cohesion: 0.10
Nodes (19): .menuBarContent, NSEvent, SpotifyObserver, .isPlaying, Bool, Notification, NSImage, TimeInterval (+11 more)

### Community 2 - "SwiftUI"
Cohesion: 0.08
Nodes (24): App, AppKit, Codable, Combine, Foundation, IOKit.pwr_mgt, Observation, QuartzCore (+16 more)

### Community 3 - "TouchBarService"
Cohesion: 0.10
Nodes (17): CaseIterable, NSCustomTouchBarItem, NSTouchBarDelegate, NSTouchBarItem, TouchBarLyricsMode, .iconName, .id, lineByLine (+9 more)

### Community 4 - "LyricsView"
Cohesion: 0.12
Nodes (23): CGRect, Layout, ProposedViewSize, FlowLayout, LyricLineRow, .body, .timeIndicator, LyricsView (+15 more)

### Community 5 - "WindowManager"
Cohesion: 0.10
Nodes (17): NSApplication, NSApplicationDelegate, NSObject, NSWindow, NSWindowDelegate, AppDelegate, Bool, Notification (+9 more)

### Community 6 - "AmbientBackdropView"
Cohesion: 0.15
Nodes (15): CGPoint, Date, AmbientBackdropView, .body, AmbientTimeTracker, ColorExtractor, DynamicPalette, RGBColor (+7 more)

### Community 7 - "AmbientCanvasView"
Cohesion: 0.15
Nodes (13): Any, Content, AmbientCanvasView, .body, AnyTransition, BlurTransitionModifier, Bool, CGFloat (+5 more)

### Community 8 - "ViewMode"
Cohesion: 0.15
Nodes (12): CGSize, ViewMode, ambientCanvas, fullOverlay, .iconName, .id, miniHUD, .windowSize (+4 more)

### Community 9 - "KaraokeWordText"
Cohesion: 0.26
Nodes (10): Font, KaraokeWordRenderer, KaraokeWordText, .body, Bool, Color, Double, GraphicsContext (+2 more)

### Community 10 - "WindowDragHandle"
Cohesion: 0.19
Nodes (8): Context, NSView, NSViewRepresentable, DragNSView, NSEvent, WindowDragHandle, WindowDragPill, .body

### Community 11 - "SleepPreventerService"
Cohesion: 0.31
Nodes (4): IOPMAssertionID, SleepPreventerService, .isScreenAwakeEnabled, Bool

## Knowledge Gaps
- **36 isolated node(s):** `.isRTL`, `.isRTL`, `.isRightToLeft`, `.isPlaying`, `Lyricora` (+31 more)
  These have ≤1 connection - possible missing edges. (Counts symbols only; 90 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **3 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `String` connect `String` to `SpotifyObserver`, `SwiftUI`, `TouchBarService`, `LyricsView`, `AmbientCanvasView`, `ViewMode`, `KaraokeWordText`?**
  _High betweenness centrality (0.163) - this node is a cross-community bridge._
- **Why does `SpotifyObserver` connect `SpotifyObserver` to `String`, `SwiftUI`, `TouchBarService`, `LyricsView`, `AmbientCanvasView`?**
  _High betweenness centrality (0.140) - this node is a cross-community bridge._
- **Why does `ViewMode` connect `ViewMode` to `String`, `SpotifyObserver`, `SwiftUI`, `TouchBarService`, `WindowManager`, `AmbientCanvasView`?**
  _High betweenness centrality (0.125) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `LyricsService` (e.g. with `.testEnhancedWordLRCParser()` and `.testLRCParser()`) actually correct?**
  _`LyricsService` has 3 INFERRED edges - model-reasoned connections that need verification._
- **Are the 3 inferred relationships involving `LyricLine` (e.g. with `.isRTL` and `.testLyricLineAndPayloadRTL()`) actually correct?**
  _`LyricLine` has 3 INFERRED edges - model-reasoned connections that need verification._
- **What connects `.isRTL`, `.isRTL`, `.isRightToLeft` to the rest of the system?**
  _36 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `String` be split into smaller, more focused modules?**
  _Cohesion score 0.10180995475113122 - nodes in this community are weakly interconnected._