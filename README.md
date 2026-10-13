<a href="https://rubygems.org/gems/raindown" title="Install gem"><img src="https://badge.fury.io/rb/raindown.svg" alt="Gem version" height="18"></a> <a href="https://github.com/raindeer-rb/raindown" title="GitHub"><img src="https://img.shields.io/badge/github-%23121011.svg?style=for-the-badge&logo=github&logoColor=white" alt="GitHub repo" height="18"></a> <a href="https://codeberg.org/Iow/raindown" title="Codeberg"><img src="https://img.shields.io/badge/Codeberg-2185D0?style=for-the-badge&logo=Codeberg&logoColor=white" alt="Codeberg repo" height="18"></a>

# Raindown

Raindown is a templating layer for static site generation and an annotation framework for Markdown files.

## CLI

The gem ships a `raindown` executable that renders a Markdown file (including directives like `<{ :toc }>`) to HTML, then re-renders it every time the file is saved.

```sh
# Write to README.html beside README.md:
raindown README.md

# Write to another path:
raindown README.md -o site/index.html

# Render once without watching, to stdout or with -o to a file:
raindown README.md --once

# Render Markdown from stdin without touching the file (for editor previews):
cat draft.rd | raindown draft.rd --stdin
```

With `--stdin`, FILE only decides whether bare directives are allowed (by its extension), so it doesn't need to exist yet, and the TOC and tables aren't written back to it.

### Raindown files

Raindown is a superset of Markdown. Give a file the `.rd` or `.raindown` extension and a directive on its own line no longer needs delimiters:

```
# Notes

:toc
```

Directives in prose or code are left as text, and `<{ :toc }>` still works.

Markdown files can opt in too, with the `--bare` flag:

```sh
raindown README.md --bare
```

### Variables

Front matter keys are variables, which render with `{key}`, or `<{ key }>` to leave HTML unescaped:

```md
---
title: Release notes
author:
  name: Mark
tags: [ruby, markdown]
draft: false
---

{title}

{author.name}

<{ for: tag in: tags }>
- {tag}
<{ :for }>

<{ if: draft }>
This is a draft.
<{ :if }>
```

Variables, loops and conditions render before the Markdown does, like Liquid in Jekyll. So a loop's lines make one list or table, and a value can contain Markdown like `*emphasis*`. Unknown variables render nothing, and variables in code are left as text.

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
<{ :endpoint }>
````

In a [Raindown file](#raindown-files) you can write `endpoint: :x` bare and leave out `<{ :endpoint }>`, which is added after the curl snippet and response.

The request only runs when the response block is missing or empty, and either the directive has `:x` (or `:execute`) or you pass `-x` (or `--execute`):

```sh
raindown api.md -x
```

To refresh a response, empty its code block. The snippet runs with the `curl` binary but not through a shell, so pipes, redirects and `$VARIABLES` aren't supported. Curl is limited to HTTP request, values can't read files (`-d @body.json`), and other options like `-o`, `-F` or `-K` are rejected. Raindown also runs curl without your `~/.curlrc`.

### VS Code

The [VS Code extension](vscode/) highlights syntax and previews Raindown files with `--stdin`, rendering as you type. In Markdown files it highlights `<{ }>` directives and renders them in the built-in Markdown preview.

### Standalone binaries

Each [GitHub release](https://github.com/raindeer-rb/raindown/releases) has a standalone `raindown` executable for macOS, Linux (glibc and musl) and Windows, built with [Tebako](https://github.com/tamatebako/tebako). Ruby is bundled inside, so nothing else needs to be installed.

To build one for your own machine, [install Tebako](https://github.com/tamatebako/tebako#installation) and run:

```sh
bundle exec rake tebako  # writes pkg/raindown-<version>-<platform>
```
