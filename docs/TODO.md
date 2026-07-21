# Backlog

Deferred enhancements, not yet implemented.

## Whole-volume scanning

The performance work is done (see [performance-plan.md](performance-plan.md)), including
the `getattrlistbulk`-based parallel scanner rewrite. What's left to actually support
scanning a whole volume:

- UX/entitlement work: the sandbox requires picking the volume root in the open panel,
  and Full Disk Access governs protected locations — unreadable subtrees are skipped, so
  results are best-effort without it.
- An `st_dev` / `ATTR_CMN_DEVID` single-volume guard in the scanner (`FTS_XDEV`
  equivalent), so the walk doesn't cross onto other mounted volumes.

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
