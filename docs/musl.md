# musl libc support (Alpine, OpenWrt/ImmortalWrt)

Node.js official Linux tarballs link glibc (`ld-linux-*`). On musl systems
there is no glibc loader, so the stock download fails with `not found` /
`Error loading shared library ld-linux-aarch64.so.1`.
See [issue #29](https://github.com/version-fox/vfox-nodejs/issues/29).

This plugin detects musl and installs a musl tarball instead.

## Alpine in a few lines

```sh
apk add bash libstdc++ libatomic
vfox add nodejs
vfox install nodejs@24
vfox use --global nodejs@24
```

`vfox use` needs vfox's shell hook, and vfox does not support BusyBox `ash`
(`vfox activate sh` answers `unknown target shell sh`), so run it from bash with
`eval "$(vfox activate bash)"` in place. The two libraries are explained below.

## Requirements

The Node.js musl packages link system libraries that the plugin does not
install. A stock Alpine image has none of them, and the usual toolchain does
not always pull them in:

| Library | Needed by | Alpine | OpenWrt, ImmortalWrt |
| ------- | --------- | ------ | -------------------- |
| `libstdc++` | every musl package | `apk add libstdc++` | the `libstdcpp` package |
| `libatomic` | the musl packages of 26.8.0 and later | `apk add libatomic` | `libatomic`, not checked |

The install checks for them, so that it does not look successful while `node
--version` fails later. Right after the unpack the `PostInstall` hook looks for
`libstdc++` in the usual library directories, and then runs `node --version`
once: the dynamic loader names any other library that is missing. The message
names the package and the command that installs it, the install is not
registered (`vfox list nodejs` answers `no available version` when it was the
only one), and after installing the library you run `vfox install` again. Where
no command can be run, or when `node` fails for another reason, the install is
left alone.

```text
plugin [PostInstall] method error: <path>:<line>: Node.js (musl build) requires the libstdc++ system package, which was not found on this system. Install it with `apk add libstdc++` and reinstall. See https://github.com/version-fox/vfox-nodejs/blob/main/README.md
failed to install nodejs
```

```text
plugin [PostInstall] method error: <path>:<line>: Node.js (musl build) requires the libatomic system package, which was not found on this system. Install it with `apk add libatomic` and reinstall. See https://github.com/version-fox/vfox-nodejs/blob/main/README.md
failed to install nodejs
```

On OpenWrt the command is `opkg install libstdcpp`. A system that is neither
gets the message without a command. A symbol that the libraries lack, which the
loader reports as `Error relocating ...: symbol not found`, ends in `Node.js
(musl build) cannot run on this system: Error relocating ...`.

Unreleased: release 0.5.2 looks for `libstdc++` only, and its message says `It
is normally installed automatically; install it and reinstall.` instead of
naming the command. It does not look for `libatomic`: the install succeeds, and
`node` then fails.

```text
Error loading shared library libatomic.so.1: No such file or directory (needed by /root/.vfox/cache/nodejs/v-26.12.0/nodejs-26.12.0/bin/node)
Error relocating /root/.vfox/cache/nodejs/v-26.12.0/nodejs-26.12.0/bin/node: __atomic_compare_exchange: symbol not found
```

Which releases need `libatomic` was checked on Alpine 3.24.1 (x86_64) with only
`libstdc++` installed: 18.20.8, 22.23.3, 24.20.0, 24.22.0, 25.2.0, 25.6.0,
25.9.0, 26.0.0 and 26.5.1 run. 26.8.0, 26.11.1 and 26.12.0 do not. What the
three have in common is that nodejs.org carries them: its musl packages of 26
start at 26.8.0, and the 26.x before that come from Unofficial Builds, see below.
The packages that nodejs.org carries for 22.23.3, 24.20.0 and 24.22.0 run
without `libatomic`. A system that has `gcc` installed has `libatomic` already,
which is why the e2e image (`go` depends on `gcc`) does not show the problem.

`libatomic1` is the Debian and Ubuntu name of the same library, which the glibc
packages of Node.js 25 and later link, see [platforms.md](platforms.md#linux).

## Which tarball is installed

| Host | Tarball | Source |
| ---- | ------- | ------ |
| Linux glibc, x64/arm64 | `node-v<V>-linux-x64.tar.gz` etc. | `nodejs.org/dist` |
| Linux musl, x64 | `node-v<V>-linux-x64-musl.tar.gz` | `nodejs.org/dist` when it has the release, else `unofficial-builds.nodejs.org` |
| Linux musl, arm64 | `node-v<V>-linux-arm64-musl.tar.gz` | `unofficial-builds.nodejs.org` (nodejs.org never ships it) |

Notes:

- A release that nodejs.org lacks falls back to
  `https://unofficial-builds.nodejs.org/download/release` automatically, and
  the plugin says so:
  `Note: node-v25.9.0-linux-x64-musl.tar.gz is not listed in https://nodejs.org/dist/v25.9.0/, using unofficial musl build`.
- Mirror behavior on musl (when the mirror applies, when unofficial is
  used): see [mirror](mirror.md).
- musl builds exist only for `x64` and `arm64`. Other Linux architectures
  (e.g. `x86` or `armv7l`) error out with a pointer to the README.
- Every musl install starts with a note that names the package, and points at
  the README: `Note: musl libc detected, installed node-v22.23.3-linux-x64-musl.tar.gz. See ...`.

## Which releases have a musl build

As of 2026-10-21, from the `index.json` and `SHASUMS256.txt` of nodejs.org and of
Unofficial Builds:

| | nodejs.org | Unofficial Builds |
| --- | --- | --- |
| x64 | 22.23.3, 24.20.0 to 24.22.0, and 26.8.0 and later | 8.16.0 and later, but not every release |
| arm64 | none | 20.20.1 and 20.20.2, 22.21.1 and later 22.x, 24.9.0 and later, 25.2.0 and later, and all of 26 |

- On x64 that makes every release from 12.0.0 on, except 12.11.0, 13.9.0, 13.10.0
  and 19.8.0. Of 8.x, 10.x and 11.x only some have a build, and 9.x and anything
  before 8.16.0 have none.
- On arm64 there is nothing for 18, 19, 21 and 23, nor for the lines before
  20.20.1.
- A release without a package ends in `Node.js package node-v9.11.2-linux-x64-musl.tar.gz is not listed in https://nodejs.org/dist/v9.11.2/SHASUMS256.txt`.
  Pick another release, or see [platforms.md](platforms.md).
- Both sites change. [development.md](development.md#refreshing-the-platform-table)
  shows how to ask again.

## Detection and override

Detection order in `lib/util.lua`:

1. `$VFOX_NODEJS_LIBC`: `musl` forces musl, `gnu`/`glibc` forces glibc.
   Useful on exotic userlands and in tests.
2. `RUNTIME.envType` when a future vfox core provides it (`musl`/`gnu`).
3. File probes readable from Lua: `/etc/alpine-release`,
   `/lib`/`/usr/lib`/`/lib64` `ld-musl-*.so.1`. musl wins when both linkers
   exist (e.g. `gcompat` shims). Non-Linux is never musl.

```sh
# Force musl selection (debugging only)
VFOX_NODEJS_LIBC=musl vfox install nodejs@26.11.1
```

Forcing the other way installs a glibc package that cannot run on musl. On
Alpine, `VFOX_NODEJS_LIBC=gnu vfox install nodejs@20.20.2` installs
`node-v20.20.2-linux-x64.tar.gz`, and running its `node` answers `not found`.
