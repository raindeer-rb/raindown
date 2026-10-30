## 2026-10-30T07:59:19Z · diagram

```diagram
                                    raindown CLI
                                (Trees, flags as keywords)
                                           │
        ┌──────────────────────────────────┼──────────────────────────────────┐
        │                                  │                                  │
  raindown [PATH]                 raindown watch [PATH]          raindown FILE --html / --stdin
  terminal UI (default)           no UI                          render once
  no terminal? watches instead    Watcher::Supervisor (folder)   PreRenderer → Commonmarker
        │                         Watcher::FileWatcher (file)    → HTML to stdout or a file
        │                                  │                     (VS Code preview: --stdin)
        │                                  │
        ▼                                  ▼
╭──────────────────────────────╮   ╭─────────────────────────────────╮
│  TUI                         │   │  Watching                        │
│                              │   │                                  │
│  Screen  ── curses, 12 fps ──│   │  Watcher.listen (Listen, skips   │
│    │ keys, clicks, hover     │   │  node_modules, build, tmp…)      │
│    ▼                         │   │     │ saved / added / removed    │
│  Navigator                   │   │     ▼                            │
│    ├─ files · endpoints      │   │  Watcher.changes                 │
│    ├─ pages: 📊 Dashboard    │   │     ├─ nodes changed → restart   │
│    │         🎭 Feelings     │   │     └─ Markdown saved → update   │
│    │         📐 Diagrams     │   │     │  (a thread per project)    │
│    ├─ views → Renderers      │   ╰─────┼────────────────────────────╯
│    │  → Layout (one frame)   │         │
│    └─ Saves ── Watcher.listen│         │
│         (queued, each tick)  │         │
╰──────────────┬───────────────╯         │
               │                         │
               ▼                         ▼
       ╭────────────────────────────────────────────────╮
       │  Workers: a process per project (fork)         │
       │  each loads its own .raindown nodes, so two    │
       │  projects' nodes of the same name stay apart   │
       │                                                │
       │   TUI::Project            Watcher::Project      │
       │   outline · charts ·      update(path)          │
       │   endpoints · write_back                        │
       ╰───────────────────────┬────────────────────────╯
                               ▼
               ╭───────────────────────────────╮
               │  Rewriter                      │
               │  Document → directives <{ }>   │
               │   toc · files · tables ·       │
               │   chart · stat · endpoint ·    │
               │   project nodes (LowNode,      │
               │   Antlers)                     │
               │  --bare  → bare directives     │
               │  -x      → run empty endpoints │
               ╰───────────────┬───────────────╯
                               ▼
                   README.md  docs/*.md  *.rd
                   written back on save, then the
                   save of that changes nothing

   .raindown/
   ├─ config.yml · nodes (*.rb, *.rbx)
   ├─ feelings.csv · memories.csv ◀── Code feelings (1–5)
   │       └──▶ CodeHealth / CodeDebt stats ──▶ README
   └─ diagrams.md ◀── raindown diagrams ◀── Claude Code Stop hook
           └──▶ 📐 Diagrams page
```

## 2026-10-30T08:38:56Z · mockup

```mockup
──────────────────────────┬────────────────────── Directive Zoo ────────────────
                          │   ┌─ TOC ──────┐  ┌─ Chart ────┐  ┌─ CodeDebt ─┐
                          │   │  (\_/)     │  │   ▁▃▅█     │  │   $ $ $    │
                          │   │  (o.o)     │  │   grazing  │  │   hoarding │
                          │   │ seen 12×   │  │ seen 8×    │  │ seen 1×    │
                          │   └────────────┘  └────────────┘  └────────────┘
                          │   ┌─ Shout ────┐  ┌─ endpoint ─┐  ┌─ ??? ──────┐
                          │   │  \(O)/     │  │  ~~~>      │  │   empty    │
                          │   │  LOUD      │  │ restless   │  │ "Greeting" │
                          │   │ seen 2×    │  │ seen 5×    │  │ escaped!   │
                          │   └────────────┘  └────────────┘  └────────────┘
                          │   Please don't feed the bare directives.
```

## 2026-10-30T10:12:56Z · mockup

```mockup
 2 of 2 · 2026-10-30 08:38 UTC · mockup · main @ 8b61e6f
 files: lib/raindown/tui.rb · spec/raindown/tui_spec.rb   +2 commits since
```

## 2026-10-30T11:28:33Z · mockup

```mockup
╭──────────────────────────────╮   ╭─────────────────────────────────╮
│  TUI                         │   │  Watching                        │
│  Screen  ── curses, 12 fps ──│   │  Watcher.listen (Listen, skips   │
│    │ keys, clicks, hover     │   │  node_modules, build, tmp…)      │
│    ▼                         │   │     ▼                            │
│  Navigator                   │   │  Watcher.changes                 │
│    └─ Saves ── Watcher.listen│   │     └─ Markdown saved → update   │
╰──────────────┬───────────────╯   ╰─────┬───────────────────────────╯
               ▼                         ▼
       ╭────────────────────────────────────────────────╮
       │  Workers: a process per project (fork)         │
       ╰────────────────────────────────────────────────╯
```

## 2026-10-30T11:28:33Z · mockup

```mockup
╭──────────────────────────────╮   ╭─────────────────────────────────╮
│                              │   │                                  │
│  def take_events(drawn_at) ──│   │  def self.listen(directory, &)   │
│    │                         │   │                                  │
│    ▼                         │   │     ▼                            │
│  def next_step(event)        │   │  def self.changes(paths, root: … │
│    └─ def take = Array.new(… │   │     └─                           │
╰──────────────┬───────────────╯   ╰─────┬───────────────────────────╯
               ▼                         ▼
       ╭────────────────────────────────────────────────╮
       │  def for(path) = self[Projects.root(path) || r…│
       ╰────────────────────────────────────────────────╯
```

