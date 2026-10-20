# LTS releases

[中文](zh-CN/lts.md) | [English](lts.md)

Node.js majors with even numbers become **LTS** (long-term support) lines:
they keep receiving fixes long after odd releases go end-of-life, so most
production setups pin an LTS line. Each LTS line has a codename
(`argon` for 4, `boron` for 6, …, `krypton` for 24).

## Installing an LTS line

The plugin has no `lts` alias for `vfox install`: `vfox install nodejs@lts`
stops with `version not found for provided version lts`. Name the line instead,
which installs the newest release of it:

```bash
vfox install nodejs@24
```

`vfox search nodejs` marks the releases of LTS lines with `(LTS)`, so the newest
LTS release is the first line that has the mark:

```text
$ vfox search nodejs | grep -m1 '(LTS)'
 - 24.22.0 (LTS) [npm 11.19.1]
```

Install it with `vfox install nodejs@24.22.0`, or with `nodejs@24` to follow the
line. The mark is the `lts` field of the version index, which Node.js sets from
the day a line enters long-term support: 24.11.0 is the first release of
Krypton with it, 24.10.0 and the ones before have none. `lts/<codename>` is
understood in `.nvmrc` and `.node-version` files only, see
[nvmrc.md](nvmrc.md).

## What this plugin understands

Under the `latest_available` strategy the plugin discovers LTS codenames
dynamically from the version index (`index.json` carries the codename in
each release's `lts` field), so codenames that postdate this plugin keep
working there. Everywhere else — and as the offline fallback — a hardcoded
table in `hooks/parse_legacy_file.lua` is used, because `specified` and
`latest_installed` must resolve without network access. "First LTS release" and
"Last release" are from the index on 2026-10-21, and Krypton is still receiving
releases:

| Codename | Major | First LTS release | Last release |
| -------- | ----- | ----------------- | ------------ |
| argon | 4 | 4.2.0 | 4.9.1 |
| boron | 6 | 6.9.0 | 6.17.1 |
| carbon | 8 | 8.9.0 | 8.17.0 |
| dubnium | 10 | 10.13.0 | 10.24.1 |
| erbium | 12 | 12.13.0 | 12.22.12 |
| fermium | 14 | 14.15.0 | 14.21.3 |
| gallium | 16 | 16.13.0 | 16.20.2 |
| hydrogen | 18 | 18.12.0 | 18.20.8 |
| iron | 20 | 20.9.0 | 20.20.2 |
| jod | 22 | 22.11.0 | 22.23.3 |
| krypton | 24 | 24.11.0 | 24.22.0 |

## When Node.js promotes a line

An even-numbered line enters long-term support each October and gets its
codename then. The [release schedule](https://github.com/nodejs/Release) puts
Node.js 26 on 2026-10-28, with no codename announced yet.

- Under `latest_available` the plugin finds the new codename in the index the
  day it appears. `lts` and `lts/*` then name the newest release of the new
  line.
- Under `specified` and `latest_installed` the table above decides, and the
  table changes with a release of the plugin. Until then `lts/<new codename>`
  selects nothing, and `lts` and `lts/*` keep meaning the highest line in the
  table, 24 at the time of writing.
- `(LTS)` in `vfox search` follows the index, so it changes at once.

The table is in `hooks/parse_legacy_file.lua`, see
[development.md](development.md#when-nodejs-promotes-a-line-to-lts).

## Examples

Given an `.nvmrc` (the same applies to `.node-version`) and
`22.23.3` plus `24.21.0` installed. Examples 1 to 4 run under the
`latest_installed` strategy that example 1 sets, see
[nvmrc.md](nvmrc.md#the-strategy-decides) for the strategies:

```sh
# 1. LTS codename -> major, then strategy picks the release.
$ cat .nvmrc
lts/jod
$ vfox config legacyVersionFile.strategy latest_installed
$ cd <dir-with-.nvmrc> && eval "$(vfox activate bash)" && eval "$(vfox env -s bash)" && node --version
v22.23.3
```

```sh
# 2. Bare `lts` (or `lts/*`) means "the highest mapped major", 24 at the time
# of writing.
$ printf 'lts\n' > .nvmrc
$ cd <dir-with-.nvmrc> && eval "$(vfox activate bash)" && eval "$(vfox env -s bash)" && node --version
v24.21.0
```

```sh
# 3. An exact version skips the codename table entirely.
$ printf '22.23.3\n' > .nvmrc
$ cd <dir-with-.nvmrc> && eval "$(vfox activate bash)" && eval "$(vfox env -s bash)" && node --version
v22.23.3
```

```sh
# 4. The current LTS line works the same way.
$ printf 'lts/krypton\n' > .nvmrc
$ cd <dir-with-.nvmrc> && eval "$(vfox activate bash)" && eval "$(vfox env -s bash)" && node --version
v24.21.0
```

```sh
# 5. Under latest_available the index is consulted, so even a codename
# newer than the table above resolves (offline it falls back to the table).
$ vfox config legacyVersionFile.strategy latest_available
$ printf 'lts/<future-codename>\n' > .nvmrc
$ cd <dir-with-.nvmrc> && eval "$(vfox activate bash)" && eval "$(vfox env -s bash)" && node --version
v<newest release carrying that codename>
$ vfox config legacyVersionFile.strategy specified
```

How example 1 resolves, step by step (`latest_installed`):

```
.nvmrc "lts/jod" --resolve_version--> "22" --prefix-match installed--> "22.23.3"
```
