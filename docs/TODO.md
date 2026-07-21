# Backlog

Deferred enhancements, not yet implemented.

## Performance & whole-volume scanning

See [performance-plan.md](performance-plan.md) for the measured findings (memory is
per-node `FileNode`/URL overhead; scan time is `contentsOfDirectory`; hover stutter is
per-sample layout recompute) and the ranked plan, including the
`getattrlistbulk`-based parallel scanner rewrite that whole-volume scanning requires.

## Real scan progress

**Partly done.** `DiskScanner.scan` now takes a `ScanProgress` counter that its
workers bump per scanned entry; `VisualizerModel` polls it (~150 ms) into
`scannedItemCount`, and `LoadingOverlayView` shows a live "N items scanned"
subtitle. Still indeterminate (no bar). Possible follow-ups:

- Show the current path being scanned, not just a count.
- A determinate bar if a total can be estimated cheaply (e.g. from a prior
  scan of the same root, or the volume's file count).

## App icon & README screenshot

- Create a proper app icon (currently using the Xcode default/placeholder).
- Update the README with a screenshot of the main view.

## Remove the treemap view

Turns out not to be that useful in practice. Drop `Views/Treemap/` (layout +
SwiftUI view) and the sunburst/treemap toggle, keeping only the sunburst.
