# 2. A shared screen buffer for drawing the terminal UI

- Status: Rejected for now (see "Revisit when")
- Date: 2026-10-27

## Context

[ADR 1](0001-terminal-ui.md) put the terminal UI's drawing in `Layout`, which returns the screen as lines of styled segments. Since then, the TUI has been restructured, and these are the names this ADR uses:

- **Panes** are the screen's two areas: `:nav` on the left, with the Dashboard row, the files and the endpoints, and `:main` on the right.
- **Views** hold what's shown in the main pane, and its cursor: `OutlineView`, `DashboardView` and `EndpointView` (`lib/raindown/tui/views/`). The nav is a `ListView`, which `OutlineView` builds on.
- **Renderers** draw what's in a pane (`lib/raindown/tui/renderers/`). Each view names its renderer with `view.renderer`, and the nav's `ListView` names `ListRenderer`.
- **`Layout`** draws the title, the status line and the button bar, with the two panes side by side between them.

A renderer returns its pane's lines. Each line is a list of `Text::Segment`s, and each segment has its text, its style, and the event a click on it sends. `Layout` joins the nav's lines and the main pane's lines with a divider. `Screen` paints each segment with one curses `addstr`. `Input#zones` finds what was clicked by adding up the segments' widths.

Most terminal UI libraries draw into a **shared screen buffer** instead. Ratatui, and RatatuiRuby, which wraps it, are examples. A buffer is a grid of cells, each with a character and a style. Widgets draw into a rectangle of it, and the library paints only the cells that changed. We considered switching, because some of our code does by hand what a buffer does for free:

- **`MenuOverlay`** draws the project menu over the screen's lines. To do that, it has to cut each line at the menu's columns, one character at a time, and it replaces a wide character cut in half with spaces.
- **The divider looks at the line beside it** to borrow the main pane's highlight colour.
- **Every renderer pads its lines** to exactly its pane's width, with `padded`, `blank` and `fit`.
- **Clicks are found by walking segment widths**, not by looking up a cell.

## Decision

**We don't draw into a shared screen buffer, and keep lines of segments.** The screen is one row of two panes, plus one overlay, and joining lines covers that in a few lines of `Layout`. A buffer is most useful for stacked or nested layouts, several popups, or widgets drawing over each other. The TUI has none of those yet.

**Drawing over lines is part of `Text`**, so the next overlay doesn't need its own copy of `MenuOverlay`'s code:

- `overlay_segments(line, segments, column:)` returns the line with the segments drawn over its columns from `column` on.
- `segments_between(line, from, to)` returns the parts of a line's segments between two columns, with spaces where a wide character is cut in two.

`MenuOverlay` uses them, and any renderer or overlay that includes `Text` can too.

### Options considered

|                       | Lines of segments (kept)                                    | Our own screen buffer                                                                                 | RatatuiRuby's buffer                                                           |
| --------------------- | ----------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| New code              | None                                                        | A buffer, rectangles, wide-character cells, and grouping cells back into styled runs to paint quickly | Replaces `terminal/`, `Layout`'s widths, and every renderer's output           |
| Overlays              | `overlay_segments` cuts lines at columns                    | Draw over the cells                                                                                   | Draw over the cells, or use its `Clear` and `Overlay` widgets                  |
| Wide characters       | The terminal lays out each segment's text                   | Each wide character needs a "continues the cell before" marker                                        | Handled by the library                                                         |
| Clicks                | Each segment carries its event, and `Input#zones` finds it  | Look up the cell                                                                                      | Not provided: apps keep each widget's rectangle and work out what was clicked  |
| Specs                 | Unchanged                                                   | Most of `layout_spec` and `input_spec` rewritten                                                      | The same, plus a Rust toolchain on Intel Macs, as ADR 1 found                  |

**Wide characters were the deciding cost of our own buffer.** An emoji with the variation selector, like `🌧️`, is drawn one column wide by some terminals and two by others, and the nav's `📊` is two. The title used `🌧️`, and stopped a column short of the edge in case it was drawn wide, until it switched to the plain `🌧` that the nav uses. A buffer has to decide which cell each half belongs to. Segments leave that to the terminal, and only `fit` and `segments_between` measure widths.

**Our own buffer would add far more code than it removes.** It would replace about 20 lines of cutting and splicing, and some padding, with a few hundred lines of buffer, rectangles and painting.

## Consequences

- Renderers still return lines exactly their pane's width, and `Layout` still joins them. A renderer that returns a short line leaves a gap that the next pane's text moves into, so the specs check the widths (`layout_spec`: "fits the cards to a pane narrower than a card can be").
- New overlays, like a help screen or a confirmation, draw over `Layout`'s lines with `overlay_segments`, as `MenuOverlay` does.
- The divider still reads the main pane's first segment for its style.

## Revisit when

- **The TUI gets more overlays, popups or stacked panes.** If several of them are drawn over each other, or the panes split vertically, the cutting and joining will spread, and a buffer starts to pay for itself.
- **We move to RatatuiRuby.** It brings a buffer, wide-character handling, rectangles and layout constraints, and that would beat building our own. Views and the Navigator would stay as they are. Renderers would become widgets drawing into a rectangle, and `Segment`s would become styled spans.
