# Mirror

[中文](zh-CN/mirror.md) | [English](mirror.md)

The Node.js packages and the version index (`index.json`, `SHASUMS256.txt`)
are downloaded from `https://nodejs.org/dist` by default. Set
`VFOX_NODEJS_MIRROR` to use another mirror:

```bash
export VFOX_NODEJS_MIRROR="https://npmmirror.com/mirrors/node"
vfox install nodejs@26.11.1
```

Point it at the root that mirrors `nodejs.org/dist`; the plugin appends its
paths (`/index.json`, `/v<version>/...`) to that base URL. Trailing slashes
are handled, so both `https://nodejs.org/dist` and `https://nodejs.org/dist/`
work.

## Setting it

The variable is read from the environment of the process that runs vfox, so set
it where your shell does:

```bash
# bash, zsh: in ~/.bashrc or ~/.zshrc
export VFOX_NODEJS_MIRROR="https://npmmirror.com/mirrors/node"

# fish
set -Ux VFOX_NODEJS_MIRROR https://npmmirror.com/mirrors/node

# for one command
VFOX_NODEJS_MIRROR=https://npmmirror.com/mirrors/node vfox search nodejs
```

```powershell
# PowerShell: this session only
$env:VFOX_NODEJS_MIRROR = "https://npmmirror.com/mirrors/node"

# PowerShell: for the user, in the shells you open later
[Environment]::SetEnvironmentVariable("VFOX_NODEJS_MIRROR", "https://npmmirror.com/mirrors/node", "User")
```

An empty value is the same as unset: `https://nodejs.org/dist`.

## What a mirror has to serve

The same layout as `nodejs.org/dist`:

```text
<mirror>/index.json
<mirror>/v24.21.0/SHASUMS256.txt
<mirror>/v24.21.0/node-v24.21.0-linux-x64.tar.gz
```

- `index.json` decides what `vfox search nodejs`, `nodejs@latest`, `nodejs@24` and
  `nodejs@24.21` see. A mirror that lags behind lists fewer releases, and a
  release it lists but does not carry fails at the download.
- The sums in the mirror's own `SHASUMS256.txt` are what the download is checked
  against. A mirror whose files differ from its sums ends in `checksum error`.
- Redirects are followed. `https://npmmirror.com/mirrors/node` answers
  `index.json` with a redirect, and works.

## Mirrors that work

These were checked on 2026-10-21: each served an `index.json` with the same 872
releases as nodejs.org, the same SHA-256 sum for `node-v24.21.0-linux-x64.tar.gz`
and the package itself, and the musl package of 26.12.0. The list records that
and endorses nothing. A mirror can change or go away without the plugin knowing.

| Mirror | `VFOX_NODEJS_MIRROR` |
| --- | --- |
| npmmirror | `https://npmmirror.com/mirrors/node` (`https://cdn.npmmirror.com/binaries/node` is the same data) |
| Huawei Cloud | `https://mirrors.huaweicloud.com/nodejs` |
| Tsinghua University (TUNA) | `https://mirrors.tuna.tsinghua.edu.cn/nodejs-release` |
| USTC | `https://mirrors.ustc.edu.cn/node` |
| Alibaba Cloud | `https://mirrors.aliyun.com/nodejs-release` |
| Tencent Cloud | `https://mirrors.cloud.tencent.com/nodejs-release` |
| Nanjing University | `https://mirror.nju.edu.cn/nodejs-release` |
| Beijing Foreign Studies University | `https://mirrors.bfsu.edu.cn/nodejs-release` |

The Node.js mirror is not the npm registry. Packages that `npm install` fetches
come from the registry in your npm config, for example `npm config set registry
https://registry.npmmirror.com`, see [npm.md](npm.md).

## Checking that it applies

A mirror that does not answer fails instead of falling back to nodejs.org, which
is how you can tell the variable is read:

```bash
VFOX_NODEJS_MIRROR=https://example.invalid/dist vfox search nodejs
# Failed to fetch Node.js versions: Get "https://example.invalid/dist/index.json": ...
```

On the same mirror `vfox install nodejs@24.21.0` fails with `get checksum failed:
Get "https://example.invalid/dist/v24.21.0/SHASUMS256.txt": ...` (Unreleased:
release 0.5.2 leaves out what follows `failed`). A mirror that serves no
`index.json` at that address fails the search with
`Failed to fetch Node.js versions: HTTP 404`, see
[troubleshooting.md](troubleshooting.md#network). vfox caches the search for 12
hours, so after a change run `vfox config cache.availableHookDuration 0` or
expect the old list for a while.

A proxy is a different setting, and covers the mirror as well, see
[troubleshooting.md](troubleshooting.md#network).

## musl and unofficial builds

`VFOX_NODEJS_MIRROR` only covers `nodejs.org/dist`. It does **not** apply to
`https://unofficial-builds.nodejs.org/download/release`, which the plugin
uses as a fallback on musl Linux (see [musl](musl.md)):

- Linux musl x64 on a release that nodejs.org carries (22.23.3, 24.20.0 to
  24.22.0, 26.8.0 and later): the official `*-musl` tarball is used, so the
  mirror applies normally (as long as the mirror carries it).
- Linux musl arm64 (all releases), or musl x64 on any other release: the
  official index has no such file, so the plugin downloads from
  `unofficial-builds.nodejs.org` directly, ignoring the mirror.

A mirror that cannot even serve `SHASUMS256.txt` still fails the install
instead of falling back; only a missing musl filename falls through to
unofficial builds.
