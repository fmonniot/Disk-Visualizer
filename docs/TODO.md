# Backlog

Deferred enhancements, not yet implemented.

## Wire up the search field

The top-bar search pill (`TopBarView.searchPill`) is currently **decorative** —
it renders the design's search box but does nothing. Make it filter the view:

- Bind it to a query string on `VisualizerModel`.
- Filter/highlight matching nodes in the sidebar tree, and optionally dim
  non-matching arcs/tiles in the sunburst and treemap.
- Decide scope: name-only vs. path, current folder vs. whole tree.

## Real scan progress

The scanning overlay (`LoadingOverlayView`) shows an **indeterminate** shimmer
because `DiskScanner` reports no progress. Improve the feedback:

- Have `DiskScanner` report progress (e.g. count of items scanned, or bytes
  seen) via a callback, surfaced through `VisualizerModel`.
- Show a live item count / current path in the overlay subtitle, and/or a
  determinate bar if a total can be estimated cheaply.
