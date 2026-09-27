# Agent Instructions: Lyricora

This document defines the repository structure, branch roles, path boundaries, and development workflows for AI agents working on **Lyricora**.

---

## 1. Project Overview
- **Name**: Lyricora
- **Platform**: macOS 14.0+ (Apple Silicon & Intel)
- **Frameworks**: SwiftUI, AppKit, Observation
- **Core Functionality**: Dynamic desktop lyrics overlay (Mini HUD, Full Overlay, Ambient Canvas) and native macOS Touch Bar integration with Spotify sync.
- **App Bundle Builder**: `./build_app.sh` (produces `./build/Lyricora.app`)

---

## 2. Branch Architecture & Roles

This repository maintains a strict two-branch separation of concerns:

### `master` Branch (Production / End-User Release)
- **Purpose**: Clean, lightweight release branch containing **only** files required to build and run the end-user application.
- **Allowed Paths**:
  - `Sources/` — Core Swift application source code.
  - `build_app.sh` — App bundle packaging script.
  - `Package.swift` — Swift package manifest declaring **only** the `Lyricora` executable target.
  - `.gitignore` — Release `.gitignore` that explicitly excludes developer-only artifacts:
    - Excludes `Tests/`
    - Excludes `graphify-out/` and `.graphify*`
  - `README.md`, `LICENSE`, `AGENTS.md`
- **Forbidden Paths on `master`**:
  - `Tests/` (Never committed to `master`)
  - `graphify-out/` (Never committed to `master`)
  - Test targets in `Package.swift`

### `dev` Branch (Active Development & Architecture)
- **Purpose**: All active development, testing, architectural analysis, and debugging.
- **Allowed Paths**:
  - All paths from `master` (`Sources/`, `build_app.sh`, etc.)
  - `Tests/` — Unit test suite (`Tests/LyricoraTests/`).
  - `Package.swift` — Includes both `Lyricora` target and `LyricoraTests` test target.
  - `graphify-out/` — Architecture dependency graphs, community clusters, and reports:
    - `GRAPH_REPORT.md` — Architectural overview and module community analysis.
    - `graph.html` — Interactive visual architecture graph.
    - `graph.json` — Raw AST dependency graph data.
    - `manifest.json` — File-level symbol and import metadata.
    - `.graphify_labels.json` — Cluster labeling cache.
  - `.gitignore` — Configured to track core `graphify-out/` reports while ignoring:
    - `graphify-out/cache/`
    - `graphify-out/*.sig`
    - `graphify-out/.graphify_root`
    - `graphify-out/.graphify_analysis.json`
    - `graphify-out/20*/` (date backup directories)

---

## 3. Workflow & Contribution Rules

### Making Code Changes
1. **Always develop on `dev` first**:
   - Implement features or bug fixes in `Sources/`.
   - Update or add tests in `Tests/` if applicable.
   - Verify compilation using `./build_app.sh` or `swift build`.
2. **Rebuilding Graphify Index** (after structural or multi-file changes):
   - Run the graphify workflow from project root:
     ```bash
     graphify extract . --code-only
     graphify cluster-only "$(pwd)"
     ```
   - Verify `graphify-out/` reports are updated and clean.
3. **Propagating Fixes to `master`**:
   - Switch to `master`: `git checkout master`
   - Only check out user-facing files from `dev`:
     ```bash
     git checkout dev -- Sources/ build_app.sh
     ```
   - **Never** run a plain `git merge dev` into `master` (as this would pollute `master` with `Tests/`, `graphify-out/`, and conflicting package/gitignore settings).
   - Verify the build on `master` with `./build_app.sh`.
   - Commit and push to `origin/master`.
   - Switch back to `dev`: `git checkout dev`.

---

## 4. Key Project Conventions & Gotchas

- **Window Sizing & Positioning**:
  - Window frame management is centralized in `WindowManager.swift`.
  - In `transition(to:)`, changing modes must preserve on-screen bounds.
  - Ambient Mode (`.ambientCanvas`) centers the window within `NSScreen.visibleFrame` and saves the previous overlay frame to restore when returning to compact/overlay modes.
- **SwiftUI & AppKit Lifecycle**:
  - UI initialization (e.g. creating floating windows, presenting modal Touch Bars) must happen in or after `applicationDidFinishLaunching` (or via `DispatchQueue.main.async`).
  - Never trigger modal AppKit overlays or `NSHostingView` layouts synchronously inside `@Observable` / `@State` property initializers or `init()` methods, as this triggers `AttributeGraph` re-entrancy assertion crashes (`AG::precondition_failure`).
