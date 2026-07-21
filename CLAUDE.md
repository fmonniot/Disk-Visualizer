# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A native macOS SwiftUI app (macOS 26.5+, Xcode project, no Swift Package Manager) that scans a user-chosen folder and visualizes its disk usage as a **sunburst**. It was implemented from an HTML/CSS design handoff (`docs/design/DiskBloom.dc.html`) — that file is the source of truth for pixel dimensions, colors, and layout math. `docs/design/README.md` explains the handoff; the Swift code ports it (`Theme` mirrors the design palettes, `FileCategory` mirrors its `TYPES` table, `ByteFormat` mirrors `fmt()`).

## Build, test, run

There is a single scheme, `Disk Visualizer` (note the space; quote it). Targets: `Disk Visualizer`, `Disk VisualizerTests` (Swift Testing), `Disk VisualizerUITests` (XCTest).

```bash
# Build
xcodebuild -scheme "Disk Visualizer" -destination "platform=macOS" build

# Run all unit tests
xcodebuild -scheme "Disk Visualizer" -destination "platform=macOS" test

# Run a single unit test (Swift Testing → filter by Suite/case)
xcodebuild -scheme "Disk Visualizer" -destination "platform=macOS" \
  test -only-testing:"Disk VisualizerTests/Disk_VisualizerTests/byteFormatting"
```

Unit tests are the primary way to verify logic here — the scanner, the sunburst layout, byte formatting, and category classification all have coverage in `Disk VisualizerTests/Disk_VisualizerTests.swift`. This environment cannot launch the GUI or run UI tests; for anything visual, ask the user to check.

## Concurrency model (important)

The project sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — **everything is `@MainActor` by default.** The scan pipeline is deliberately kept off the main actor:

- `FileNode`, `FileCategory`, `DiskScanner`, `SunburstLayout` are all marked `nonisolated` so they can run on a background `Task.detached`.
- `FileNode` is `@unchecked Sendable`: it is built entirely on the background task and **never mutated after construction**, so passing the finished tree back to the main actor is safe. Preserve this invariant — don't add post-construction mutation.
- `VisualizerModel.scan()` runs `DiskScanner.scan` on a detached user-initiated task and checks `Task.isCancelled` before applying results. It still wraps folder access in `startAccessingSecurityScopedResource()`, but the app is **not sandboxed** (`ENABLE_APP_SANDBOX = NO`) — a deliberate choice so whole-volume scans can read TCC-protected locations once the user grants the app **Full Disk Access** (no App Store / Developer ID target). The call is a harmless no-op without the sandbox.

## Architecture

Single source of truth is **`VisualizerModel`** (`@MainActor @Observable`), created once in `Disk_VisualizerApp` and injected via `.environment`. It owns the scan lifecycle (`Phase`: idle/scanning/loaded/failed) and *all* navigation state:

- `root` — the scanned tree; `current` — node framed by the visualization + breadcrumbs; `selection` — node shown in the details panel; `expanded` — sidebar disclosure set.
- Navigation verbs: `enter` (focus + select + reveal in tree), `select` (details only), `activate` (drill into folders, select files), `goToParent`. Views call these; they never mutate model state directly.

`ContentView` switches on `phase` and lays out the loaded UI: `TopBarView` / `SidebarTreeView` / `VisualizationStageView` (with `LoadingOverlayView` while scanning) / `DetailsPanelView` / `BottomBarView`, plus a transient `ToastView`.

### The sunburst visualization

Lives under `Views/Sunburst/`, split into a pure layout enum (testable, `nonisolated`) and a SwiftUI view. Arcs are laid out in a **fixed 720×720 coordinate space** then scaled to fit. Hit-testing is *analytic* (cursor → radius → depth, angle → segment via `SunburstView.arc(at:scale:in:)`) rather than SwiftUI hit-testing, so the highlight, tooltip node, and tooltip position always agree. Angles start from the top (straight up = angle 0).

### Theming

`Theme` holds every color role for the UI, with verbatim `.dark` / `.light` palettes from the design. The active theme **follows the system appearance** (`ContentView` picks it from `colorScheme`) and is passed down through `EnvironmentValues.theme`. When adding UI, pull colors from the injected `theme`, not literals — the only hex literals in views are the couple of accent colors on the welcome screen.

## Conventions

- File categories are size-weighted: a folder's `category` is the `dominantCategory` (most bytes) of its contents; a file's is derived from its extension. Coloring flows from this.
- Certain directory bundles (`.app`, `.photoslibrary`, `.xcassets`, `.framework`, …) are treated as **opaque leaves** — their size is summed but their contents aren't navigable. See `DiskScanner.opaqueExtensions`.
- The scanner **skips** entries it can't read (permissions, races) rather than failing the whole scan; only `Cancelled` propagates.

## Known deferred work

See `docs/TODO.md` for the current backlog.
