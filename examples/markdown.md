---
raindown: true
---

# Raindown Example

Run `raindown examples/markdown.md` and edit this file to see Raindown write back to it on save, or add `--html examples/markdown.html` to render it.

This is a Markdown file (`.md`) with `raindown: true` front matter, so its directives could also be written bare on their own line, like in a Raindown file. Here they sit between `<{` and `}>`.

<{ toc: }>

- [Raindown Example](#raindown-example)
  - [Directives](#directives)
  - [Charts](#charts)
    - [Commits](#commits)
  - [Endpoints](#endpoints)
  - [Tables](#tables)
    - [Nested heading](#nested-heading)

<{ :toc }>

## Directives

Raindown directives sit between `<{` and `}>`. The table of contents above comes from:

```
<{ toc: }>
<{ :toc }>
```

It writes a list of every heading into this file between the two, kept in sync as you edit, and renders a table of contents in the HTML. Use `<{ :toc }>` for the HTML one alone. Directives inside code are left as-is, so the block above shows the directive instead of rendering it.

## Charts

A `chart:` directive draws its data in block characters, and writes the chart below it, redrawn whenever the file is rendered. Labeled data like `data/downloads.csv` draws as bars:

<{ chart: 'data/downloads.csv' width: 30 }>

```
Jun  ██████▊                          640
Jul  █████████████                  1,240
Aug  ████████████████████▊          1,980
Sep  ███████████████████████▏       2,210
Oct  ██████████████████████████████ 2,870
```

<{ :chart }>

Numbers alone draw as a sparkline:

<{ chart: '3 5 2 8 6 9 4 7' }>

```
▂▄▁▇▅█▃▆
```

<{ :chart }>

### Commits

`minus:` charts a column against the values, like the lines each commit deleted against the lines it added:

<{ chart: 'data/commits.csv' minus: 'deleted' width: 30 }>

```
c2f98fc  -18  █│███▊                           +96
b1a573a   -0   │▏                               +1
b737205  -11  ▐│██▍                            +62
1cd92fb   -5  ▕│████████████████████████████▏ +717
69ce897  -47 ██│█████▊                        +146
```

<{ :chart }>

## Endpoints

An `endpoint:` directive runs the curl snippet below it and writes the response in the code block below that. Empty the response block and save to fetch a new one.

<{ endpoint: :x }>

```sh
curl https://httpbin.org/uuid
```

```json
{
  "uuid": "359ecfa4-a344-46fe-bbe4-c12dea7d4541"
}
```
<!-- raindown:fetched 2026-10-26 -->
<{ :endpoint }>

## Tables

Tables auto-expand their column widths on save to match the content.

| Command | Description       |
| ------- | ----------------- |
| render  | Render once       |
| watch   | Re-render on save |

### Nested heading

Deeper headings are listed in the table of contents too.
