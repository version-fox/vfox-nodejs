# Changes

[中文](zh-CN/changes.md) | [English](changes.md)

What changed in each release, as a user notices it. GitHub's
[release pages](https://github.com/version-fox/vfox-nodejs/releases) list the
pull requests. The newest release at the time of writing is 0.5.2, and `main` is
ahead of it by everything under "Unreleased".
[source-build.md](source-build.md) gets you those changes now.

## Unreleased

- 32-bit ARM Linux installs the `linux-armv7l` package, which Node.js published
  up to 23.11.1: `vfox install nodejs@20` works there. vfox's `armv7` build
  reports `arm`, and release 0.5.2 asks for `linux-arm`, which does not exist, so
  every install on 32-bit ARM ends with `Node.js package
  node-v20.19.5-linux-arm.tar.gz is not listed in ...`. From 24 on there is no
  package, and the ARMv6 one is never chosen. See
  [platforms.md](platforms.md#not-supported).
- On musl the install stops when the unpacked `node` cannot run for lack of a
  library. After the unpack the plugin runs `node --version` once, and the dynamic
  loader names what is missing. The musl packages of 26.8.0 and later need
  `libatomic`, which a stock Alpine does not have: the install ends with
  ``Node.js (musl build) requires the libatomic system package, which was not
  found on this system. Install it with `apk add libatomic` and reinstall.`` and
  nothing is registered. Release 0.5.2 checks for `libstdc++` only, so the
  install succeeds and `node` fails with `Error loading shared library
  libatomic.so.1`. The message about `libstdc++` names its command too, where
  release 0.5.2 says `It is normally installed automatically`. See
  [musl.md](musl.md#requirements).
- `.nvmrc` and `.node-version` name a release by its numbers under
  `legacyVersionFile.strategy` `latest_installed` and `latest_available`. With
  22.9.0 and 22.23.3 installed, `22` selects 22.23.3, where release 0.5.2 selects
  22.9.0, because vfox lists the installed releases as text. `22.2` no longer
  matches 22.23.3. `22.x`, `22.x.x` and `22.*` mean 22, and release 0.5.2 selects
  nothing for `22.x`. Only a leading `v` is dropped, so `lts/<codename>` works for
  a codename with a `v` in it. Text that is no release number (`node`, `(`,
  `22[`) is left alone, where release 0.5.2 fails with `unfinished capture at
  EOS` and vfox hides the error. See [nvmrc.md](nvmrc.md#how-a-prefix-is-matched).
- A failed request for `SHASUMS256.txt` says why: `get checksum failed: HTTP 404
  from https://nodejs.org/dist/v24.99.0/SHASUMS256.txt`, or the network error,
  such as `x509: certificate signed by unknown authority`. Release 0.5.2 prints
  `get checksum failed` and nothing else. See
  [troubleshooting.md](troubleshooting.md#messages-from-the-plugin).
- `VFOX_NODEJS_MIRROR` may end in several slashes. Release 0.5.2 strips one.
- The documentation has a Chinese version, see [README_CN.md](../README_CN.md).

## 0.5.2 (2026-10-17)

- `vfox use` prints a note when another `node`, such as the one that `pnpm
  runtime set node -g` installs, comes before vfox in `PATH`, so that `node` does
  not run the release that was just selected. Before, `vfox use` reported
  `Now using` and `node -v` printed another version. See [pnpm.md](pnpm.md)
  ([#38](https://github.com/version-fox/vfox-nodejs/pull/38)).
- The Windows e2e jobs run against a home directory with a space in it, which
  needs vfox 1.0.13 ([#39](https://github.com/version-fox/vfox-nodejs/pull/39)).

## 0.5.1 (2026-10-17)

- Alpine, OpenWrt and other musl systems get the musl packages. Before, the glibc
  package was installed and `node` failed with `not found`. Where nodejs.org has
  no musl package, the plugin takes it from unofficial-builds.nodejs.org, which is
  all of arm64 and most of x64. `VFOX_NODEJS_LIBC` overrides the detection.
  An install without `libstdc++` fails with a message that names it. See
  [musl.md](musl.md)
  ([#31](https://github.com/version-fox/vfox-nodejs/pull/31),
  [#29](https://github.com/version-fox/vfox-nodejs/issues/29)).
- `.nvmrc` and `.node-version` work with `legacyVersionFile.strategy` set to
  `latest_installed` under vfox 1.x. Releases 0.3.0 to 0.5.0 call
  `ctx:getInstalledVersions()`, which vfox 1.x rejects with `expected 0 arguments
  for func() []string, got 1`, and vfox hides the error: the file selects
  nothing, even `22.23.3`. The default strategy, `specified`, was not affected
  ([#30](https://github.com/version-fox/vfox-nodejs/pull/30)).
- Under `latest_available`, `lts` and `lts/<codename>` are looked up in the version
  index, so a codename newer than the plugin keeps working. Krypton (24) is in the
  table that the other strategies use. See [lts.md](lts.md)
  ([#31](https://github.com/version-fox/vfox-nodejs/pull/31)).
- The repository has a container e2e suite for Linux, Alpine, Windows and WSL,
  and a dev container, see [e2e.md](e2e.md)
  ([#30](https://github.com/version-fox/vfox-nodejs/pull/30),
  [#33](https://github.com/version-fox/vfox-nodejs/pull/33),
  [#34](https://github.com/version-fox/vfox-nodejs/pull/34),
  [#37](https://github.com/version-fox/vfox-nodejs/pull/37)).

## 0.5.0 (2026-09-12)

- `vfox search nodejs` fails with `Failed to fetch Node.js versions: ...` when the
  index cannot be fetched. Before, it listed nothing and vfox cached the empty
  list ([#28](https://github.com/version-fox/vfox-nodejs/pull/28),
  [#16](https://github.com/version-fox/vfox-nodejs/issues/16)).
- 32-bit x86 asks for the `x86` package. Before it asked for `386`, which does not
  exist. An empty architecture from vfox stops the install with `Cannot determine
  Node.js package architecture from RUNTIME.archType`
  ([#28](https://github.com/version-fox/vfox-nodejs/pull/28),
  [#23](https://github.com/version-fox/vfox-nodejs/issues/23)).
- A package that `SHASUMS256.txt` does not list stops the install with `Node.js
  package ... is not listed in ...`. Before, vfox went on to a download without
  a checksum, which answered 404
  ([#28](https://github.com/version-fox/vfox-nodejs/pull/28)).
- `VFOX_NODEJS_MIRROR` may end in a slash. Before, the URLs had `//` in them
  ([#25](https://github.com/version-fox/vfox-nodejs/pull/25)).

## 0.4.1 (2025-09-29)

- Node.js 16.0.0 installs the arm64 package on Apple silicon. Before, 16 took the
  amd64 one, and only releases before 16 should. Those say `Note: Node.js
  versions below 16 do not support Apple Silicon (arm64), using x64 architecture
  with Rosetta 2` ([#21](https://github.com/version-fox/vfox-nodejs/pull/21)).

## 0.4.0 (2025-09-28)

- `.nvmrc` and `.node-version` follow `legacyVersionFile.strategy`. Before, they
  always used `latest_installed`. See [nvmrc.md](nvmrc.md)
  ([#17](https://github.com/version-fox/vfox-nodejs/pull/17)).
- `lts` and `lts/*` select the newest LTS line of the table, and `lts/jod` is
  known ([#17](https://github.com/version-fox/vfox-nodejs/pull/17)).
- An unknown version says `version not found for provided version <what you
  typed>`. Before, the hook failed with `cannot perform concat operation between
  string and nil` ([#14](https://github.com/version-fox/vfox-nodejs/pull/14)).

## 0.3.0 (2024-04-22)

- vfox reads `.nvmrc` and `.node-version`: exact versions, majors and
  `lts/<codename>`, see [nvmrc.md](nvmrc.md)
  ([#7](https://github.com/version-fox/vfox-nodejs/pull/7)).

## 0.2.x (2024-04)

- 0.2.2 (2024-04-09): `vfox use nodejs@20` and `nodejs@20.11` find the installed
  releases ([#6](https://github.com/version-fox/vfox-nodejs/pull/6)).
- 0.2.1 (2024-04-08): `vfox install nodejs@20` and `nodejs@20.11` install the
  newest release of the line. They failed before
  ([#5](https://github.com/version-fox/vfox-nodejs/pull/5)).
- 0.2.0 (2024-04-07): `VFOX_NODEJS_MIRROR`, see [mirror.md](mirror.md)
  ([#3](https://github.com/version-fox/vfox-nodejs/issues/3)). Apple silicon
  installs the amd64 package of Node.js 16 and earlier
  ([#4](https://github.com/version-fox/vfox-nodejs/issues/4)).

## 0.0.x and 0.1.x (2024-03 and 2024-04)

- 0.0.1 (2024-03-26) is the first release. `vfox search nodejs` failed in it, and
  works from 0.0.5. Installing a full release number, with the check of its
  SHA-256 sum, works from the start.
- 0.1.1 (2024-04-01) adds the lookup of a line for `vfox use`, which finds
  nothing until 0.2.2.
