# Raindown Example

Run `raindown examples/raindown.rd` and edit this file to see `examples/raindown.html` update on save.

This is a Raindown file (`.rd`), so directives can be written bare on their own line.

toc:

- [Raindown Example](#raindown-example)
  - [Directives](#directives)
  - [Endpoints](#endpoints)
  - [Alerts](#alerts)
  - [Markdown](#markdown)
    - [Nested heading](#nested-heading)

## Directives

In a `.rd` file a directive on its own line needs no delimiters. The table of contents above comes from:

```
toc:
```

It writes a list of every heading into this file, kept in sync as you edit, and renders a table of contents in the HTML. Use `:toc` for the HTML one alone. Directives inside code are left as-is, so the block above shows the directive instead of rendering it. `<{ toc: }>` works too, and is the only form `.md` files understand.

## Endpoints

An `endpoint:` directive runs the curl snippet below it and writes the response in the code block below that. Empty the response block and save to fetch a new one.

endpoint: :x

```sh
curl https://httpbin.org/uuid
```

```json
{
  "uuid": "09808426-f717-497f-a2fb-5d25a8ba8761"
}
```

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
