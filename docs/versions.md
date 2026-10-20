# Versions and names

[中文](zh-CN/versions.md) | [English](versions.md)

The part after `nodejs@` in `vfox install` and `vfox use` is a Node.js release
number, or the start of one:

```bash
vfox install nodejs@24.21.0    # exactly this release
vfox install nodejs@24.21      # newest 24.21.x
vfox install nodejs@24         # newest 24.x
vfox install nodejs@latest     # newest release of any line
```

There are no names such as `lts`, `lts/iron` or `stable` here. For a line that
is in long-term support, name the line (`nodejs@24`), see [lts.md](lts.md).
`.nvmrc` files do understand `lts/<codename>`, see [nvmrc.md](nvmrc.md).

## Installing

`vfox install` asks the plugin which package matches, then vfox downloads it,
checks it and unpacks it. These are the answers on 2026-10-21:

| You type | Installs |
| --- | --- |
| `24.21.0` | `24.21.0` |
| `v24.21.0` | `24.21.0`, vfox drops the `v` |
| `24.21` | `24.21.0`, the newest 24.21.x |
| `24` | `24.22.0`, the newest 24.x |
| `latest` | `26.12.0`, the newest release in the index. vfox prints `Using latest version: 26.12.0` first |

- "Newest" is the highest number among the releases that the index lists, LTS
  or not. A line that is not in long-term support yet, such as 26 today, can be
  newer than the newest LTS line, so `latest` is not "the LTS".
- `24` and `24.21` are looked up in the index, not among what is installed.
  `vfox install nodejs@24` installs a newer 24.x than the one you have, and
  prints `nodejs@24.22.0 is already installed` once you have the newest.
- The index lists releases with three numbers, and nothing else: no `-rc`
  builds, nightlies or four-part numbers. Those end in `version not found for
  provided version ...`.
- A release number that does not exist (`24.99.0`) ends in `get checksum
  failed: HTTP 404 from ...`, as nodejs.org has no directory for it. A release
  that exists but has no package for your platform ends in `Node.js package ...
  is not listed in ...`. See
  [troubleshooting.md](troubleshooting.md#messages-from-the-plugin) and
  [platforms.md](platforms.md).
- Every download is checked against the SHA-256 sum in the release's
  `SHASUMS256.txt`. vfox prints `Verifying checksum <sum>...` and, when the sums
  differ, stops with `checksum error` and installs nothing.
- An install that finds the name already present downloads nothing.

A mirror changes where the files come from, not what the names mean, see
[mirror.md](mirror.md).

## Installed names

The name of an install is the release number: no `v`, no platform, no flavour.
`vfox list nodejs` shows the names, with the one in use marked. vfox sorts them
as text, highest first, so `22.9.0` comes before `22.23.3`:

```text
$ vfox list nodejs
-> 26.12.0
-> 24.21.0 <— current
-> 22.9.0
-> 22.23.3
-> 20.20.2
```

`vfox uninstall` needs the whole name:

```bash
vfox uninstall nodejs@22.23.3
```

`vfox uninstall nodejs@22` and `nodejs@22.23` answer `is not installed`. When you
uninstall the release in use, vfox switches to the first entry that is left in
`vfox list nodejs`, and says so (`Auto switch to the other version.`), which can
be another line.

The files live in `~/.vfox/cache/nodejs/v-<version>/nodejs-<version>/`, see
[troubleshooting.md](troubleshooting.md#where-nodejs-is).

## Using

`vfox use` maps what you type to an installed release and downloads nothing:

| You type | Selects |
| --- | --- |
| `24.21.0`, `v24.21.0` | that release |
| `24.21` | the newest installed 24.21.x |
| `24` | the newest installed 24.x |
| anything else, such as `lts` or `99` | nothing: `nodejs@lts is not installed` |

"Newest" compares the numbers, so with 22.3.0, 22.9.0 and 22.23.3 installed
`nodejs@22` selects 22.23.3 and `nodejs@22.3` selects 22.3.0. A shorthand has
to match something installed: with only 22.23.3 installed, `nodejs@22.2` selects
nothing, as there is no 22.2.x.

Pick the scope with `vfox use`'s flags: `--global`, `--project` or `--session`,
the default. All of them need vfox's shell hook (`eval "$(vfox activate
bash)"` for bash). Without it, `vfox use` stops on Linux with:

```text
vfox requires hook support. Please ensure vfox is properly initialized with 'vfox activate'
```

`--project` writes a `.vfox.toml` that holds the installed name:

```toml
[tools]
nodejs = "22.23.3"
```

A `.nvmrc` or `.node-version` in the same directory is read as well, see
[nvmrc.md](nvmrc.md). `vfox use` prints a note when another `node` comes before
vfox in `PATH`, see [pnpm.md](pnpm.md).

## Searching

```bash
vfox search nodejs
```

Each line is a name that can follow `nodejs@`, newest first. After the name
come `(LTS)` for releases of a line in long-term support, the npm that comes
with the release, and `(installed)`:

```text
$ vfox search nodejs
Available versions:
 - 26.12.0 [npm 11.20.0] (installed)
 - 26.11.1 [npm 11.20.0]
 ...
 - 24.22.0 (LTS) [npm 11.19.1]
 - 24.21.0 (LTS) [npm 11.19.0] (installed)
 ...
 - 0.6.3 [npm 1.1.0-alpha-2]
 - 0.6.2 [npm ]
```

- The list is the `index.json` of nodejs.org, or of your
  [mirror](mirror.md): 872 releases from 0.1.14 to 26.12.0 on 2026-10-21. npm
  is listed from 0.6.3 on and empty before that.
- `(LTS)` is the `lts` field of the index, which Node.js sets from the day a
  line enters long-term support. 24.11.0 is the first release of Krypton with
  it, 24.10.0 and the releases before have none. See [lts.md](lts.md).
- The plugin ignores arguments: `vfox search nodejs 24` prints the same full
  list. To filter, pipe it, for example `vfox search nodejs | grep '^ - 24\.'`.
  In a pipe vfox only prints.
- In an interactive terminal vfox shows a picker instead (`Please select a
  version of nodejs to install [type to search]`): arrow keys move, typing
  filters, Enter confirms.
- The list holds every release, whether or not your platform has a package for
  it, see [platforms.md](platforms.md).
- vfox caches the list for 12 hours (`vfox config cache.availableHookDuration`),
  so a release published a minute ago can be missing. `vfox config
  cache.availableHookDuration 0` turns the cache off.
- When the index cannot be fetched, the search fails with `Failed to fetch
  Node.js versions: ...` rather than listing nothing, see
  [troubleshooting.md](troubleshooting.md#network).

`vfox install nodejs 24` does not install 24: arguments separated by spaces
are several SDKs, and it stops with `install requires specifying a version for
nodejs`. Write `nodejs@24`.
