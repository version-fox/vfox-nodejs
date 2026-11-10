# Development

[中文](zh-CN/development.md) | [English](development.md)

## Layout

```text
metadata.lua                    plugin name, version, .node-version and .nvmrc as legacy files, and shadowHints for a shadowing node
hooks/available.lua             vfox search: the version index
hooks/pre_install.lua           vfox install: choose the package, its URL and its checksum
hooks/post_install.lua          musl: fail when node cannot run, such as without libstdc++ or libatomic
hooks/env_keys.lua              PATH: bin on Linux and macOS, the install directory on Windows
hooks/pre_use.lua               vfox use: map 24 or 24.21 to an installed release (and, on vfox before 1.1.0, note a shadowing node)
hooks/parse_legacy_file.lua     .nvmrc and .node-version
hooks/detect.lua                vfox link --detect: the nvm, mise, asdf, Homebrew and winget installs on this machine
lib/util.lua                    mirror URL and download headers, musl detection and missing libraries, running a command, version comparison and matching, shorthands, PATH probe, vfox version check, the LTS lines the plugin learned
.lts-cache                      not in the repository: what the plugin learned about LTS lines, written next to it
tests/hooks_test.lua            offline hook tests
tests/e2e/                      container tests, see e2e.md
Injection.lua                   type hints for what vfox injects, never loaded
.devcontainer/                  Linux development container, see e2e.md
.github/workflows/              test, lint, license, e2e and publish
```

vfox loads `metadata.lua`, calls a hook when a command needs it, and puts
`PLUGIN` and `RUNTIME` (`osType`, `archType`, `version`) in scope, and the
modules `http` and `json`. `osType` and `archType` are Go's `GOOS` and `GOARCH`
of the vfox binary. `RUNTIME.envType` is read when a vfox provides it (none
does yet), see [musl.md](musl.md#detection-and-override). `lib/util.lua` is
loaded with `require("util")`.

## What runs for a command

| You run | Hooks |
| --- | --- |
| `vfox search nodejs` | `Available` |
| `vfox install nodejs@24` | `PreInstall` returns the release, URL and checksum, and calls `Available` for `latest` and for a start of a release. vfox downloads, verifies and unpacks, then calls `PostInstall` |
| `vfox use nodejs@24` | `PreUse` returns the installed release to select. `EnvKeys` provides `PATH` |
| a shell hook, `cd` into a directory with `.nvmrc` | `ParseLegacyFile`, then `EnvKeys` |
| `vfox uninstall nodejs@24.21.0` | none, the name has to be exact |
| `vfox link --detect nodejs` | `Detect` |

A few contracts that cost time to find:

- `PreInstall` returns `version`, `url`, `sha256`, `headers` and sometimes
  `note`. `version` is the name of the install, so a start of a release has to
  be resolved to the full release here. vfox only warns when there is no
  checksum (`Checksum is not provided`) and goes on to download, so since 0.5.0
  the hook fails when the package is not in `SHASUMS256.txt` instead of
  returning none. Notes that the hook prints with `print` show up in vfox's
  output.
- `headers` is what vfox sends with the download of `url`, which vfox makes, not
  the plugin. Left out, vfox asks with the `User-Agent` of Go's HTTP client,
  `Go-http-client/1.1`, and Huawei Cloud, TUNA, USTC and BFSU answer that with
  an error page that vfox saves as the package, so the install ends in
  `checksum error`. `util.download_headers()` gives the `User-Agent` that vfox
  builds for the plugin's own requests, `vfox/<RUNTIME.version>
  vfox-nodejs/<PLUGIN.version>`, which all of them serve. vfox 1.0.13 sends it
  with the download, as a local server that logged the requests showed. The
  unofficial site gets it too.
- `Available` raises on a network error or a status other than 200. Since 0.5.0
  it does not return an empty list, which vfox cached. The result is kept in the
  global `available_result` for the life of the process, and the tests reset it.
  vfox caches the search itself for 12 hours.
- `PreUse` returns `{ version = nil }` for what it cannot map, and vfox answers
  `is not installed`. The `ctx.installedSdks` it gets is a table keyed by
  release, not an array, which is why `calculate_shorthand` iterates with
  `pairs`.
- `ParseLegacyFile` calls `ctx.getInstalledVersions()` with no argument. vfox 1.x
  binds it as a plain Go function and rejects the extra argument that
  `ctx:getInstalledVersions()` adds. The strategy is `ctx.strategy`. vfox hands
  over the installed versions as text sorted descending, so `22.9.0` comes
  before `22.23.3`. The test passes the function as a plain function and asserts
  that it was called without arguments.
- `PostInstall` gets `ctx.rootPath` and `ctx.sdkInfo`, a table keyed by the name
  of the SDK (`nodejs`, or the alias) whose `path` is the unpacked release.
  `bin/node` is there by then. The hook walks `ctx.sdkInfo` instead of reading
  `ctx.sdkInfo.nodejs`, so an alias works too. `io.popen` and `os.execute` work in
  vfox's Lua. `io.popen(...):close()` returns the exit status as a number, not
  `true` as in standard Lua, and `util.capture` copes with both.
- `EnvKeys` sets `PATH` only, nothing like `NODE_HOME`.
- vfox removes a leading `v` from what the user types before the hooks see it.

## Resolving a version

`PreInstall`:

1. `latest` becomes the first entry of `Available`, which is sorted newest first
   by `util.compare_versions`, numbers one by one.
2. Anything that is not `x.y.z` (`^%d+%.%d+%.%d+$`, `util.is_semver_simple`) is
   looked up in `util.calculate_shorthand(Available)`, a table from `24` and
   `24.21` to the newest release of each. A miss ends in `version not found for
   provided version <what the user typed>`.
3. A release that does not exist passes both steps and fails when
   `SHASUMS256.txt` answers 404: `get checksum failed`.

`PreUse` does step 2 against the installed releases. `ParseLegacyFile` has its own
rules, see below.

## Packages

`PreInstall` builds the file name `node-v<version>-<os>-<arch><ext>`
(`util.FileName`) from `RUNTIME`: `amd64` is `x64`, `386` is `x86`, `arm` is
`armv7l`, Windows is `win` and `.zip`. macOS arm64 with a major below 16 takes
`x64`. On Linux `util.is_musl()` adds `-musl` for `x64` and `arm64`, and errors
for other CPUs. It then reads `<mirror>/v<version>/SHASUMS256.txt`, finds the sum
with `util.get_checksum`, and returns the URL next to the sums. A request that
fails ends in `get checksum failed: <error>` or `get checksum failed: HTTP
<status> from <address>`. If a musl package is missing there, it tries
`UnofficialBaseUrl` the same way. The tables of what exists are in
[platforms.md](platforms.md) and [musl.md](musl.md).

`util.getBaseUrl()` is the mirror: `$VFOX_NODEJS_MIRROR` without trailing
slashes, or `https://nodejs.org/dist`. The unofficial site ignores it.

`post_install.lua` does nothing outside musl. On musl it fails when no
`libstdc++.so.6` is found in the usual library directories
(`util.has_libstdcxx`). Then it runs the unpacked `bin/node --version` once with
`util.capture`: the dynamic loader names a library that is missing (`Error
loading shared library libatomic.so.1`), and the hook turns that into a message
with the package and, on Alpine and OpenWrt, the command (`util.MuslLibraries`
holds the package names, `util.install_command` builds the command). Any other
failure, and a runtime that cannot run a command, leave the install alone, so a
check that cannot work never blocks an install. See
[musl.md](musl.md#requirements).

## Legacy files

`ParseLegacyFile` reads the file and decodes it (`util.decode_text` turns
UTF-16 with a byte order mark into UTF-8, and drops the UTF-8 mark, because
Windows PowerShell 5.1 writes both). It removes all whitespace, and gives the
text to
`resolve_version(query, strategy)`: it drops a leading `v`, lowers the case,
turns `lts-x` into `lts/x`, and maps `lts/<codename>` to a major, `lts` and
`lts/*` to the newest major of an LTS line. Under `latest_available` the
codename comes from the index first (`discover_lts`). Everywhere else, and when
that finds nothing or the request fails, `util.known_lts_lines` answers without
a request: what the plugin learned from the index over the built-in
`util.LtsLines`, see [below](#what-the-plugin-learns-about-lts-lines).

`resolve_legacy_version(strategy, query)` then reads the query with
`util.version_prefix`: `22` is `{ 22 }`, `22.23` is `{ 22, 23 }`, and `22.x`,
`22.x.x` and `22.*` are `{ 22 }`. Text that is no such prefix (`node`,
`lts/unknown`, `>=20`) is returned as it is. For a prefix:

- `specified`: returns the query.
- `latest_installed`: the newest of `ctx.getInstalledVersions()` that starts with
  the prefix (`util.newest_matching`, compared as numbers part by part). If none
  does, it does what `latest_available` does.
- `latest_available`: the newest of `Available` that starts with the prefix, or
  the query itself.

`vfox` then selects the answer if it is installed. User-facing rules and
examples are in [nvmrc.md](nvmrc.md) and [lts.md](lts.md).

## What the plugin learns about LTS lines

`ParseLegacyFile` runs at every prompt in a directory with a version file, so it
cannot fetch `index.json` to find out what `lts/*` is. The plugin learns it when
it has the index in hand anyway, and keeps it in `.lts-cache`, a text file next
to the plugin:

```text
# What vfox-nodejs learned from index.json about LTS lines. Safe to delete.
updated 1793000000
newest 26
line argon 4
...
line lithium 26
```

- `Available` calls `util.remember_lts` with the index it has decoded.
  `util.lts_summary` finds the major of each named line and the newest major
  that is LTS at all (a release whose `lts` is `true`, a line without a name,
  counts for the newest only). It runs when vfox's own cache of the answer has
  run out.
- `PreInstall` calls `util.refresh_lts_cache` once the install has its checksum,
  so an install that fails early, such as the one for an architecture without a
  package, fetches nothing. vfox installs an exact release without asking
  `Available`, so this is where such an install learns. It calls `Available`
  when the file is missing or older than a day, and only if the file can be
  written, so that a plugin directory that is read-only does not cost an index
  at every install.
- `ParseLegacyFile` reads the file through `util.known_lts_lines`, which puts
  what was learned over the built-in `util.LtsLines` and takes the newest major
  of the two for `lts` and `lts/*`. It never fetches.
- vfox gives a plugin no path of its own, so `util.plugin_dir` finds the
  directory where `package.path` has `hooks/?.lua` and `lib/?.lua`. The new
  file is written beside the old one and renamed over it. Every failure, no
  directory, nothing writable, a damaged file, leaves the plugin with the table.
- In the checkout `package.path` starts with `./lib/?.lua`, so the directory
  would be the repository. The hook tests point `util.lts_cache_path` at a file
  of their own.

## When Node.js promotes a line to LTS

Each October an even-numbered line gets a codename, see
[lts.md](lts.md#when-nodejs-promotes-a-line). The plugin learns the line from
the index and needs no release for it. This is housekeeping, so that a plugin
that has learned nothing yet knows it too, and that the documents are right:

1. Add `<codename> = <major>` to `UTIL.LtsLines` in `lib/util.lua`.
2. Add a case next to `legacy lts lithium maps to its major` in
   `tests/hooks_test.lua`, and change the major that `legacy bare lts is the
   newest line of the table` expects.
3. Add the codename to `LTSCodenames` in `tests/e2e/common/common.go`, and a
   case to `TestLTSCodename`. The e2e suites compare that table with the file
   the plugin wrote from the live index.
4. Add a row to the table in [lts.md](lts.md#what-this-plugin-understands), and
   change the "26 at the time of writing" sentences in [lts.md](lts.md) and
   [nvmrc.md](nvmrc.md), and the examples of [lts.md](lts.md#examples).
5. `DefaultLTSVersion` in `tests/e2e/common/common.go` may stay: it only has to
   stay inside the table.

## Tests

The hook tests run offline under `gopher-lua`, the Lua interpreter vfox embeds:

```bash
go run github.com/yuin/gopher-lua/cmd/glua@v1.1.1 tests/hooks_test.lua
```

Run it from the repository root. `tests/hooks_test.lua` stubs `http` and `json`
itself (`package.preload`), sets `RUNTIME` per case, and answers requests from
`state.response`, `state.decoded` and `state.responder`. A case is
`test("name", function() ... end)`, which resets the state and `available_result`.
It covers `Available` and its failures, the package name per platform and the
errors of a failed checksum request, musl and `PostInstall` (with `util.capture`,
`util.file_exists` and `util.has_libstdcxx` stubbed through `with_util`),
`ParseLegacyFile` under each strategy, in UTF-16 and with a byte order mark,
what
the plugin learns about LTS lines (the file is a temporary one, and every case
starts with a fresh one that knows no line), `PreUse` with and without the
shadowing `node` on old and new vfox (`RUNTIME.version` before and from
1.1.0), `PLUGIN.shadowHints` in `metadata.lua`, `Detect` over stubbed
install roots, listings and `node --version` outputs (`os.getenv`,
`list_dir`, `file_exists` and `capture` stubbed), and the helpers of
`lib/util.lua`. Add the case a change needs there.

gopher-lua 1.1.1 loses a `local x = nil` that a closure assigns: the outer scope
still reads `nil`. A test that collects a value from inside `with_util` or
`pcall` has to keep it in a table field. It also ends in a Go "nil pointer
dereference" at `if file == nil` after `local file = path ~= nil and
io.open(path, "r") or nil`: test `path` and open the file in two statements.
Check new code under `glua`, not only with LuaLS.

To call one hook against the real servers, vfox 1.0.13 and later has
`vfox plugin run`. It does not register the plugin, `--os` and `--arch` answer
for another platform, `--offline` rejects HTTP, and `VFOX_NODEJS_MIRROR` applies
(`Detect` needs vfox 1.1.0 or later, which knows the hook):

```bash
vfox plugin run . Available --json
vfox plugin run . PreInstall --input '{"version":"24"}' --os windows --arch arm64 --json
vfox plugin run . PreUse --input '{"version":"22","installedSdks":{"22.23.3":{"version":"22.23.3"}}}' --json
vfox plugin run . ParseLegacyFile --input '{"filename":".nvmrc","filepath":"/tmp/p/.nvmrc","strategy":"latest_installed","installedVersions":["24.21.0"]}' --json
vfox plugin run . EnvKeys --input '{"path":"C:\\vfox\\nodejs-24.21.0"}' --os windows --arch amd64 --json
vfox plugin run . Detect --json
```

`vfox --debug <command>` shows what vfox does with a hook, which is how to find
an error it swallows, such as one from `ParseLegacyFile`.

Lint, license headers and the container tests are in
[e2e.md](e2e.md#local-checks). Lua is formatted with StyLua (`stylua.toml`: 4
spaces, 120 columns), checked by LuaLS at `Warning` level (`.luarc.json` declares
`PLUGIN` and `RUNTIME`). Source files (Lua, Go, YAML, PowerShell and the
Dockerfiles) carry the license header, Markdown and JSON do not.

## Refreshing the platform table

[platforms.md](platforms.md) was taken from nodejs.org. `index.json` lists the
releases, newest first, with the files each has, and this prints for each package
the first and the last release that has it, and how many releases in between do
not:

```bash
curl -s https://nodejs.org/dist/index.json | jq -r '
  def span($key):
    [to_entries[] | select(.value.files | index($key))] as $hits
    | if ($hits | length) == 0 then "none"
      else "\($hits[-1].value.version) to \($hits[0].value.version), \($hits | length) releases, \($hits[-1].key - $hits[0].key + 1 - ($hits | length)) missing in between"
      end;
  ("linux-x64", "linux-arm64", "linux-ppc64le", "linux-s390x", "linux-x86", "linux-x64-musl",
   "osx-x64-tar", "osx-arm64-tar", "win-x64-zip", "win-x86-zip", "win-arm64-zip") as $key
  | "\($key): \(span($key))"'
```

The keys are the index's names for the plugin's files (`osx-x64-tar` is
`darwin-x64.tar.gz`, `win-x64-zip` is `win-x64.zip`). The index agrees with the
`SHASUMS256.txt` files, which are what the plugin reads, except for two releases:
it lists 0.11.4 and 0.11.6 for `linux-x64`, `linux-x86` and macOS x64, and they
have no package. For the musl table run the same program against
`https://unofficial-builds.nodejs.org/download/release/index.json` with
`linux-x64-musl` and `linux-arm64-musl`, and against the official index with
`linux-x64-musl`. Each answers for one site, so combine the two.

## Known gaps

- 32-bit ARM takes the `linux-armv7l` package, up to 23.11.1. The ARMv6 package
  (`linux-armv6l`) is never chosen, and from 24 on nothing exists for 32-bit ARM.
- riscv64 and loong64 only have packages on Unofficial Builds, which the plugin
  uses for musl only.
- `PostInstall` runs `node --version` on musl only. On glibc a missing
  `libatomic.so.1` (Node.js 25 and later) shows when `node` runs: the README
  leaves system libraries to the user.
- The e2e Alpine image gets `libatomic` through `go`, which depends on `gcc`, so
  the suite does not cover a stock Alpine without it. The hook tests do.
- `.nvmrc` aliases (`node`, `stable`, `lts/-1`), ranges and comments are not
  understood, see [nvmrc.md](nvmrc.md#not-understood).
- A plugin directory that cannot be written, or a plugin that has not had the
  index in hand since it was installed, leaves `specified` and
  `latest_installed` with the built-in table, which ends at Lithium.
- On vfox before 1.1.0 a version file only applies when a shell starts in its
  directory: a `cd` into the directory is ignored, and so is an edit of the
  file, and leaving the directory keeps the release it had. vfox tracks these
  files from 1.1.0
  ([version-fox/vfox#745](https://github.com/version-fox/vfox/issues/745),
  fixed by [version-fox/vfox#748](https://github.com/version-fox/vfox/pull/748)),
  tracked here as [#46](https://github.com/version-fox/vfox-nodejs/issues/46).
- `latest_available` downloads `index.json` at every prompt in a directory with a
  legacy file.
- UTF-32, and UTF-16 without a byte order mark, are not decoded.
- The unofficial site is not covered by `VFOX_NODEJS_MIRROR`.
- macOS has no e2e job.

## Releasing

A maintainer runs **Actions → Plugin → Run workflow** on the default branch with
the version, without `v`. The README describes what the shared workflow does.
Afterwards `plugins/nodejs.json` in
[vfox-plugins](https://github.com/version-fox/vfox-plugins) shows the version
that `vfox add nodejs` serves.

While `main` is ahead of the last release, the documentation marks what is newer
with "Unreleased" ("未发布" in Chinese): the entries sit under an "Unreleased"
heading at the top of [changes.md](changes.md), a page that describes the new
behavior adds a remark that starts with "Unreleased: release X.Y.Z" and tells
what the last release does, and the README has a paragraph that explains the
mark and points at [changes.md](changes.md) and
[source-build.md](source-build.md). After a release, move the entries in
[changes.md](changes.md) under the new version, with the pull request of each,
and take the remarks and the README paragraph out, in both languages:
`grep -rn -i -e unreleased -e 未发布 docs README*`. Also search for the number of
the previous release: a few sentences compare against it without saying
"Unreleased".

## Writing the docs

English pages are in `docs/`, the Chinese ones in `docs/zh-CN/` under the same
names (the Chinese README is `README_CN.md`), and each page starts with a link to
the other language. Prose is wrapped at 80 columns in the English pages, tables
are not. Pages that quote data give the day it was taken (the platform and musl
tables, the mirror list, the LTS table, the outputs of `vfox search`), and
nothing checks them. CI does not lint Markdown, so run the commands you add, and
the outputs in a page are the ones they printed. When a change in the plugin
makes a page wrong, change the page and its translation in the same pull request.
A link to `page.md#heading` in a Chinese page uses the heading of the Chinese
page, whose address is not the English one.
