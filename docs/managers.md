# Other Node.js managers

[中文](zh-CN/managers.md) | [English](managers.md)

pnpm has its own page ([pnpm.md](pnpm.md)): `pnpm runtime set node -g`
puts a second `node` into `$PNPM_HOME/bin`. This page is for the same
problem from the other managers people commonly have next to vfox:
mise, asdf, nvm, Homebrew and winget (or the official installer, which
puts `node` in the same place as winget).

The symptom is always the same: `vfox use nodejs@<version>` prints
`Now using`, `vfox current nodejs` agrees, but `node --version` prints
the other manager's version, because its `node` comes before vfox's in
`PATH` (`type -a node` lists it first). On vfox 1.1.0 and later vfox
warns itself and appends the plugin's hint for the manager it
recognizes; on older vfox the plugin prints its own `Note:`. Unreleased:
release 0.5.4 prints the `Note:`; on vfox 1.1.0 and later the warning
comes from vfox itself with the plugin's hint.

Pick at most one manager for `node` in a shell. There are two roads.
Road A, the default below, hands `PATH` to vfox without removing the
other manager itself: its `node` stops shadowing, and vfox installs and
selects its own releases. Road B keeps the files where they are and
registers one of them with vfox:

```sh
vfox link nodejs@<name> <dir>
vfox use nodejs@<name>
```

`<dir>` is the SDK directory the plugin expects: the directory holding
`bin/` with `bin/node` in it on Linux and macOS, the directory holding
`node.exe` itself on Windows. `vfox link` checks that and refuses
anything else. Link the real install, never a shims directory
(`mise/shims`, `.asdf/shims`, `$PNPM_HOME/bin`): a shim is a
version-switching proxy, and pnpm's shim additionally ships no npm, so
a linked shim selects nothing stable. A linked version stays its
owner's: the other manager may upgrade or prune it underneath vfox
(`brew upgrade` replaces the Cellar directory, mise/asdf prune
installs), vfox only reports that, `vfox install --reinstall` does not
apply to it, and `vfox uninstall` removes the link only. The `<name>`
is used as written (`24-system`, `brew-24`, `nvm-22`); use letters,
digits, `.`, `_`, `+` and `-`, never `latest`. The nodejs plugin has no
`Detect` hook, so `vfox link --detect nodejs` finds nothing; pass the
directory yourself.

## mise

mise keeps shims in `~/.local/share/mise/shims/` (`%LOCALAPPDATA%\mise\shims\`
on Windows, e.g. `...\mise\shims\node.exe`) and the real installs in
`~/.local/share/mise/installs/node/<version>/`. `mise activate` puts the
shims first in `PATH`, so its `node` wins.

To let vfox own `node` (road A), drop the request and delete the
installs:

```sh
mise unuse -g node
mise uninstall --all node
```

In a project directory, `mise unuse node` edits that project's config
instead of the global one. Official reference:
[uninstall](https://mise.jdx.dev/cli/uninstall.html) and
[unuse](https://mise.jdx.dev/cli/unuse.html).

Or link one real install (road B); never the shims directory:

```sh
mise ls node
vfox link nodejs@mise-22 ~/.local/share/mise/installs/node/22.0.0
vfox use nodejs@mise-22
```

## asdf

asdf keeps shims in `~/.asdf/shims/` (`$ASDF_DATA_DIR/shims` when that
is set), e.g. `~/.asdf/shims/node`, and the real installs in
`~/.asdf/installs/nodejs/<version>/`. The shims directory is prepended
to `PATH`, so its `node` wins.

To let vfox own `node` (road A), uninstall the versions and drop the
pin:

```sh
asdf uninstall nodejs <version>
```

Then delete the `nodejs ...` line from `./.tool-versions` and
`~/.tool-versions` (or `asdf unset nodejs` on asdf 0.16+), and run
`asdf reshim nodejs` if a stale shim stays. Official reference:
[versions](https://asdf-vm.com/manage/versions.html) (uninstall and
shims on one page).

Or link one real install (road B); never the shims directory:

```sh
asdf list nodejs
asdf where nodejs 22.13.0
vfox link nodejs@asdf-22 ~/.asdf/installs/nodejs/22.13.0
vfox use nodejs@asdf-22
```

## nvm

nvm (nvm-sh) keeps versions in `~/.nvm/versions/node/v<version>/`, e.g.
`~/.nvm/versions/node/v22.14.0/bin/node`, and `nvm use` prepends that
`bin/` to `PATH`, so its `node` wins. Check with `nvm which current`.

To hand the current shell to vfox without deleting anything (road A),
run:

```sh
nvm deactivate
```

The installs stay for a later `nvm use`. `nvm unload` is stronger: it
also unloads the `nvm` function itself, so prefer `deactivate` for a
handoff. Official reference:
[restoring PATH](https://github.com/nvm-sh/nvm#restoring-path).

Or link one installed version (road B):

```sh
nvm which 22
vfox link nodejs@nvm-22 ~/.nvm/versions/node/v22.14.0
vfox use nodejs@nvm-22
```

## Homebrew

Homebrew links `node` into its prefix: `/opt/homebrew/bin/node` on Apple
silicon, `/usr/local/bin/node` on Intel Macs,
`/home/linuxbrew/.linuxbrew/bin/node` on Linux. Whichever `node` is first
in `PATH` wins (`which -a node`).

To let vfox own `node` while keeping the keg around (road A), run:

```sh
brew unlink node
```

`brew link node` brings it back. To remove it fully, `brew uninstall
node`. The Intel prefix `/usr/local/bin/node` does not contain
`homebrew`, so there vfox warns without the Homebrew hint; the fix is
the same. Official reference:
[manpage](https://docs.brew.sh/Manpage) (`unlink`, `uninstall`).

Or link the Cellar directory (road B); a later `brew upgrade` replaces
it, so the link can dangle and need relinking:

```sh
ls $(brew --cellar node)
vfox link nodejs@brew-24 /opt/homebrew/Cellar/node/24.5.0
vfox use nodejs@brew-24
```

## winget and the official installer

winget runs the official MSI, which installs machine-wide to
`C:\Program Files\nodejs\`, e.g. `C:\Program Files\nodejs\node.exe`,
and appends that directory to the system `PATH`. The LTS line uses the
`OpenJS.NodeJS.LTS` package id instead of `OpenJS.NodeJS`.

To let vfox own `node` (road A), uninstall it (Add/Remove Programs runs
the same uninstaller):

```powershell
winget list --name Node.js
winget uninstall -e --id OpenJS.NodeJS
```

If the LTS line is installed, replace the id with
`OpenJS.NodeJS.LTS`. Open a new terminal afterwards so the stale `PATH`
entry is gone. Official download page:
[nodejs.org](https://nodejs.org/en/download).

Or link the directory (road B); an MSI upgrade replaces the files
underneath, which vfox only reports:

```powershell
vfox link nodejs@system "C:\Program Files\nodejs"
vfox use nodejs@system
```
