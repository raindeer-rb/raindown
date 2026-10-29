# TODO

## Endpoint `:x` on untrusted files

An `endpoint: :x` directive with an empty response block runs its request as soon as `raindown file.rd` or `--once` starts, with no `-x` flag needed. Snippets can only make HTTP(S) requests, but the request still goes out from the machine running raindown, so a file someone else wrote (a cloned repo, a PR, a file an agent wrote) can reach localhost, internal APIs or cloud metadata (`169.254.169.254`), and the response is written into the file.

Reading a file, and the VS Code preview (`--stdin`), never run endpoints.

Options:

1. **Leave it as it is.** `:x` is the author's opt-in and the worst case is one HTTP request, the same trust as running `make` or `npm run` in a repo you haven't read. Maybe document it in the README.
2. **Block private addresses unless `-x` is passed.** Refuse loopback, private and link-local addresses (`localhost`, `127.0.0.0/8`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `169.254.0.0/16`, `::1`, `fc00::/7`, `fe80::/10`) when only `:x` is set. Needs the hostname resolved first, and `-L` redirects to a private address checked too.
3. **Ignore `:x` in files.** Only run endpoints when `-x` is passed, so whoever runs raindown decides. Simplest and safest, but loses per-endpoint opt-in.
4. **Ask before running.** When a file's `:x` would run a request, print the curl command and ask for confirmation, unless `-x` is passed. Doesn't work in CI or editors without a terminal.

## Endpoint response freshness

A response only refreshes when its code block is emptied, so once written it stays, and a year-old response looks the same as one fetched today. Readers, and agents especially, can't tell whether an example still holds. Responses now record the date they were fetched (`<!-- raindown:fetched 2026-10-14 -->`), but nothing checks they still match.

**Check mode.** `raindown file.rd --check` re-runs every endpoint without writing, and exits non-zero listing the responses that no longer match, for CI. Needs a way to ignore fields that change every request (ids, timestamps), for example an `ignore:` list on the directive or a JSON path list.

## Code feelings

Ideas for the feelings screen, roughly most useful first.

1. **Jump to the next unfelt method.** Felt methods go blank, so late in the week the grid is mostly empty, and the arrows step through cells there's nothing left to do in. `n` and `N` could jump to the next or previous unfelt method in reading order.
2. **Undo the last feeling.** One wrong key, like `1` instead of `2`, notes a feeling straight away, and the only way back is feeling it again. `u` could remove the last row from `feelings.csv` and select its method again.
3. **Click a bin to feel the selected method.** The bins are drawn, but clicking them does nothing, as they have no click events. With hover already working, Code feelings could be used with the mouse alone.
4. **The hovered method's name in the status line.** The code box doesn't follow the mouse, so while hovering, the status line could show `lib/text.rb:62 · Text#segments_between`, and "This week's code to feel" otherwise.
5. **Esc collapses an expanded code box.** Esc only does something while a note's being typed.
6. **How many are left, beside "39% refined".** Like "12 left", which says more near the end of the week.
7. **A scroll hint when an expanded box pushes rows off the grid.** A faint `↑` or `↓` at the grid's edge, so it's clear it's scrolled.
8. **A resize during the celebration** can pick a bigger batch, with unfelt methods, while the rain or waffle carries on. Not picking again until the celebration's over would fix it.
