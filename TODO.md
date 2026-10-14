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
