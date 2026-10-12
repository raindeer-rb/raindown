<a href="https://rubygems.org/gems/raindown" title="Install gem"><img src="https://badge.fury.io/rb/raindown.svg" alt="Gem version" height="18"></a> <a href="https://github.com/raindeer-rb/raindown" title="GitHub"><img src="https://img.shields.io/badge/github-%23121011.svg?style=for-the-badge&logo=github&logoColor=white" alt="GitHub repo" height="18"></a> <a href="https://codeberg.org/Iow/raindown" title="Codeberg"><img src="https://img.shields.io/badge/Codeberg-2185D0?style=for-the-badge&logo=Codeberg&logoColor=white" alt="Codeberg repo" height="18"></a>

# Raindown

Raindown is a templating layer for static site generation and an annotation framework for Markdown files.

## CLI

The gem ships a `raindown` executable for rendering a Markdown file (including directives like `<{ :toc }>`) to HTML from the command line.

```sh
# Render once and print to stdout:
raindown render README.md

# Render once and write to a file:
raindown render README.md -o README.html

# Watch and render every time the file is saved:
raindown watch README.md -o README.html
```

### Raindown files

Raindown is a superset of Markdown. Give a file the `.rd` or `.raindown` extension and a directive on its own line no longer needs delimiters:

```
# Notes

:toc
```

Directives in prose or code are left as text, and `<{ :toc }>` still works.

Markdown files can opt in too, with the `--bare` flag:

```sh
raindown render README.md --bare
```

Or with `bare: true` in the front matter:

```
---
bare: true
---
```

### Endpoints

Put an `endpoint:` directive above a curl snippet and Raindown writes the response in a code block below it, typed by its content type:

````md
<{ endpoint: :x }>

```sh
curl https://httpbin.org/uuid
```

```json
{
  "uuid": "4c9d6a2e-…"
}
```
````

The request only runs when the response block is missing or empty, and either the directive has `:x` (or `:execute`) or you pass `-x` (or `--execute`):

```sh
raindown render api.md -x
```

To refresh a response, empty its code block. The snippet runs with the `curl` binary but not through a shell, so pipes, redirects and `$VARIABLES` aren't supported.

### Standalone binaries

Each [GitHub release](https://github.com/raindeer-rb/raindown/releases) has a standalone `raindown` executable for macOS, Linux (glibc and musl) and Windows, built with [Tebako](https://github.com/tamatebako/tebako). Ruby is bundled inside, so nothing else needs to be installed.

To build one for your own machine, [install Tebako](https://github.com/tamatebako/tebako#installation) and run:

```sh
bundle exec rake tebako  # writes pkg/raindown-<version>-<platform>
```
