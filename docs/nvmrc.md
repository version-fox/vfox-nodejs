# `.nvmrc` and `.node-version`

[中文](zh-CN/nvmrc.md) | [English](nvmrc.md)

vfox can read `.nvmrc`, the project file of [nvm](https://github.com/nvm-sh/nvm),
and `.node-version`, the one that nodenv, fnm and others use, through this
plugin (it lists both in `PLUGIN.legacyFilenames`). A project that already pins
its Node.js version for one of those tools needs no second file for vfox:

```text
# .nvmrc
22.23.3
```

## Using it

```bash
eval "$(vfox activate bash)"       # once, in ~/.bashrc; other shells: see vfox's quick start

vfox install nodejs@22.23.3        # these files never install anything
cd my-project                      # holds the .nvmrc above
node -v                            # v22.23.3
```

vfox's shell hook reads the file when you enter the directory and selects the
release it names. `vfox use` is not needed. The hook is vfox's own, see its
[quick start](https://vfox.dev/guides/quick-start.html) for zsh, fish,
PowerShell and the others.

- The file is read from the current directory only. In a subdirectory of the
  project it is not found, so after `cd packages/app` you are back to the global
  version.
- With both files in a directory, `.node-version` wins.
- A `.vfox.toml` in the same directory that names `nodejs` wins over both, and
  so does a `.tool-versions` (asdf's file) that names it. `vfox use --project`
  writes a `.vfox.toml`.
- In that directory the file also outranks a `vfox use` without `--project`: the
  next prompt switches back, while `vfox current nodejs` still names the choice
  of the session.
- vfox creates `.vfox/sdks/nodejs` in that directory and does not add `.vfox/` to
  `.gitignore`, so `git status` lists it. Ignore it yourself.
- The release has to be installed already. When nothing installed matches, the
  file is ignored and no message is printed. `vfox list nodejs` shows what there
  is.
- `vfox config legacyVersionFile.enable false` turns all legacy files off, for
  every plugin. The default is `true`.

## The strategy decides

What the file's text can name depends on `legacyVersionFile.strategy`, a
setting of vfox:

```bash
vfox config legacyVersionFile.strategy latest_installed
```

| Strategy | What happens with the text |
| --- | --- |
| `specified` (the default) | It is used as the version. Only a full release number (`22.23.3`) selects something, as vfox looks for an installed release of exactly that name. No network |
| `latest_installed` | The newest installed release that starts with the text is selected. No network, until no installed release matches: then the plugin asks the index as `latest_available` does, and the answer counts only if that release is installed |
| `latest_available` | The newest release in the index that starts with the text is the answer, and it selects something only if that release is installed. The plugin downloads `index.json` (about 330 KB) at every prompt in a directory with a legacy file |

Pick `latest_installed` if the files of your projects say `22`, `lts/jod` or
`lts/*`. Keep `specified` if they say `22.23.3`. `latest_available` needs the
network at every prompt, and a prompt in such a directory waits for it.

## What the file may hold

Before it looks at the text, the plugin removes all whitespace, drops a leading
`v`, makes the rest lower case and turns `lts-jod` into `lts/jod`. So
`v22.23.3`, a CRLF file and blanks around the version are fine. A name such as
`lts/jod` becomes the major of its line (22) with the table in
[lts.md](lts.md), except under `latest_available`, where the index is asked for
the newest release with that codename. A release number may end in `x`, `X` or
`*` for the parts it leaves open: `22.x`, `22.x.x` and `22.*` all mean 22.

Unreleased: release 0.5.2 drops every `v` of the file, so a codename with a `v`
in it does not match, and it does not know `22.x`.

The results on 2026-10-21 with 20.20.2, 22.23.3, 24.21.0, 25.9.0 and 26.12.0
installed, when 24.22.0 is the newest 24.x and 22.23.3 the newest 22.x:

| In the file | `specified` | `latest_installed` | `latest_available` |
| --- | --- | --- | --- |
| `22.23.3`, `v22.23.3` | 22.23.3 | 22.23.3 | 22.23.3 |
| `22`, `v22`, `22.x`, `22.*` | nothing | 22.23.3 | 22.23.3 |
| `22.23` | nothing | 22.23.3 | 22.23.3 |
| `lts/jod`, `lts-jod`, `LTS/Jod` | nothing | 22.23.3 | 22.23.3 |
| `lts/krypton` | nothing | 24.21.0 | nothing: 24.22.0 is the newest and is not installed |
| `lts/*`, `lts` | nothing | 24.21.0 | nothing: 24.22.0 is the newest LTS release and is not installed |
| `18.20.8` or any release that is not installed | nothing | nothing | nothing |

`latest_available` does not fall back to an older installed release. When the
index names a newer release than the one you have, nothing is selected. Use
`latest_installed` if you want the newest one you have.

`lts` and `lts/*` mean the newest LTS line. Under `specified` and
`latest_installed` that is the highest major in the codename table (24 at the
time of writing), under `latest_available` the newest release that carries any
codename in the index. See [lts.md](lts.md) for the table and what happens
when Node.js promotes a new line.

## Not understood

The plugin understands less than nvm does. These select nothing, under every
strategy:

- Aliases: `node`, `stable`, `latest`, `unstable`, `system`.
- `lts/-1` and the other relative forms of nvm, and a codename without `lts/`
  (`iron`, `jod`).
- Version ranges: `>=20`, `^22.0.0`, `~22.23`, and an `x` before a number
  (`22.x.1`).
- Comments. `# pin` on its own line, or `22.23.3 # pin`, becomes part of the
  text, as all whitespace is removed before the text is read.
- An empty file.

## How a prefix is matched

`latest_installed` and `latest_available` compare the text with the start of
each release, part by part and as numbers, and take the newest release that
starts with it:

- `22.2` matches 22.2.x, and not 22.23.3.
- vfox hands over the installed releases sorted as text, descending, so `22.9.0`
  comes before `22.23.3`. The plugin does not go by that order: with 22.9.0,
  22.3.0 and 22.23.3 installed, `22` selects 22.23.3 and `22.3` selects 22.3.0.
  `vfox use nodejs@22` compares numbers as well.

Unreleased: release 0.5.2 compares text, and takes the first installed release
that starts with it. `22.2` also matches `22.23.3`, and with 22.9.0 and 22.23.3
installed `22` under `latest_installed` selects 22.9.0 (checked with 22.9.0,
22.3.0 and 22.23.3 installed). Keep one release per line installed, or write the
full release number, to get the same answer there. The text is also used as a
Lua pattern, so `22.*` happens to work and `22.x` does not.

## Not finding it

If the release does not switch:

- The shell hook is not active. `eval "$(vfox activate bash)"` has to run in
  the shell, not only once somewhere else.
- The shell is in a subdirectory of the one with the file.
- The release is not installed. `vfox install nodejs@22.23.3`.
- The strategy is `specified` and the file holds `22` or `lts/jod`.
- Under `latest_available`, a newer release than the installed one is out.
- A `.vfox.toml` or `.tool-versions` is in the way, or `legacyVersionFile.enable`
  is `false`.
- The text is on the list above, or has a comment in it.

`vfox --debug env -s bash` prints what the plugin returned and what vfox did
with it:

```text
Parsing legacy file /home/me/project/.nvmrc
CallFunction: ParseLegacyFile
Found nodejs@22
SDK nodejs@22 from project scope not installed, trying lower-priority config
```

## Differences from nvm

`nvm install` installs what `.nvmrc` names, and `nvm use` with no argument reads
it. vfox only selects among what is installed, and you install with `vfox
install nodejs@<version>`. A line of an `.nvmrc` is not always a spec that `vfox
install` takes: `22.23.3` is, `22` is, `lts/jod` is not (see
[lts.md](lts.md#installing-an-lts-line)).
