# Backlog

Deferred enhancements, not yet implemented.

## Performance & whole-volume scanning

See [performance-plan.md](performance-plan.md) for the measured findings (memory is
per-node `FileNode`/URL overhead; scan time is `contentsOfDirectory`; hover stutter is
per-sample layout recompute) and the ranked plan, including the
`getattrlistbulk`-based parallel scanner rewrite that whole-volume scanning requires.

## Wire up the search field

The top-bar search pill (`TopBarView.searchPill`) is currently **decorative** —
it renders the design's search box but does nothing. Make it filter the view:

- Bind it to a query string on `VisualizerModel`.
- Filter/highlight matching nodes in the sidebar tree, and optionally dim
  non-matching arcs/tiles in the sunburst and treemap.
- Decide scope: name-only vs. path, current folder vs. whole tree.

## Real scan progress

**Partly done.** `DiskScanner.scan` now takes a `ScanProgress` counter that its
workers bump per scanned entry; `VisualizerModel` polls it (~150 ms) into
`scannedItemCount`, and `LoadingOverlayView` shows a live "N items scanned"
subtitle. Still indeterminate (no bar). Possible follow-ups:

- Show the current path being scanned, not just a count.
- A determinate bar if a total can be estimated cheaply (e.g. from a prior
  scan of the same root, or the volume's file count).
