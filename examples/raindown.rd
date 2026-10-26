# Raindown Example

Run `raindown examples/raindown.rd` and edit this file to see `examples/raindown.html` update on save.

This is a Raindown file (`.rd`), so directives can be written bare on their own line.

toc:
- [Raindown Example](#raindown-example)
  - [Directives](#directives)
  - [Charts](#charts)
    - [Commits](#commits)
  - [Endpoints](#endpoints)
  - [Tables](#tables)
    - [Nested heading](#nested-heading)

## Directives

In a `.rd` file a directive on its own line needs no delimiters. The table of contents above comes from:

```
toc:
```

It writes a list of every heading into this file, kept in sync as you edit, and renders a table of contents in the HTML. Use `:toc` for the HTML one alone. Directives inside code are left as-is, so the block above shows the directive instead of rendering it. `<{ toc: }>` works too with a `<{ :toc }>` end tag, and is the only form `.md` files understand.

## Charts

A `chart:` directive draws its data in block characters, and writes the chart below it, redrawn whenever the file is rendered. Labeled data like `data/downloads.csv` draws as bars:

chart: 'data/downloads.csv' width: 30
```
Jun  ██████▊                          640
Jul  █████████████                  1,240
Aug  ████████████████████▊          1,980
Sep  ███████████████████████▏       2,210
Oct  ██████████████████████████████ 2,870
```

Numbers alone draw as a sparkline:

chart: '3 5 2 8 6 9 4 7'
```
▂▄▁▇▅█▃▆
```

### Commits

`minus:` charts a column against the values, like the lines each commit deleted against the lines it added:

chart: 'data/commits.csv' minus: 'deleted' width: 30
```
c2f98fc  -18  █│███▊                           +96
b1a573a   -0   │▏                               +1
b737205  -11  ▐│██▍                            +62
1cd92fb   -5  ▕│████████████████████████████▏ +717
69ce897  -47 ██│█████▊                        +146
```

## Endpoints

An `endpoint:` directive runs the curl snippet below it and writes the response in the code block below that. Empty the response block and save to fetch a new one.

endpoint: :x

```sh
curl https://httpbin.org/uuid
```

```json
{
  "uuid": "3ca20551-9df0-4f92-8710-8e8df2ab9e85"
}
```
<!-- raindown:fetched 2026-10-26 -->

## Tables

Tables auto-expand their column widths on save to match the content.

| Command | Description       |
| ------- | ----------------- |
| render  | Render once       |
| watch   | Re-render on save |

### Nested heading

Deeper headings are listed in the table of contents too.
