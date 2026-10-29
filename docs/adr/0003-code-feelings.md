# 3. Code feelings: sorting how code feels in the terminal UI

- Status: Accepted
- Date: 2026-10-28

## Context

Code review records what's wrong with code, but not how it feels to work with. Hesitation usually shows up before anyone can say why: a method that's scary to touch, a file that keeps needing changes, code everyone avoids. Some code is worth keeping as an example, and that rarely gets written down either.

The terminal UI ([ADR 1](0001-terminal-ui.md)) already has views and renderers ([ADR 2](0002-screen-buffer.md) lists the terms), a Dashboard that charts data, and ways to open the editor and run commands. Code feelings uses those to make recording how code feels quick enough to do regularly. It's modelled on the "macrodata refinement" screens in *Severance*, where workers sort a grid of numbers by the feeling they give off into one of four tempers: **woe, frolic, dread and malice**.

`f`, or teleporting to "Code feelings", opens it as a view in the main pane:

```
                                ▏                                                     39% refined
 📊 Dashboard                   ▏  2  7  6  7  2  3  1  3  5  7  7  9  1  1  8  8  8  5  5  0  0  5
 🎭 Feelings                    ▏  5  3  3  3  3  2  3  5  7  7  8  7  4  4  4  4  3  3  2  4  3  1
                                ▏ ╭─ lib/text.rb:62 · Text#segments_between ──────── changed 6× ─╮
                                ▏ │ def segments_between(line, from, to)                          │
                                ▏ │ [12 more lines]                                               │
                                ▏ ├───────────────────────────────────────────────────────────────┤
                                ▏ │ Why DREAD? > column maths, a character at a time▏             │
                                ▏ ╰───────────────────────────────────────────────────────────────╯
                                ▏ ╭─ 01 ─────╮ ╭─ 02 ─────╮ ╭─ 03 ─────╮ ╭─ 04 ─────╮ ╭─ 05 ─────╮
                                ▏ │ WOE      │ │ FROLIC   │ │ DREAD    │ │ MALICE   │ │ NUMB     │
                                ▏ │ ██░░░░ 6 │ │ ███░░░ 9 │ │ █░░░░░ 3 │ │ █░░░░░ 2 │ │ ████░ 41 │
                                ▏ ╰──────────╯ ╰──────────╯ ╰──────────╯ ╰──────────╯ ╰──────────╯
```

## Decision

### The grid

Each function or method in the batch (see The week's batch below) is a cluster of digits. The clusters fill the grid in a fixed order, left to right, wrapping onto the next row (`FeelingsView#cells`). A method takes one cell, plus one for every four of its lines, up to eight (`CodeMethod#size`).

**A method's digits show its drift, from 0 to 9.** Drift ranks each method against every method in the project by its weight: its lines times the commits that changed its file, plus one (`CodeMethods.drifting`). The lightest get 0 and the heaviest get 9, and methods with the same weight get the same drift. A rank spreads the digits evenly in any project, whatever its language or size, with no thresholds for line or commit counts.

The digits aren't uniform, which keeps the show's feel:

- **Noise:** about four cells in ten are one to three away from their method's drift. Each cell's checksum decides which, so a cell never changes from one draw to the next (`FeelingsRenderer::NOISE`).
- **Still:** a method that drifts 7 or more is restless, but its digits stay in the middle of their cells unless they're fleeing the mouse, below. Restless digits used to tremble now and then on their own too, on each cell's own clock.
- **Flicker:** a restless method's cells' digits also drop one lower for half a second now and then, about every 30 seconds each, at their own moment (`Motion#flicker`). An earlier version flickered them every 6 seconds.
- **Flee:** when the mouse is over a method, the digits beside it in its row move to the far side of their cells, away from it, where they tremble, a column either way for four steps of 0.09 seconds, about every 0.7 seconds, and every cell around it, above, below and diagonally too, is bold. Code feelings is drawn at 12 frames a second, a little faster than those trembles' steps, so none are skipped, and the rain at 20. Each frame's wait counts from when the last one started drawing, so the time it takes to draw doesn't slow the rate (`Screen#wait`).

**Cells are 3 columns wide and 1 line tall**, with the digit small in the middle, and the grid has a blank line above and below it. When the mouse is over a method, its digits are magnified, 3 columns wide and 3 lines tall, in the same block digits as the README's stats (`Raindown::Stat::DIGITS`), across their cell and over the cells above and below it. Each line of a magnified digit clicks whatever cell it covers (`Magnifier#magnify`), so the mouse over it is over that cell, and can move onto the digits it covers. Cells were 6 by 2 for a while, so magnified digits covered only blank space, but that quartered how many fit, and so the size of a batch.

### Styles

The screen's text, digits, lines and titles are lavender (the `feelings` style, 256-colour 183, or magenta in 8 colours), apart from the batch's progress, in grey. The selected method's cells are white on the selection's blue, or on green once it's felt, so they join into one block. The digits under the mouse are magnified, unless they are the selected method's, which keep the selection's style, with no highlight behind them, in lavender and purple (256-colour 135, or blue in 8 colours) by turns, like a chessboard's squares, since magnified digits beside and below each other touch. A felt method's cells go blank, but stay in place and stay selectable. Selecting one shows its digits and its code again. Nothing in the grid moves as methods are felt, so the batch visibly empties.

### Feeling a method

`1` to `5` sort the selected method into **frolic, numb, woe, dread or malice**, best to worst, as `CodeHealth` scores them, so the keys rate the code, rather than in *Severance*'s order. Numb is for code that gives no feeling. **The cursor stays on the method**, so the next thing you do can be about it. Woe, dread and malice first ask why, below the code. The question uses the typing mode teleport added, so keys like `q` and `j` are typed as letters. The note wraps onto as many lines as it needs, and Enter saves it, or Esc saves the feeling without one. Frolic and numb are noted straight away.

### Finding methods, in any language

`CodeMethods.list` runs **Universal Ctags** (`ctags --output-format=json --fields=+ne -R`) when it's installed, and keeps the function and method tags that have end lines. When it isn't, or the installed `ctags` is the BSD one macOS ships, which has no JSON output, an **indentation fallback** reads the code. A line starting a function (`def`, `function`, `fn`, `func`, `sub` or `proc`, after modifiers like `export`, `async` and `pub`) starts a block. The block runs until the indentation comes back, including a closing `end` or `}`. The nearest less-indented `class`, `module`, `struct`, `impl` or similar line above names its owner. Specs, tests and folders like `vendor` and `node_modules` are left out.

On this repository the fallback finds 643 methods, against 644 from a Ruby parser.

### The week's batch

The grid shows one **batch** of files a week, like the files the refiners work through. Once it's refined, that's the week's work done: there's no next batch to move on to.

- **Which files** (`Batch.pick`): the first files in an order shuffled for the week, felt or not, from a checksum of the ISO year and week, like `2026-W44`, and each file's path. The batch's methods are shuffled together the same way, so a screen mixes files. The order is random but stays the same through reloads, edits, fixes and restarts until the week changes, so a refined batch stays refined. A file felt in an earlier week can come up again, with its methods blank unless their code has changed.
- **How many** (`Batch.filling`): as many as fill the grid's cells, worked out for the room left by the code box, which is always as tall as it gets until it's expanded, 6 lines of code and a line of how many more, with blank lines below a short method's (`FeelingsRenderer#filled_rows`). So the grid stays the same height, and doesn't scroll, as the selection moves. Files are taken in the week's order, passing over any too big for what's left, with at least one. Expanding the code box takes rows from the grid, which then scrolls to keep the selected method in view, but by then the method's already selected.
- **When it's sized:** when the view first opens. The view can't know the screen's size itself, so nothing is picked until the screen draws it, straight after it opens and before any key. The renderer lays out the cells before anything else, and that first layout picks the batch. `WeeklyBatch` keeps that batch in memory only, until the screen's resized to a grid of a different number of cells. Once the grid's kept its new number for 2 seconds (`WeeklyBatch::RESIZE_SECONDS`), the batch is picked again to fill it, keeping the selected method where it's still in the batch, so dragging the screen's edge doesn't pick a batch for every size it passes through.
- **Progress:** the main pane's side of the line above the panes shows how much of the batch is refined, like `39% refined`. Renderers fill that line with `spacer`, which is blank by default.

`Batch` is plain data: its files, their methods, the log and the week. `WeeklyBatch` holds it, picks it on the first draw and reads its methods again after edits. Both were taken out of `FeelingsView` when it grew past what one class should do.

### Remembering what's been felt

Each feeling is a row in **`.raindown/feelings.csv`**: the date, where the method is, its name, the temper, the note, the commit, and **a checksum of its code** (`CodeMethod#checksum`). The checksum is a CRC of its lines, leaving out indentation, trailing spaces and blank lines.

- **A method counts as felt** when a row matches its file, name and checksum (`FeelingsLog#felt?`). Line numbers are ignored, so a method that moves within its file stays felt.
- **When its code changes,** a method comes back into the grid to be felt again. That's what happens after `x` has Claude Code fix it.
- **Feeling an unchanged method again replaces its row,** as the newest, so only its latest feeling counts.
- **Feelings about code that's changed, or gone, move to `.raindown/memories.csv`** (`FeelingsLog#move_stale_to_memories`), with the same columns. It runs whenever Code feelings reads the code, when it opens and after an edit or a fix, and when a changed method is felt again. So `feelings.csv` only says how the code feels now, and the bins and the README's code debt count only that, while the memories keep the history. It isn't trimmed to the week's batch: a method felt in an earlier week, whose code hasn't changed, stays felt.

Nothing else is stored. Which methods are felt, and so which files a batch picks, comes from the CSV, and a team that commits it shares its progress.

### Counting the feelings

The TUI writes nothing but `.raindown/feelings.csv`. The README counts it instead, with two `Raindown::Stat` nodes in `.raindown`, which the Dashboard shows as cards too. Both use one scale, so they can't disagree:

| frolic | numb | woe | dread | malice |
|---|---|---|---|---|
| 1 | 0.5 | ⅓ | ⅙ | 0 |

Hope, at 0.75 for code that's promising but not a joy, was dropped, and its feelings became numb. Numb is neither good nor bad, and the bad feelings sit evenly below it, woe the mildest, as everywhere else woe's a bad feeling: it asks why, and a fix from it is a fix. **`CodeHealth`** is the feelings' average, to two places, which doesn't grow with the project, labelled with how many feelings it's the average of. **`CodeDebt`** adds up how far each is from numb, (score − 0.5) × 2, from 1 for frolic to −1 for malice, to one place, in debt below zero, labelled with how many fixes there have been: memories whose method's next feeling scored higher. Memories don't count otherwise, as they're about code that's since changed or gone. A chart of the tempers' counts, and a running total of the debt by day, were tried first. An earlier version also wrote a `docs/code-feelings.md` page, with a chart over a `.raindown/tempers.csv` of counts and a table of every feeling, which only repeated what the CSV holds.

### The code box and fixing

The box below the grid shows the selected method's code, **highlighted with Rouge** by its file's name (see the options below). It shows the first 6 lines, then a `[14 more lines]` button. Clicking it, Enter or Space shows as much as fits, and `[Fewer lines]` collapses it again. Lines too long for the box wrap at a space, carrying on at their indent after an ellipsis. Its title is the method's file and line, its name, and how many commits changed its file.

- **`e`** opens the method in your editor, at its line.
- **`x`** runs Claude Code (the `claude` command) with a prompt naming the method, how it last felt and your note. The prompt asks Claude Code to keep the method's behaviour, follow the project's `CLAUDE.md` and run the specs. If `claude` isn't installed, the status line says so.
- **Either way,** the code is read again afterwards. The Navigator no longer writes back every edited file afterwards, only Markdown files the TUI lists, so code edited from here isn't run through Raindown's write-back.

### The mouse

Code feelings is the first view to use mouse **hover**. While the TUI is open, it asks the terminal for "any motion" tracking (`\e[?1003h`) as well as clicks, because older ncurses, like macOS's, doesn't ask every terminal for it. Each movement becomes a `Hover` event carrying whatever a click at that spot would send. Tracking is turned off when the TUI quits, and while the screen is suspended for the editor or Claude Code, so they aren't sent mouse codes.

### Keys

| Key | Does |
|---|---|
| `f` | open Code feelings |
| arrows | move between methods |
| `1` to `5` | feel frolic, numb, woe, dread or malice, best to worst |
| Enter, Space, or a click on "[more lines]" | show all of the method's code that fits, or fewer |
| `e` | edit the method |
| `x` | fix it with Claude Code |
| Tab, or left from the first method | back to the files |

### Options considered

**Finding methods:**

| | Chosen: Universal Ctags, or indentation | Prism | Rubocop | Tree-sitter |
|---|---|---|---|---|
| Languages | over 100 with Ctags, and most code by indentation | Ruby only | Ruby only | one grammar per language |
| Dependency | optional external program, or none | in Ruby | a gem, and it runs per file | native extension and grammars |
| Accuracy | Ctags exact, fallback close | exact | exact, and has complexity metrics | exact |

The first version used Prism, which was dropped because Code feelings is meant to work in any language. Rubocop's complexity metrics would rank drift better, but only for Ruby. Drift uses line counts and `git log` instead, which work the same everywhere.

**Highlighting code:**

| | Rouge (chosen) | ruby_tree_sitter | tree_sitter (Rust) | Commonmarker |
|---|---|---|---|---|
| Download / installed | 531 KB / 1.8 MB | 666–701 KB / 1.6 MB | 3.7–6.4 MB / 10.3 MB | already installed |
| Native code | none | C extension | Rust extension | Rust, already installed |
| Languages included | 233 | none: grammars loaded separately | none: grammars loaded separately | syntect's |
| Prebuilt for Windows | not needed | no | yes | yes |
| Gives the TUI | tokens, as `[text, style]` parts | a syntax tree | a syntax tree | HTML with styled spans |

Rouge is pure Ruby, ships its languages, and runs on every OS and build Raindown ships, including the Tebako binaries. Tree-sitter would need a native grammar per language per platform. Commonmarker only highlights through HTML, which the TUI would have to parse back. Rouge's token names map to six code styles (keyword, string, number, function, constant and comment), with 256-colour, 8-colour and no-colour versions. A fixed set stays within older curses' limit on colour pairs. Rouge also highlights an endpoint's response, in the language of its code block, and the outline's expanded directive bodies, which it lexes as Markdown so each code block gets its own language.

**Order and batches:** file order showed only the first files on screen, because the grid scrolls. A shuffle on every draw would have moved methods under the cursor. A daily shuffle was tried before a weekly one, which fits a week of refining a batch better. Batches of four files were too few to fill a screen. Picking from only the unfelt files, with `n` for the next batch, was dropped: once a batch is refined there should be no more work that week, and a restart would have picked new files.

**What's felt:** appending every feeling counted a re-sorted method twice. A separate store for the batch and progress would have duplicated what the CSV already says.

## Consequences

- **Its code lives in `lib/raindown/tui/feelings/`,** apart from the other views and renderers: its view and renderer, the renderer's bins and code box, the log, the batches, and method snippets. Its specs mirror it in `spec/raindown/tui/feelings/`. The `Highlighter` stays in `lib/raindown/tui/`, as the outline and endpoints use it too.
- **It writes into the project it's run on:** `.raindown/feelings.csv` and `.raindown/memories.csv`. Teams will want to commit them on purpose.
- **Memories depend on finding the same methods.** A feeling moves when its method isn't found with the same file, name and code, so switching between Ctags and the indentation fallback, which can name methods differently, can move feelings that are still true.
- **Rouge is a new runtime dependency** (`~> 5.1`). It's pure Ruby, so installing Raindown still needs no native code beyond curses. It takes about a third of a second to load, so the TUI loads it as it starts, rather than whenever Raindown is required, since nothing else highlights code.
- **Universal Ctags and Claude Code are optional.** Without Ctags, the indentation fallback is rougher for code that isn't indented in blocks. Without Claude Code, `x` only shows a message.
- **What's been tested:** the views, renderers, batches, log, method finding and highlighting have specs that need no terminal. The real Ctags JSON was only tested from sample output. Hover, mouse tracking, colours and the code box in a real terminal were checked by rendering, not by hand.
- **Batch size isn't saved.** It depends on the screen the TUI first draws on, so a bigger terminal takes more of the week's order, and a smaller one fewer.
- **`Row` gained a `code` field** for highlighted parts, and the renderers gained `Text#code_segments`, `Text#wrap` and the `spacer` line, which other views can use.

## Later

- **Alternate shading** for neighbouring methods, so clusters show their edges without the cursor.
- **Daily team quotas** from the same CSV, with a bar per person on the Dashboard.
