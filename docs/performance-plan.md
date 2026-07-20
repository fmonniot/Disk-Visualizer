# Performance investigation & plan

Findings from a profiling session (2026-07-19) into why a large scan (~/Documents-scale)
uses ~1 GB of memory and takes 10–20 s, and the resulting plan. Context that shapes the
plan: **scanning an entire volume is an eventual goal**, which means millions of nodes —
so the per-node memory work and the syscall-level scanner rewrite below are requirements,
not nice-to-haves.

## How the numbers were obtained

The app's GUI wasn't profiled directly; instead the actual `DiskScanner.swift`,
`FileNode.swift`, `FileCategory.swift`, `TreemapLayout.swift`, and a verbatim extraction
of `SunburstLayout` were compiled into a standalone `swiftc -O` harness, alongside an
instrumented copy of the scanner (identical traversal, timing counters) and candidate-fix
variants. Memory is `task_vm_info.phys_footprint`. Machine: 8-core Apple Silicon, APFS,
warm caches. Datasets: a real `~/Documents` (313,130 nodes, max depth 16) and a large
projects folder (715,978 nodes, max depth 20).

## Measurements

| | 313k-node tree | 716k-node tree |
|---|---|---|
| Serial `DiskScanner` scan (warm) | 9.9 s | 22.2 s |
| — time in `contentsOfDirectory` | 7.15 s (72%) | 15.72 s (71%) |
| — time in `resourceValues` | 1.17 s (12%) | 2.66 s (12%) |
| — time in `directorySize` (opaque bundles) | 0.10 s (1%) | 0.04 s (0.2%) |
| Peak footprint at scan end | 543 MB (1.8 KB/node) | 1,442 MB (2.1 KB/node) |
| Variant: per-dir `autoreleasepool` + hoisted key set | 324 MB, same speed | 824 MB, same speed |
| Variant: parallel walk (`concurrentPerform`, depth-3 fan-out) | 8.9 s | 20.8 s |
| Two independent *processes* scanning concurrently | full solo speed | full solo speed |
| Raw `fts(3)` serial walk (lower bound) | 6.1 s | 12.1 s |
| `SunburstLayout.arcs` per call | 4.9 ms @ 15,980 arcs | 3.0 ms @ 7,598 arcs |

Per-node memory (synthetic 300k-node tree): `FileNode` as-is = **864 B/node**; a node
holding only name+size+children+parent = **154 B/node**. Instance sizes 120 vs 56 B, so
~700 B/node is heap storage behind the stored `URL` — NSURL backing duplicating the full
path at every depth (path text alone sums to 95 MB on the 716k tree) plus the prefetched
resource-value caches those URLs retain.

## What was confirmed / refuted

- **Memory driver: per-node `FileNode` overhead × node count.** The stored `URL` is ~80%
  of it. 716k nodes → 1.44 GB in the bare harness; the ~1 GB in-app needs no other
  explanation. Secondary: the scan is one long synchronous call on a dispatch worker, so
  autoreleased Foundation objects can't drain until it ends (per-directory
  `autoreleasepool` cut peak ~40% for free).
- **Scan time driver: `contentsOfDirectory` itself** (~72%). The `resourceValues` call in
  `buildNode` is *not* a redundant stat — the `includingPropertiesForKeys:` prefetch
  works (3.3 µs vs 26.5 µs cold per file, measured). Keep passing keys.
- **Refuted: opaque-bundle `directorySize` double-walk as a material cost** — ≤1% on both
  datasets. It scales with bundle content (a huge `.photoslibrary` would show up), but
  it's paid once per bundle and there is no cheaper accurate API (no "recursive size"
  resource key exists).
- **Refuted: parallelizing the FileManager-based walk.** `concurrentPerform` fan-out
  (top-level and recursive, with and without per-thread `FileManager` instances) gains
  ≤6% — Foundation's directory machinery serializes in-process. Crucially, two separate
  *processes* scan concurrently at full solo speed, so the kernel/SSD scale fine; the
  bottleneck is Foundation, not the disk. Parallelism pays only below Foundation.
- **Confirmed: hover stutter is layout recompute.** `hoveredID`/`cursor` are `@State` and
  `arcs`/`tiles` are computed in `body`, so every pointer-move sample re-runs
  `SunburstLayout.arcs` (3–5 ms, 36–59% of a 120 Hz frame) and re-diffs ~16k arc views.
  Treemap layout itself is trivial (0.02 ms; it only tiles direct children).
- **Non-issues:** `ancestryChain` (navigation-only, depth-bounded), `initialExpansion`
  (single O(n) walk, tens of ms — though it pointlessly recurses below depth 2),
  sidebar `visibleRows` (0.11 ms per render).

## Plan

Ordered so each step is independently shippable; 1–4 are small, 5 is the milestone that
unlocks whole-volume scanning.

1. **Cache sunburst arcs (and treemap tiles) keyed on `current.id`.** Compute on
   navigation (e.g. `@State` refreshed via `.onChange(of: current?.id, initial: true)`,
   or cached in `VisualizerModel`); hover then only updates `hoveredID`. Also filter arcs
   with span < 0.004 rad out *before* the `ForEach` — they're invisible already
   (`SunburstView.arcShape`) but still get diffed.
2. ~~**Per-directory `autoreleasepool` + hoist the resource-key `Set` in
   `DiskScanner.buildNode`.**~~ Done. Measured: −40% peak memory, −2.6% scan time, no
   downside. Do regardless of step 5 (the same pattern applies inside the rewritten walk).
3. **Slim `FileNode`: drop the stored `URL` (and optionally `UUID`).** Store only `name`
   (root keeps its absolute URL); compute the path on demand by walking `parent` — `url`
   is consumed in exactly two per-user-action places (`VisualizerModel.reveal`,
   `DetailsPanelView` path line). `ObjectIdentifier(self)` can serve `Identifiable`.
   Measured 864 → 154 B/node; at volume scale (3–5M nodes) this is the difference between
   ~500 MB–750 MB and 3–4 GB. All fields still set once in `init`, preserving the
   never-mutated-after-construction / `@unchecked Sendable` invariant.
4. ~~**Sort `children` by size (descending) once at scan time**, before constructing the
   node. Removes the per-call re-sorts in `SunburstLayout.arcs`, `SidebarTreeView`, and
   lets `TreemapLayout` skip its sort (area order ≡ size order). Pre-construction, so the
   immutability invariant holds.~~ Done.
5. **Rewrite the walk on `getattrlistbulk(2)` (or `fts(3)`) with a parallel worker pool**
   — the whole-volume scanner. Measured basis: `fts` does the same traversal 1.8× faster
   serially, and the two-process experiment shows the kernel scales with concurrency, so
   a parallelized syscall-level walk should land 3–6× overall (≈2–4 s for 700k nodes;
   minutes → tens of seconds for a full volume). Design notes:
   - `getattrlistbulk` is the better fit: one syscall returns a batch of directory
     entries *with* attributes (`ATTR_CMN_NAME`, `ATTR_CMN_OBJTYPE` for file/dir/symlink,
     `ATTR_CMN_MODTIME`, `ATTR_FILE_ALLOCSIZE`), replacing
     `contentsOfDirectory` + `resourceValues` per entry. `fts` is simpler but stats one
     entry at a time.
   - Parallelize with a bounded worker pool / `TaskGroup` over a shared queue of
     directories (not per-level fan-out — real trees are too imbalanced; that was
     measured at ≤6% gain even at depth-3 fan-out).
   - Package/bundle detection: the LaunchServices-backed `isPackage` flag isn't available
     at this layer; rely on the existing `opaqueExtensions` set (already the dominant
     path today) and accept that exotic unregistered packages become navigable folders —
     or do a targeted `isPackageKey` lookup only for directory names containing a dot.
   - Preserve existing semantics: skip unreadable entries, don't follow symlinks, stay on
     one volume for whole-volume mode (`FTS_XDEV` equivalent: compare `st_dev` /
     `ATTR_CMN_DEVID`), check `Task.isCancelled` per directory.
   - Whole-volume mode also needs UX/entitlement work outside the scanner: the sandbox
     requires the user to pick the volume root in the open panel (read-only
     user-selected-files entitlement covers descendants), and Full Disk Access governs
     protected locations — unreadable subtrees are skipped, so results are best-effort
     without it. Progress reporting (see docs/TODO.md) becomes essential at this scale.
6. **Micro:** prune `initialExpansion` recursion below depth 2. Leave `directorySize`
   as-is (subsumed by step 5's walk anyway).
