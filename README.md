<a href="https://rubygems.org/gems/raindown" title="Install gem"><img src="https://badge.fury.io/rb/raindown.svg" alt="Gem version" height="18"></a> <a href="https://github.com/raindeer-rb/raindown" title="GitHub"><img src="https://img.shields.io/badge/github-%23121011.svg?style=for-the-badge&logo=github&logoColor=white" alt="GitHub repo" height="18"></a> <a href="https://codeberg.org/Iow/raindown" title="Codeberg"><img src="https://img.shields.io/badge/Codeberg-2185D0?style=for-the-badge&logo=Codeberg&logoColor=white" alt="Codeberg repo" height="18"></a>

# Raindown

Raindown is a Markdown superset for AI, APIs, Docs and humans.

<{ Commits: limit=5 }>

```
ecf65be   -6        █│█▊                       +14
3e2c2ab   -0         │████████████████████    +163
5021033  -60 ▐███████│██████████████████████▋ +184
913fa60   -1        ▕│█                         +8
69ce897  -47   ██████│██████████████████      +146
```

<{ :Commits }>

## CLI

The gem ships a `raindown` executable that watches Markdown files and writes back to them as they're saved, like their tables of contents, tables and endpoint responses.

```sh
# Watch every project with a .raindown folder in the current directory, or in another one:
raindown
raindown ~/dev

# Watch one file:
raindown README.md

# Render to HTML once, to stdout or to a file:
raindown README.md --html
raindown README.md --html site/index.html

# Render Markdown from stdin without touching the file (for editor previews):
cat draft.rd | raindown draft.rd --stdin

# Browse a project's files and their outlines in the terminal:
raindown tui
raindown tui README.md
```

With `--stdin`, FILE only decides whether bare directives are allowed (by its extension), so it doesn't need to exist yet, and the TOC and tables aren't written back to it.

Watching a directory watches each project in it, a folder with a `.raindown` folder, and the Markdown files below it, skipping hidden folders and ones like `node_modules` and `build`. Each project's nodes load in a process of their own, so two projects can have nodes of the same name, and saving one of a project's nodes reloads them. Files are written back as they're saved, not all at once when watching starts.

`raindown tui` shows a project's Markdown files beside an outline of the open file's headings and directives. Arrow keys or `j`/`k` move, Tab switches pane, and Enter opens a file or folds a heading. On a directive, Enter shows the lines it wrote back, `x` (or its `[Run]` button) runs an endpoint, and `e` opens your `$EDITOR` at the selected line, then writes back to the file when you close it. The mouse works too.

### Directives

Directives sit between `<{` and `}>`, and come in two kinds:

|                       | Template directives                                 | Content directives                                                    |
| --------------------- | --------------------------------------------------- | --------------------------------------------------------------------- |
| Examples              | `for:`, `if:`, `list:` and variables like `{title}` | `toc:`, `:toc`, `files:`, `chart:`, `endpoint:` and your own nodes    |
| What they do          | Shape how the Markdown around them renders          | Bring content into the page, written into the file, the HTML, or both |
| Who writes the output | You, as a template                                  | Raindown or your node, from your input                                |
| Where they sit        | Often inside paragraphs, tables and lists           | On their own lines, between blocks                                    |
| In the HTML           | Invisible, since the input is a template            | In bold, or as comments with `hide_directives`                        |

#### Template directives

Shape how the Markdown around them renders, like Liquid or Jinja: [variables](#variables) like `{title}`, loops with `for:`, conditions with `if:` and [lists](#files-and-lists) with `list:`. You write their output as a template, and they decide whether it appears and how many times, filling in values like `{title}`. They're invisible in the HTML, since the input is a template, and showing them would break the tables and lists they often sit in.

#### Content directives

Bring content into the page: a [table of contents](#table-of-contents) with `toc:` and `:toc`, [files](#files-and-lists) with `files:`, [charts](#charts) with `chart:`, [endpoints](#endpoints) with `endpoint:` and your own [nodes](#nodes). Raindown or your node writes their output, and you only give them input, like `folder: 'notes'` or an endpoint's curl snippet. Most also write their content into the Markdown below them, so it's there for people and agents reading the file. They sit on their own lines between content blocks, and show in bold in the HTML, so you can see where a page's content comes from, unless you [hide them](#config).

### Raindown files

Raindown is a superset of Markdown. Give a file the `.rd` or `.raindown` extension and a directive on its own line no longer needs delimiters:

```
# Notes

:toc
```

Bare directives have no end tags. A block directive like `if:` or `for:` applies to the Markdown block below it, up to the next blank line:

```
if: draft
This is a draft.
```

When a block needs to hold more than that, like several paragraphs, write it with delimiters and an end tag, which works in `.md` and `.rd`:

```
<{ if: draft }>
This is a draft.

It has two paragraphs.
<{ :if }>
```

Directives in prose or code are left as text.

Markdown files can opt in too, with `raindown: true` in their front matter:

```md
---
raindown: true
---

# Notes

:toc
```

Or with the `--bare` flag:

```sh
raindown README.md --bare
```

### Table of contents

`<{ :toc }>` renders a table of contents of the file's headings in the HTML.

A `<{ toc: }>` block does that too, and also writes the table of contents into the Markdown below it as a list of links, updated whenever the file is rendered. That way people and agents reading the file see it as well:

```md
<{ toc: }>

- [Notes](#notes)
  - [Setup](#setup)

<{ :toc }>
```

The block needs `<{ :toc }>` after it. In a [Raindown file](#raindown-files) it can be a bare `toc:` with the list straight below it, and `:toc` on its own is always the HTML table of contents.

`toc:` and `:toc` are a [node](#nodes), so a project can change them with its own `TOC` node, like `class TOC < Raindown::TOC`.

### Files and lists

A `files:` block writes a link to each file in a folder, by its title, into the Markdown, and renders them as a list in the HTML:

```md
<{ files: folder: 'notes' }>

- [Getting started](docs/_notes/_1-getting-started.md)
- [Setup](docs/_notes/_2-setup.md)

<{ :files }>
```

The files come from the [metadata](#metadata) of your project's Markdown files. `files:` is a [node](#nodes) too, so a project can list files its own way with a `Files` node that overrides `replace` or adds `render`, like `class Files < Raindown::Files`, where `files(metadata:)` gives each file's front matter, `path` and `content`.

To render the files with your own template instead, use a `list:` block. Its template repeats for each file, and only renders in the HTML:

```md
<{ list: page folder: 'notes' }>
## {page.title}
<{ :list }>
```

### Metadata

`files:` and `list:` list the Markdown files in your project by their metadata. The project is the folder with your [`.raindown`](#nodes) folder, or else the folder of the file being rendered.

A file's front matter is its metadata, and a list like `tags: [ruby, intro]` tags it with each item:

```md
---
title: Getting started
tags: [ruby, intro]
---
```

Underscored folders in a file's path are metadata too. `docs/_basics/_1-getting-started.md` has:

```yaml
folder: basics
order: 1
path: docs/_basics/_1-getting-started.md
```

The `path` is relative to the project, so the links `files:` writes work in the Markdown, like on GitHub.

Files are listed by `order`, and separate several folder tags with `&`, like `docs/_1&_basics/getting-started.md`. Filter by any of them, with quoted values, since unquoted ones are front matter keys:

```md
files: folder: 'basics'

files: tags: 'intro'
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

### Charts

A `chart:` block draws its data as a chart in block characters, and writes it into the Markdown below it as a code block, redrawn whenever the file is rendered:

````md
<{ chart: 'data/downloads.csv' }>

```
Jan  ██████████████████████▌                  1,240
Feb  ███████████████████████████████████▉     1,980
Mar  ████████████████████████████████████████ 2,210
Apr  ███████████████▊                           870
```

<{ :chart }>
````

Its data can be a CSV, TSV, JSON or YAML file relative to the project, numbers like `chart: '3 5 -2 8'`, or a [variable](#variables) like `chart: stats`. A variable can hold either of those, or data of its own like a list of numbers or a hash of labels and values. A table's labels come from its first column and its values from the first column of numbers after it, or name them with `label:` and `value:`, like `value: 'sales'`.

`format:` draws it as `'bars'`, `'columns'`, a `'line'` or a `'sparkline'` (`▂▄▁▇▅█▃`). Without it, labeled data draws as bars and numbers alone as a sparkline. Negative values go below the line, or left of it for bars:

```
chart: 'data/profit.csv' width: 30
```
```
Jan              │██████████▉          1,200
Feb         ▕████│                      -450
Mar              │███████▎               800
Apr  ████████████│                    -1,300
May              │██████████████████▏  2,000
```

A line is drawn in braille, where each character has dots 2 across and 4 down, and shows the labels that fit below it:

```
chart: 'data/profit.csv' format: 'line' height: 6
```
```
 2,000 ┤                                       ⡠⠊
       │ ⢄⡀                                  ⢀⠔⠁
       │  ⠈⠑⠢⢄           ⢀⡠⠔⠊⠑⠤⡀           ⢀⠔⠁
     0 ┼──────⠉⠒⠤⣀───⣀⠤⠒⠉⠁─────⠈⠢⢄────────⡠⠊─────
       │          ⠉⠒⠉             ⠑⠢⡀   ⡠⠊
-1,300 ┤                            ⠈⠒⢄⠔⠁
         Jan      Feb       Mar      Apr      May
```

`minus:` names a column to chart against the values, like lines deleted against lines added. It goes left of the line for bars, below it for columns and sparklines, and as a second line below zero for a line:

```
chart: 'data/commits.csv' minus: 'deleted' width: 30
```
```
a8bb4fa  -44 ██│█████████▉                    +250
d6114e0  -11  ▐│▍                              +11
b12a47e   -4  ▕│▋                              +15
35cfe8c  -11  ▐│██▌                            +62
1f8ff0e   -5  ▕│████████████████████████████▎ +717
```

Bars and lines are 40 characters wide, and columns and lines 8 lines high, which `width:` and `height:` change.

`chart:` is a [node](#nodes), so a project can draw charts its own way with a `Chart` node, like `class Chart < Raindown::Chart`. Raindown only watches the file being rendered, so after changing a chart's data, save the file to redraw it.

### Endpoints

Put an `endpoint:` directive above a curl snippet and Raindown writes the response in a code block below it, typed by its content type, followed by the date it was fetched:

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
<!-- raindown:fetched 2026-10-14 -->
<{ :endpoint }>
````

In a [Raindown file](#raindown-files) you can write `endpoint: :x` bare, which ends after the curl snippet and response, so there's no `<{ :endpoint }>`.

The request only runs when the response block is missing or empty, and either the directive has `:x` (or `:execute`) or you pass `-x` (or `--execute`):

```sh
raindown api.md -x
```

To refresh a response, empty its code block, and its fetched date is updated too. The date is an HTML comment, so it's hidden on the page, but anyone reading the file or the HTML source, people or agents, can tell how fresh the example is. The snippet runs with the `curl` binary but not through a shell, so pipes, redirects and `$VARIABLES` aren't supported. Curl is limited to HTTP requests, values can't read files (`-d @body.json`), and other options like `-o`, `-F` or `-K` are rejected. Raindown also runs curl without your `~/.curlrc`.

### Nodes

Nodes are your own [LowNodes](https://github.com/low-rb/lownode) that write Markdown into the file with `replace`, and render HTML into the page with `render`. Put them in a `.raindown` folder beside your files, or in a folder above them, and Raindown loads them with [Dirload](https://github.com/low-rb/dirload):

```ruby
# .raindown/changelog.rb
class Changelog < LowNode
  def initialize(limit: 5)
    @releases = Release.all.first(limit)
  end

  # Written into the Markdown.
  def replace
    @releases.map { |release| "- **#{release.version}** #{release.summary}" }.join("\n")
  end

  # Rendered into the HTML. Without it, the HTML of the Markdown above is rendered.
  def render
    "<section class=\"changelog\">...</section>"
  end
end
```

A node block names the node and its props, and Raindown writes the node's Markdown into it whenever the file is rendered:

```md
<{ Changelog: limit=3 }>

- **1.2.0** Bare directives close themselves
- **1.1.0** Track fetched dates

<{ :Changelog }>
```

In a [Raindown file](#raindown-files) it can also use bare syntax, with the Markdown straight below it up to the next blank line (a bare node block can't write blank new lines):

```
Changelog: limit=3
- **1.2.0** Bare directives close themselves
- **1.1.0** Track fetched dates
```

Props can be quoted text, numbers, `true`, `false` or [variables](#variables) like `author.name`, written `limit=3` or `limit: 3`. A variable is the data it holds, so a list stays a list. A value before the props, like `'data.csv'` in `chart: 'data.csv' format: 'columns'`, is passed to the node's `initialize` as its argument. `replace` and `render` can also take the keywords `document:` (the Markdown being rendered), `metadata:` and `bare:`, and get the ones they ask for. A self-closing `<{ :Changelog }>`, or a bare `:Changelog`, renders the node into the HTML without writing it into the file. Raindown keeps one instance of each node and its props while it runs, so `replace` and `render` can share what they work out, like the releases above. A name only starts a node block when it's a loaded LowNode with a `replace` method, so other text like `Note:` is left alone. Nodes run your project's code whenever Raindown renders the file.

### Config

A project can keep settings in `config.yml` in its [`.raindown`](#nodes) folder.

[Content directives](#directives) like `toc:`, `files:`, a node's or an endpoint's show in bold in the HTML, so you can see where a page's content comes from. Hide them as HTML comments with:

```yaml
# .raindown/config.yml
hide_directives: true
```

Template directives are always invisible in the HTML.

Code blocks are highlighted in the HTML. For a site that highlights code in the browser instead, like with [Prism](https://prismjs.com), turn it off and each code block gets a language class, like `<pre><code class="language-ruby">`:

```yaml
# .raindown/config.yml
highlight_code: false
```

### VS Code

The [VS Code extension](vscode/) highlights syntax and previews Raindown files with `--stdin`, rendering as you type. In Markdown files it highlights `<{ }>` directives and renders them in the built-in Markdown preview.

### Standalone binaries

Each [GitHub release](https://github.com/raindeer-rb/raindown/releases) has a standalone `raindown` executable for macOS, Linux (glibc and musl) and Windows, built with [Tebako](https://github.com/tamatebako/tebako). Ruby is bundled inside, so nothing else needs to be installed, except on Alpine and other musl distros, which need `libgcc` and ncurses (`apk add libgcc ncurses-libs`). Other Linux binaries use the system's ncurses, which most distros include.

To build one for your own machine, [install Tebako](https://github.com/tamatebako/tebako#installation) and run:

```sh
bundle exec rake tebako  # writes pkg/raindown-<version>-<platform>
```
