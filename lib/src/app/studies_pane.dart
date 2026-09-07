/// Whether the studies pane is collapsed, across every navigation (#18).
///
/// Field feedback: *"When I click to the simulation it is opening the side
/// pane, keep the same state as it was."* It was a plain `bool` on
/// `_ProjectWorkspaceScreenState`, and switching mode is a `go_router`
/// navigation to a different route — so the screen was rebuilt and the flag
/// went with it. **The last piece of in-memory UI state phase 3 did not
/// convert** (#7).
///
/// **A provider over a file, not a location.** §12.1 reserves the URL for
/// `?study=` — the one filter you navigate *from* — and #17 re-affirmed that a
/// view setting stays out of it; a pane collapse is a view setting. The file is
/// `window.json`, beside `maximized`, because it is the same kind of choice:
/// made once, expected to hold tomorrow.
///
/// **Optimistic, and deliberately so.** The toggle moves the pane immediately
/// and the write follows; a disk write that fails leaves the pane where the
/// reader put it for this session and Diag has the error. Making the pane wait
/// on a file would be a 280 px animation gated on I/O.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'window_geometry.dart';

part 'studies_pane.g.dart';

@Riverpod(keepAlive: true)
class StudiesPaneCollapsed extends _$StudiesPaneCollapsed {
  /// Starts expanded and corrects itself once the file has been read.
  ///
  /// **Not an `AsyncValue`**, because every reader of this is a layout
  /// decision that has to be made on the first frame. Expanded is the honest
  /// default for the moment before the answer arrives: it is what a first run
  /// shows, and a pane that appears and then collapses is a smaller wrong than
  /// a workspace that flashes without its study list.
  @override
  bool build() {
    WindowChrome.studiesPaneCollapsed().then((collapsed) {
      if (collapsed != state) state = collapsed;
    });
    return false;
  }

  void toggle() {
    state = !state;
    WindowChrome.setStudiesPaneCollapsed(state);
  }
}
