# Raindown Example

Run `raindown watch examples/example.md` and edit this file to see `examples/example.html` update on save.

<{ :toc }>

<!-- raindown:toc -->
- [Raindown Example](#raindown-example)
  - [Directives](#directives)
  - [Alerts](#alerts)
  - [Markdown](#markdown)
    - [Nested heading](#nested-heading)
<!-- /raindown:toc -->

## Directives

Raindown directives sit between `<{` and `}>`. The table of contents above comes from:

```
<{ :toc }>
```

It lists every heading in the file and stays in sync as you edit. Directives inside code are left as-is, so the block above shows the directive instead of rendering it.

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
