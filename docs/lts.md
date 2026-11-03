# LTS releases

[中文](zh-CN/lts.md) | [English](lts.md)

Node.js majors with even numbers become **LTS** (long-term support) lines:
they keep receiving fixes long after odd releases go end-of-life, so most
production setups pin an LTS line. Each LTS line has a codename
(`argon` for 4, `boron` for 6, …, `lithium` for 26).

## Installing an LTS line

The plugin has no `lts` alias for `vfox install`: `vfox install nodejs@lts`
stops with `version not found for provided version lts`. Name the line instead,
which installs the newest release of it:

```bash
vfox install nodejs@24
```

`vfox search nodejs` marks the releases of LTS lines with `(LTS)`, so the newest
LTS release is the first line that has the mark (on 2026-11-03):

```text
$ vfox search nodejs | grep -m1 '(LTS)'
 - 26.13.0 (LTS) [npm 11.20.0]
```

Install it with `vfox install nodejs@26.13.0`, or with `nodejs@26` to follow the
line. The mark is the `lts` field of the version index, which Node.js sets from
the day a line enters long-term support: 24.11.0 is the first release of
Krypton with it, 24.10.0 and the ones before have none. `lts/<codename>` is
understood in `.nvmrc` and `.node-version` files only, see
[nvmrc.md](nvmrc.md).

## What this plugin understands

`index.json` carries the codename of an LTS line in the `lts` field of each
release (`"lts": "Lithium"`, and `false` for a release outside long-term
support). The plugin reads the codenames from there, and not from a list that a
maintainer has to keep up:

- Under the `latest_available` strategy it asks the index when it reads the
  file, at every prompt in the directory, so a codename that postdates the
  plugin works on the day it appears.
- Under `specified` and `latest_installed` the plugin runs at every prompt too,
  and must not fetch the index each time. It uses what it learned the last time
  it had the index in hand: when `vfox search`, or an install of `latest` or of
  a major such as `nodejs@26`, asks it for the list of releases (vfox keeps the
  answer for a while, so not every search does), and when it installs a release
  and the file is missing or a day old. It keeps what it learned in `.lts-cache`
  next to the plugin, where vfox keeps its `.available.cache`. Delete the file
  to make it forget, and it learns again at the next install.
- Before it has learned anything, or where it cannot write the file, it uses
  the table below. The table is a start: a line that is missing from it is
  learned as soon as the plugin has had the index in hand.

"First LTS release" and "Last release" are from the index on 2026-11-03, and
Jod, Krypton and Lithium are still receiving releases:

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
| jod | 22 | 22.11.0 | 22.23.4 |
| krypton | 24 | 24.11.0 | 24.22.2 |
| lithium | 26 | 26.13.0 | 26.13.0 |

## When Node.js promotes a line

An even-numbered line enters long-term support each October and gets its
codename then. Node.js 26 did on 2026-10-28, as Lithium: 26.13.0 is the first
release with the `lts` mark in the index. What a promotion looks like in
practice:

- Under `latest_available` the plugin finds the new codename in the index the
  day it appears. `lts` and `lts/*` then name the newest release of the new
  line, and `lts/lithium` worked there at once, with release 0.5.3 as well.
- Under `specified` and `latest_installed` the plugin knows the line from the
  first time it has the index in hand after the promotion: the `vfox search` or
  the install that brings you the new line. `latest_installed` selects nothing
  until a release of the line is installed, so that is early enough. Until then
  `lts/<new codename>` selects nothing, and `lts` and `lts/*` mean the newest
  line that the plugin knows.
- `(LTS)` in `vfox search` follows the index, so it changes at once.

Unreleased: release 0.5.3 has the table only, and no file. The table was
published before Lithium and ends at Krypton, so with 22.23.4, 24.22.2 and
26.13.0 installed on 2026-11-03 it selected 24.22.2 for `lts/*` and nothing for
`lts/lithium` under `latest_installed`, and only a release of the plugin adds a
line there. How the plugin learns is in
[development.md](development.md#what-the-plugin-learns-about-lts-lines).

## Examples

Given an `.nvmrc` (the same applies to `.node-version`) and
`22.23.4`, `24.21.0` and `26.13.0` installed, as on 2026-11-03. Examples 1 to 4
run under the `latest_installed` strategy that example 1 sets, see
[nvmrc.md](nvmrc.md#the-strategy-decides) for the strategies:

```sh
# 1. LTS codename -> major, then strategy picks the release.
$ cat .nvmrc
lts/jod
$ vfox config legacyVersionFile.strategy latest_installed
$ cd <dir-with-.nvmrc> && eval "$(vfox activate bash)" && eval "$(vfox env -s bash)" && node --version
v22.23.4
```

```sh
# 2. Bare `lts` (or `lts/*`) means "the newest LTS line that the plugin knows",
# 26 at the time of writing (Unreleased: 24 in release 0.5.3).
$ printf 'lts\n' > .nvmrc
$ cd <dir-with-.nvmrc> && eval "$(vfox activate bash)" && eval "$(vfox env -s bash)" && node --version
v26.13.0
```

```sh
# 3. An exact version needs no codename.
$ printf '22.23.4\n' > .nvmrc
$ cd <dir-with-.nvmrc> && eval "$(vfox activate bash)" && eval "$(vfox env -s bash)" && node --version
v22.23.4
```

```sh
# 4. The current LTS line works the same way, and so does the one before it.
$ printf 'lts/lithium\n' > .nvmrc
$ cd <dir-with-.nvmrc> && eval "$(vfox activate bash)" && eval "$(vfox env -s bash)" && node --version
v26.13.0
$ printf 'lts/krypton\n' > .nvmrc
$ cd <dir-with-.nvmrc> && eval "$(vfox activate bash)" && eval "$(vfox env -s bash)" && node --version
v24.21.0
```

```sh
# 5. Under latest_available the index is consulted, so even a codename that
# the plugin has not learned yet resolves (offline it falls back to what the
# plugin learned, then to the table above).
$ vfox config legacyVersionFile.strategy latest_available
$ printf 'lts/<future-codename>\n' > .nvmrc
$ cd <dir-with-.nvmrc> && eval "$(vfox activate bash)" && eval "$(vfox env -s bash)" && node --version
v<newest release carrying that codename>
$ vfox config legacyVersionFile.strategy specified
```

How example 1 resolves, step by step (`latest_installed`):

```
.nvmrc "lts/jod" --resolve_version--> "22" --prefix-match installed--> "22.23.4"
```
