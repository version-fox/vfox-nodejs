# Troubleshooting

[中文](zh-CN/troubleshooting.md) | [English](troubleshooting.md)

The messages below were produced with vfox 1.0.12 and 1.0.13. vfox prefixes the
plugin's own errors with `plugin [PreInstall] method error: <path>:<line>:`
(`[Available]` for the search) and follows them with a Lua stack trace, which this
page leaves out.

## Messages from the plugin

### `version not found for provided version lts`

What follows `nodejs@` is not a release number, nor the start of one. The plugin
knows `latest`, `24.21.0`, `24.21` and `24`, see [versions.md](versions.md).
`lts`, `lts/iron`, `stable`, `24.21.0.1` and `24.0.0-rc.1` end here, and so do `99`
and `22.99`, which are well formed but start no release. For an LTS line, install
the line by number, see [lts.md](lts.md#installing-an-lts-line).

### `get checksum failed: HTTP 404 from https://nodejs.org/dist/v24.99.0/SHASUMS256.txt`

The plugin could not read the `SHASUMS256.txt` of the release, and says why
after the colon. `HTTP 404 from <address>` means the server has no such file:
the release does not exist (`24.99.0`), or the mirror lacks it. A network error
(`Get "<address>": tls: failed to verify certificate: x509: certificate signed
by unknown authority`, `... connection refused`, `... EOF`) means the server
could not be reached: a mirror that is down, a proxy, a TLS problem. See
[Network](#network).

Unreleased: release 0.5.2 prints `get checksum failed` and nothing else, so the
cause is hidden. `vfox search nodejs` asks the same server for the index and
prints the real error.

### `Node.js package node-v19.8.1-win-arm64.zip is not listed in https://nodejs.org/dist/v19.8.1/SHASUMS256.txt`

The release exists, and Node.js published no package for your platform under the
name the plugin asks for. `vfox search nodejs` lists releases that have no
package for your platform, as the index does not say which ones have. The file
name in the message is the one the plugin looked for. Compare it with
[platforms.md](platforms.md), which also lists what is not supported (ARMv6, 32-bit
ARM from 24 on, riscv64, loong64).

On Alpine and other musl systems the file name ends in `-musl.tar.gz`, and the
plugin has tried unofficial-builds.nodejs.org as well. See
[musl.md](musl.md#which-releases-have-a-musl-build).

### `Failed to fetch Node.js versions: ...`

The request for `index.json` failed. What follows is the network error
(`Get "https://nodejs.org/dist/index.json": ...`) or the HTTP status
(`HTTP 404`, from a mirror that has no `index.json` at that address). See
[Network](#network). Before 0.5.0 a failed request ended as an empty list, and
vfox cached it.

### `Cannot determine Node.js package architecture from RUNTIME.archType`

vfox did not tell the plugin which CPU it runs on. It is not expected. Report it
with the output of `vfox --version`.

### `Node.js musl builds are only available for x64 and arm64, got x86. See ...`

The plugin took the system for musl, and Node.js has no musl packages for the
CPU (`x86` and `armv7l` are the ones that end here). If the system is not musl,
set `VFOX_NODEJS_LIBC=glibc`, see
[musl.md](musl.md#detection-and-override).

### `Node.js (musl build) requires the libatomic system package, which was not found on this system. ...`

A musl system without a library that the Node.js musl package links:
`libstdc++` for every one of them, `libatomic` for the ones of 26.8.0 and later.
The message names the package, and the command that installs it on Alpine
(`apk add libatomic`) and OpenWrt (`opkg install libatomic`). The install fails
after the unpack and nothing is registered. Install the library and run the
install again. See [musl.md](musl.md#requirements).

Unreleased: release 0.5.2 looks for `libstdc++` only, and its message has no
command. A missing `libatomic` shows later, as an error of `node` itself, see
below.

### `Node.js (musl build) cannot run on this system: Error relocating ...`

The unpacked `node` needs a symbol that no library of the system provides. The
install fails after the unpack and nothing is registered. Unreleased: release
0.5.2 does not run `node` after the unpack, and the error shows when you run it.
See [musl.md](musl.md#requirements).

### `checksum error`

vfox prints `Verifying checksum <sum>...`, compares the download with it, and
stops when they differ. It names the file it dropped: `Checksum error, file:
~/.vfox/cache/nodejs/node-v24.21.0-linux-x64.tar.gz`. Typical causes are a
cut-off download and a mirror whose files differ from its `SHASUMS256.txt`.
Nothing is installed. Run it again, or try another [mirror](mirror.md).

### `nodejs@24.99 is not installed`

`vfox use` and `vfox uninstall` only know what is installed. `vfox list nodejs`
shows it. `vfox use` takes `24`, `24.21` and `24.21.0` for installed releases,
`vfox uninstall` takes the whole release number. See
[versions.md](versions.md#using).

### `vfox requires hook support. Please ensure vfox is properly initialized with 'vfox activate'`

`vfox use` changes the environment of your shell, which only the hook can do.
Add `eval "$(vfox activate bash)"` (or the line for your shell) to the startup
file of the shell, see vfox's
[quick start](https://vfox.dev/guides/quick-start.html). Alpine's own `sh` is
not supported by vfox. Install `bash` there.

### `plugin named nodejs already exists`

`vfox add nodejs` found the plugin. For a plugin from source, see
[source-build.md](source-build.md#when-nodejs-is-already-added).

### `Plugin nodejs is not installed. Use the -y flag to automatically install plugins in non-interactive environments`

The plugin is not added, or `VFOX_HOME` points at a directory it was not added
to. Run `vfox add nodejs`.

### Notes the plugin prints

These are not errors.

| Note | Meaning |
| --- | --- |
| `Note: Node.js versions below 16 do not support Apple Silicon (arm64), using x64 architecture with Rosetta 2` | macOS arm64 and a release before 16.0.0, see [platforms.md](platforms.md#macos) |
| `Note: musl libc detected, installed node-v22.23.3-linux-x64-musl.tar.gz. See ...` | the plugin took the musl package, see [musl.md](musl.md) |
| `Note: node-v18.20.8-linux-x64-musl.tar.gz is not listed in https://nodejs.org/dist/v18.20.8/, using unofficial musl build` | nodejs.org has no such musl package and the plugin takes it from unofficial-builds.nodejs.org |
| ``Note: /home/me/.local/share/pnpm/bin/node comes before vfox in PATH, so `node` will not run nodejs@24.21.0. See ...`` | another `node` shadows vfox's, see [pnpm.md](pnpm.md) |

### Errors from Node.js itself

These come from `node` after a successful install.

- `node: error while loading shared libraries: libatomic.so.1: cannot open
  shared object file`. Node.js 25 and later links `libatomic`, which stock
  Debian and Ubuntu do not have: `sudo apt install --assume-yes libatomic1`. See
  [platforms.md](platforms.md#linux).
- `node: not found`, though the file exists, on Alpine. That is a glibc package on
  a musl system: the plugin did not detect musl, or `VFOX_NODEJS_LIBC` says
  `gnu` or `glibc`. See [musl.md](musl.md#detection-and-override).
- `Error loading shared library libatomic.so.1: No such file or directory`,
  followed by `Error relocating ...: __atomic_compare_exchange: symbol not
  found`, on Alpine. The musl packages of 26.8.0 and later need `libatomic`:
  `apk add libatomic`. Unreleased: the install itself stops with the message
  above, and release 0.5.2 gets this far. See [musl.md](musl.md#requirements).
- `Error relocating ... symbol not found` on a musl system, without the
  `libatomic` line above. A library is missing or too old. Unreleased: the
  install stops with `cannot run on this system`, and release 0.5.2 gets this
  far. See [musl.md](musl.md#requirements).

## Network

The plugin asks the server for two things, and vfox downloads a third:

| What | Address |
| --- | --- |
| The list of releases (`vfox search`, `latest`, `nodejs@24`) | `<mirror>/index.json` |
| The sums of one release (`vfox install`) | `<mirror>/v<version>/SHASUMS256.txt` |
| The package (vfox) | `<mirror>/v<version>/<package>` |

`<mirror>` is `https://nodejs.org/dist` unless `VFOX_NODEJS_MIRROR` says
otherwise, see [mirror.md](mirror.md). Musl systems may also use
`https://unofficial-builds.nodejs.org/download/release`.

vfox's own proxy setting covers the requests of the plugin and the download:

```bash
vfox config proxy.enable true
vfox config proxy.url http://127.0.0.1:7890
```

While `proxy.enable` is `false`, the usual `HTTP_PROXY`, `HTTPS_PROXY` and
`NO_PROXY` environment variables apply. A proxy that is down shows in the search
as `proxyconnect tcp: dial tcp 127.0.0.1:7890: connect: connection refused`.

The usual failures of `vfox search nodejs`. `vfox install` reports the same cause
after `get checksum failed:`. Unreleased: release 0.5.2 leaves it out, and only
the search prints it:

| After `Failed to fetch Node.js versions:` | Cause |
| --- | --- |
| `Get "https://nodejs.org/dist/index.json": tls: failed to verify certificate: x509: certificate signed by unknown authority` | The system has no CA certificates, as in a bare Debian or Ubuntu Docker image: `apt-get install ca-certificates` |
| `Get "...": ... connection refused`, `i/o timeout` or `no such host` | The server cannot be reached: no route, a dead proxy, a wrong mirror name, DNS. Try a [mirror](mirror.md) or the proxy setting |
| `HTTP 404` | The mirror does not have `index.json` at that address. Point `VFOX_NODEJS_MIRROR` at the directory that holds it |

## Things that look wrong and are not

- **A release you expect is missing from `vfox search`.** vfox keeps the result
  for 12 hours. `vfox config cache.availableHookDuration 0` turns the cache off.
  A mirror can also lag behind nodejs.org.
- **`vfox search nodejs` lists a release that will not install.** The list is the
  index for every platform, see [platforms.md](platforms.md).
- **`vfox search nodejs 24` does not filter.** Arguments are ignored, see
  [versions.md](versions.md#searching).
- **`vfox install nodejs@24` downloads nothing.** Newest 24.x is already
  installed: `nodejs@24.22.0 is already installed`.
- **`vfox use nodejs@24.21.0` says `Now using`, and `node -v` prints another
  version.** In a directory with a `.nvmrc` or `.node-version` the file wins
  at the next prompt, see [nvmrc.md](nvmrc.md). Another `node` ahead of vfox in
  `PATH` wins too, and `vfox use` says so, see [pnpm.md](pnpm.md).
- **`vfox current nodejs` and `node -v` disagree.** The same. The first names
  the choice of the session or the scope, the second what `PATH` finds.
- **A global npm package is gone after `vfox use`.** Global packages belong to a
  release, see [npm.md](npm.md#global-packages-belong-to-a-release).
- **`corepack` is missing.** Node.js 25 and later does not ship it, see
  [npm.md](npm.md#yarn-pnpm-and-corepack).
- **`.nvmrc` selects nothing.** Check the strategy and what the file holds, see
  [nvmrc.md](nvmrc.md#not-finding-it).
- **`git status` lists `.vfox/`.** vfox links the release into the project as
  `.vfox/sdks/nodejs`. Ignore `.vfox/` in `.gitignore`, and keep `.vfox.toml`.
- **The installed name has no `v`.** Releases are named `24.21.0`, and a `v` in
  what you type is dropped.

## Where Node.js is

| Scope | Where `node` comes from |
| --- | --- |
| `--global` | `~/.vfox/sdks/nodejs`, a link to the release. `~/.vfox/sdks/nodejs/bin` is on `PATH` |
| `--project` | `.vfox/sdks/nodejs` in the project, a link to the release, and the name in `.vfox.toml` |
| session (the default) | a directory under `~/.vfox/tmp/<date>-<pid>/nodejs` |

The release itself is `~/.vfox/cache/nodejs/v-<version>/nodejs-<version>/`, with
`bin/node`, `bin/npm` and `lib/node_modules`. `vfox info nodejs@24.21.0` prints
the directory above it. `~/.vfox` is the default `$VFOX_HOME`. When `VFOX_HOME`
is set (to a directory that exists), the plugin and the releases (`cache/`) live
there, while the `sdks/nodejs` link and the session directories stay in
`~/.vfox`. `storage.sdkPath` moves the releases to `<path>/nodejs/` for new
installs, see vfox's
[configuration](https://vfox.dev/guides/configuration.html). On Windows `node.exe`
is directly in the release directory.

## Reporting a problem

Open an issue at
[version-fox/vfox-nodejs](https://github.com/version-fox/vfox-nodejs/issues) with
the output of `vfox --version` and `vfox info nodejs`, the operating system and
CPU, the command, and everything it printed. `vfox --debug <command>` prints
more, and so does `vfox --debug env -s bash` for a `.nvmrc`. Problems of vfox
itself belong with [vfox](https://github.com/version-fox/vfox/issues).
