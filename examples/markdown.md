# Raindown Example

Run `raindown examples/markdown.md` and edit this file to see `examples/markdown.html` update on save.

<{ toc: }>

- [Raindown Example](#raindown-example)
  - [Directives](#directives)
  - [Alerts](#alerts)
  - [Markdown](#markdown)
    - [Nested heading](#nested-heading)

<{ :toc }>

## Directives

Raindown directives sit between `<{` and `}>`. The table of contents above comes from:

```
<{ toc: }>
<{ :toc }>
```

It writes a list of every heading into this file between the two, kept in sync as you edit, and renders a table of contents in the HTML. Use `<{ :toc }>` for the HTML one alone. Directives inside code are left as-is, so the block above shows the directive instead of rendering it.

## Alerts

> [!NOTE]
> GitHub-style alerts are enabled.

> [!WARNING]
> Headings will appear in the table of contents.

## Markdown

Regular Markdown works as usual:

- **Bold**, *italic* and `code`
- [Links](https://github.com/raindeer-rb/raindown)

| Command | Description       |
| ------- | ----------------- |
| render  | Render once       |
| watch   | Re-render on save |

### Nested heading

Deeper headings are listed in the table of contents too.
