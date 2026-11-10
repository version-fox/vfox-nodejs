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

vfox's shell hook reads the file at every prompt in the directory and selects
the release it names, so a `cd` into the directory switches, and so does a
change of the file. Leaving the directory for one with no config at all
switches back to the global release on vfox 1.1.0 and later. Unreleased:
release 0.5.5 keeps the file's release there. `vfox use` is not needed. The
hook is vfox's own, see its
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

## When the file is read

vfox works out the environment of a shell at its first prompt and keeps the
result in `env-state.json` in the session directory. At every prompt it reads
the version files of the current directory and works the environment out
again when what they resolve to changed. On vfox 1.1.0 and later a `cd` into
a directory with a `.nvmrc` or `.node-version` switches, a `cd` from one such
directory to another does, a change of the file takes effect at the next
prompt, and leaving for a directory with no config at all switches back to
the global release. A prompt with nothing changed reuses the kept result
(`Using cached output`). Unreleased: release 0.5.5 works the environment out
again at every prompt in such a directory, by removing `env-state.json`
whenever vfox asks the plugin to read the file, and never switches back on
the way out.

This is what `node -v` printed in one shell, step by step, with vfox 1.1.0 and
26.13.0 as the global release (bash 5.3):

| Step | `node -v` |
| --- | --- |
| A shell that starts in a directory with a `.nvmrc` that names 18.20.8 | v18.20.8 |
| A shell that starts in a directory with no config at all | v26.13.0 |
| `cd` into the directory with the `.nvmrc` for 18.20.8 | v18.20.8 |
| `cd` into a directory with a `.node-version` that names 24.22.2 | v24.22.2 |
| Edit that `.node-version` to name 22.23.4 | v22.23.4 |
| `cd` into a directory with no config at all | v26.13.0 |
| `cd` into a directory with a `.vfox.toml` that names 18.20.8 | v18.20.8 |
| `cd` into a directory with no config at all | v26.13.0 |

The first row is a shell of its own, the other seven follow one another in a
second shell. `vfox --debug env -s bash` shows both cases. The first prompt
after a change, in a directory with a `.nvmrc`, parses the file and
calculates:

```text
Parsing legacy file /home/me/projects/legacy-api/.nvmrc
CallFunction: ParseLegacyFile
Found nodejs@18.20.8
Config changed: true, configPaths: map[global:/home/me/.vfox/.vfox.toml]
CallFunction: EnvKeys
```

A prompt with nothing changed reuses the kept result:

```text
Parsing legacy file /home/me/projects/legacy-api/.nvmrc
CallFunction: ParseLegacyFile
Found nodejs@18.20.8
Config changed: false, configPaths: map[global:/home/me/.vfox/.vfox.toml]
Using cached output
```

A `.vfox.toml` is tracked by vfox itself, so it switches in both directions
on every vfox: `vfox use --project nodejs@18.20.8` writes one. See
[scenarios.md](scenarios.md#several-projects-in-one-shell).

On vfox before 1.1.0 the file only applies when a shell starts in its
directory: a `cd` into the directory is ignored, and so is an edit of the
file, and leaving the directory keeps the release it had. Upgrade vfox to
1.1.0 or later to switch on every `cd`. vfox learned to track these files in
1.1.0 ([version-fox/vfox#745](https://github.com/version-fox/vfox/issues/745),
fixed by [version-fox/vfox#748](https://github.com/version-fox/vfox/pull/748)),
tracked here as
[#46](https://github.com/version-fox/vfox-nodejs/issues/46).

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

Before it looks at the text, the plugin decodes it, removes all whitespace,
drops a leading `v`, makes the rest lower case and turns `lts-jod` into
`lts/jod`. So `v22.23.3`, a CRLF file and blanks around the version are fine. A
name such as `lts/jod` becomes the major of its line (22), which the plugin
knows from the index, see [lts.md](lts.md), except under `latest_available`,
where the index is asked for the newest release with that codename. A release
number may end in `x`, `X` or `*` for the parts it leaves open: `22.x`, `22.x.x`
and `22.*` all mean 22.

Decoding means that a file in UTF-16, or in UTF-8 with a byte order mark, reads
like plain text. Windows PowerShell 5.1 writes such files with `>`, `Out-File`
and `-Encoding UTF8`, see
[scenarios.md](scenarios.md#writing-the-file-from-windows-powershell-51).

The results on 2026-11-03 with 20.20.2, 22.23.4, 24.21.0, 25.9.0 and 26.13.0
installed, when 24.22.2 is the newest 24.x and 22.23.4 the newest 22.x:

| In the file | `specified` | `latest_installed` | `latest_available` |
| --- | --- | --- | --- |
| `22.23.4`, `v22.23.4` | 22.23.4 | 22.23.4 | 22.23.4 |
| `22`, `v22`, `22.x`, `22.*` | nothing | 22.23.4 | 22.23.4 |
| `22.23` | nothing | 22.23.4 | 22.23.4 |
| `lts/jod`, `lts-jod`, `LTS/Jod` | nothing | 22.23.4 | 22.23.4 |
| `lts/krypton` | nothing | 24.21.0 | nothing: 24.22.2 is the newest and is not installed |
| `lts/lithium` | nothing | 26.13.0 | 26.13.0 |
| `lts/*`, `lts` | nothing | 26.13.0 | 26.13.0 |
| `18.20.8` or any release that is not installed | nothing | nothing | nothing |

`latest_available` does not fall back to an older installed release. When the
index names a newer release than the one you have, nothing is selected. Use
`latest_installed` if you want the newest one you have.

`lts` and `lts/*` mean the newest LTS line. Under `specified` and
`latest_installed` that is the newest line that the plugin knows (26 at the time
of writing), under `latest_available` the newest release that carries any
codename in the index. See [lts.md](lts.md) for how the plugin knows lines and
what happens when Node.js promotes a new one.

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
- A file in UTF-32, or in UTF-16 without a byte order mark. Only the mark tells
  the plugin that a file is UTF-16, and without it the zero bytes stay in the
  text.

## How a prefix is matched

`latest_installed` and `latest_available` compare the text with the start of
each release, part by part and as numbers, and take the newest release that
starts with it:

- `22.2` matches 22.2.x, and not 22.23.3.
- vfox hands over the installed releases sorted as text, descending, so `22.9.0`
  comes before `22.23.3`. The plugin does not go by that order: with 22.9.0,
  22.3.0 and 22.23.3 installed, `22` selects 22.23.3 and `22.3` selects 22.3.0.
  `vfox use nodejs@22` compares numbers as well.

## Not finding it

If the release does not switch:

- The shell hook is not active. `eval "$(vfox activate bash)"` has to run in
  the shell, not only once somewhere else.
- On vfox before 1.1.0: the shell was already running when you `cd`'d into the
  directory, and vfox went on with the release it had worked out for the shell.
  Open a new terminal there, or upgrade vfox to 1.1.0 or later.
- On vfox before 1.1.0: the shell came from a directory with a version file and
  went into one with no config at all, and it keeps the release of the
  directory it left. Open a new terminal there.
- The shell is in a subdirectory of the one with the file.
- The release is not installed. `vfox install nodejs@22.23.3`.
- The strategy is `specified` and the file holds `22` or `lts/jod`.
- Under `latest_available`, a newer release than the installed one is out.
- A `.vfox.toml` or `.tool-versions` is in the way, or `legacyVersionFile.enable`
  is `false`.
- The text is on the list above, or has a comment in it, or the file is in an
  encoding the plugin does not read (before 0.5.4: anything but plain ASCII
  text).

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
[lts.md](lts.md#installing-an-lts-line)). nvm reads the file when you type the
command, vfox at every prompt in the directory, see
[above](#when-the-file-is-read). The commands side by side are in
[scenarios.md](scenarios.md#coming-from-nvm).
