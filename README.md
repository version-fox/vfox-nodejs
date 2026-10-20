# vfox-nodejs

[中文](README_CN.md) | [English](README.md)

Node.js plugin for [vfox](https://vfox.dev/).

It installs the Node.js release archives published on
[nodejs.org](https://nodejs.org/dist/), or on a [mirror](docs/mirror.md) of it,
and checks every download against the SHA-256 sums published next to it. Each
release comes with its own npm. On Alpine, OpenWrt and other musl systems it
installs the musl builds. vfox reads `.nvmrc` and `.node-version` through it.

## Install

After installing [vfox](https://github.com/version-fox/vfox), install the plugin by running:

```bash
vfox add nodejs
```

vfox has to be hooked into your shell for `node` to be on the `PATH`, see its
[quick start](https://vfox.dev/guides/quick-start.html).

### Example

```bash
vfox add nodejs
vfox install nodejs@24
vfox use --global nodejs@24
```

You can verify this using the following command:

```bash
node -v
```

`vfox search nodejs` lists every release, with the npm that comes with it and a
mark on the ones of an LTS line. In an interactive terminal it lets you pick one.

Behavior that only exists on `main` and not in the latest release is marked
"Unreleased" in the pages below. [docs/changes.md](docs/changes.md) lists it, and
[docs/source-build.md](docs/source-build.md) gets you `main`.

### Example: Ubuntu 26.04

```bash
vfox add nodejs
vfox install nodejs@26.11.1
sudo apt install --assume-yes libatomic1
vfox use --global nodejs@26.11.1
```

Note: the `libatomic1` step works around an upstream Node.js packaging bug
([nodejs/node#60790](https://github.com/nodejs/node/issues/60790), still
open): Node 25+ links `libatomic.so.1`, which stock Debian/Ubuntu images do
not ship. System libraries are the user's responsibility; the plugin does
not install them.

### Example: Alpine / musl

```bash
apk add bash libstdc++ libatomic
vfox add nodejs
vfox install nodejs@24
vfox use --global nodejs@24
```

The Node.js musl builds need `libstdc++`, and the ones of 26.8.0 and later need
`libatomic` as well. A stock Alpine image has neither, and the plugin does not
install system libraries. The install stops with a message that names the
missing package and the command that installs it (`apk add libatomic`; OpenWrt
calls `libstdc++` the `libstdcpp` package). Unreleased: release 0.5.2 checks for
`libstdc++` only, and a missing `libatomic` shows when `node` fails with `Error
loading shared library libatomic.so.1`. musl builds exist for x64 and arm64
only. musl details (OpenWrt, tarball matrix, mirror fallback, which releases
have a build): see [docs/musl.md](docs/musl.md).

## Versions and names

A version is a release number: `24.21.0`, or the start of one, `24.21` and `24`,
which install the newest release of that line. `latest` is the newest release of
any line, LTS or not. There is no `lts` alias, name the line (`nodejs@24`). The
name of an install is the release number, `24.21.0`, and `vfox uninstall` needs
it whole. See [docs/versions.md](docs/versions.md) for details, including what
`vfox use` and `vfox search` do with them.

## Platforms

Node.js publishes packages for Linux (x64, arm64, ppc64le, s390x), macOS (x64 and
arm64) and Windows (x64, arm64, and x86 up to 22.x). Not every release has every
one of them: Windows on ARM starts at 19.9.0, Linux arm64 at 4.0.0, Apple silicon
at 16.0.0 (older releases install the x64 package under Rosetta 2). 32-bit ARM
Linux has packages up to 23.11.1. Unreleased: release 0.5.2 cannot install them.
riscv64 and loong64 are not supported. `vfox search` lists every release
whatever your platform is. See [docs/platforms.md](docs/platforms.md) for the
table.

## npm and global packages

Packages installed with `npm install -g` belong to the Node.js release that was in
use, and are gone from the others. Node.js 25 and later does not ship Corepack.
See [docs/npm.md](docs/npm.md).

## Mirror

Set `VFOX_NODEJS_MIRROR` to use a mirror of `nodejs.org/dist`, for example
`https://npmmirror.com/mirrors/node`. See [docs/mirror.md](docs/mirror.md) for
details and for mirrors that were checked.

## `.nvmrc` and `.node-version`

vfox reads these files when you enter a directory, and selects the release they
name if it is installed. What a file can say depends on vfox's
`legacyVersionFile.strategy`: with the default, `specified`, only a full release
number selects something. See [docs/nvmrc.md](docs/nvmrc.md) for details.

## LTS

See [docs/lts.md](docs/lts.md) for the LTS lines, how to install one and how
`lts/<codename>` is resolved.

## pnpm

pnpm as a package manager works next to this plugin. A `node` that pnpm installs
itself can shadow vfox's. See [docs/pnpm.md](docs/pnpm.md).

## Troubleshooting

See [docs/troubleshooting.md](docs/troubleshooting.md) for the messages the
plugin prints, proxies and where Node.js is.

## Install from source

See [docs/source-build.md](docs/source-build.md) for details.

## Development

See [docs/development.md](docs/development.md) for how the plugin works and how
to change it, [docs/e2e.md](docs/e2e.md) for the container tests, and
[docs/changes.md](docs/changes.md) for what changed in each release.

## Releasing this plugin

Maintainers can publish from **Actions → Plugin → Run workflow** on the default
branch by entering a stable plugin version without the `v` prefix. The shared
workflow updates `metadata.lua`, creates the version commit and tag, and publishes
the ZIP and manifest in this repository. No local tag or extra release token is
needed. Pull requests run checks only; PR titles no longer trigger publication.

Existing version-tag pushes are supported when `PLUGIN.version` already matches
the tag. If publication fails, re-run the original failed job to resume it.

The workflow follows the shared `@v1` release-tool version. Updating the tool does
not release this plugin. See the [shared workflow documentation](https://github.com/version-fox/plugin-manifest-action)
for the package contract and first-rollout requirements.

## Thanks

- [Node.js](https://nodejs.org/), whose release archives, checksums and version
  index the plugin installs from
- [Node.js Unofficial Builds](https://github.com/nodejs/unofficial-builds), where
  the musl builds that nodejs.org lacks come from
