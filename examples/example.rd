# Raindown Example

Run `raindown watch examples/example.rd` and edit this file to see `examples/example.html` update on save.

This is a Raindown file (`.rd`), so directives can be written bare on their own line.

:toc

<!-- raindown:toc -->
- [Raindown Example](#raindown-example)
  - [Directives](#directives)
  - [Alerts](#alerts)
  - [Markdown](#markdown)
    - [Nested heading](#nested-heading)
<!-- /raindown:toc -->

## Directives

In a `.rd` file a directive on its own line needs no delimiters. The table of contents above comes from:

```
:toc
```

It lists every heading in the file and stays in sync as you edit. Directives inside code are left as-is, so the block above shows the directive instead of rendering it. `<{ :toc }>` works too, and is the only form `.md` files understand.

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
