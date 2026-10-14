# LTS releases

Node.js majors with even numbers become **LTS** (long-term support) lines:
they keep receiving fixes long after odd releases go end-of-life, so most
production setups pin an LTS line. Each LTS line has a codename
(`argon` for 4, `boron` for 6, …, `krypton` for 24).

## What this plugin understands

Under the `latest_available` strategy the plugin discovers LTS codenames
dynamically from the version index (`index.json` carries the codename in
each release's `lts` field), so codenames that postdate this plugin keep
working there. Everywhere else — and as the offline fallback — a hardcoded
table in `hooks/parse_legacy_file.lua` is used, because `specified` and
`latest_installed` must resolve without network access:

| Codename | Major |
| -------- | ----- |
| argon | 4 |
| boron | 6 |
| carbon | 8 |
| dubnium | 10 |
| erbium | 12 |
| fermium | 14 |
| gallium | 16 |
| hydrogen | 18 |
| iron | 20 |
| jod | 22 |
| krypton | 24 |

## Examples

Given an `.nvmrc` (the same applies to `.node-version`) and
`22.23.3` plus `24.21.0` installed:

```sh
# 1. LTS codename -> major, then strategy picks the release.
$ cat .nvmrc
lts/jod
$ vfox config legacyVersionFile.strategy latest_installed
$ cd <dir-with-.nvmrc> && eval "$(vfox activate bash)" && eval "$(vfox env -s bash)" && node --version
v22.23.3
```

```sh
# 2. Bare `lts` (or `lts/*`) means "the highest mapped major", currently 24.
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

## E2E coverage

The legacy-file suite needs an installed release whose major is inside the
table, independently of the pinned release under test. `LTS_NODE_VERSION`
(default `24.21.0`) provides it: the exact-version probes target
`NODE_VERSION` while the `lts/<codename>` probe targets the LTS release.

```sh
# Narrow the matrix and watch the codename probe pick the LTS release:
VFOX_VERSION=latest MIRROR=default E2E_MAX_JOBS=1 LTS_NODE_VERSION=24.21.0 \
  docker compose -f tests/e2e/linux/compose.yaml run --rm e2e
# PASS legacy files select 26.11.1 (.nvmrc, .node-version) and 24.21.0 (lts/krypton)
```

The E2E `LTSCodename` helper (`tests/e2e/common/common.go`) mirrors the
plugin's table, so both sides stay in sync. See [e2e](e2e.md).
