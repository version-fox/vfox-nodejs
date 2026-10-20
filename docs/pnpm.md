# pnpm

[中文](zh-CN/pnpm.md) | [English](pnpm.md)

pnpm as a package manager, for example from `npm install -g pnpm`, works
next to this plugin. The conflict starts when pnpm also installs Node.js:
`pnpm runtime set node <version> -g` (or the deprecated
`pnpm env use --global <version>`) puts a second `node` into
`$PNPM_HOME/bin`. Only the `node` that comes first in `PATH` runs, and with
the shell setup pnpm writes that is pnpm's, whatever `vfox use` selected.

Observed with pnpm 12.14.0 and vfox 1.0.12 in bash on Ubuntu.

## Symptoms

- `vfox use nodejs@24.21.0` prints `Now using nodejs@24.21.0` and
  `vfox current nodejs` agrees, but `node --version` prints the
  pnpm-managed version. Global, session and project scope are all affected.
- `type -a node` lists `$PNPM_HOME/bin/node` before the vfox path.
- In a directory with `.nvmrc` or `.node-version`, `node` runs a copy pnpm
  downloads on first use, even when vfox has that version installed.
- `npm install -g <pkg>` succeeds but the command is not found. pnpm's
  runtime ships no npm, so vfox's `npm` runs on pnpm's `node` and installs
  into pnpm's copy of Node.js under `$PNPM_HOME`.

## Why

1. `pnpm runtime set node -g` refuses to run until `$PNPM_HOME/bin` is on
   `PATH` (`ERR_PNPM_GLOBAL_BIN_DIR_NOT_IN_PATH`). The fix it suggests,
   `pnpm setup`, adds a block at the end of the shell rc file, below
   `eval "$(vfox activate bash)"`, that prepends `$PNPM_HOME/bin` to `PATH`.
2. At every prompt `vfox env` keeps the `PATH` entries that come before its
   first own path ahead of all SDK paths, so that an activated Python
   virtualenv keeps priority. `$PNPM_HOME/bin` is such an entry.
3. That `node` is pnpm's shim: it runs pnpm's global Node.js, or the version
   the current project pins through `devEngines.runtime`, `engines.runtime`,
   `.node-version` or `.nvmrc`
   ([project-aware global bins](https://pnpm.io/global-packages#project-aware-global-bins)).
   pnpm's `globalShims` setting and `PNPM_SHIM_BYPASS=1` only turn off the
   project lookup; `node` still runs pnpm's global Node.js, not vfox's.

`vfox use nodejs@<version>` prints a note when a `node` sits ahead of vfox
this way, whichever tool put it there:

```text
Note: /home/user/.local/share/pnpm/bin/node comes before vfox in PATH, so `node` will not run nodejs@24.21.0. See https://github.com/version-fox/vfox-nodejs/blob/main/docs/pnpm.md
```

## Keeping vfox in charge of `node`

Remove the Node.js that pnpm installed globally. pnpm keeps working, since
`pnpm setup` copied it into `$PNPM_HOME`:

```sh
pnpm remove -g node
```

Activating vfox below pnpm's block in the rc file is not enough: pnpm's
block prepends `$PNPM_HOME/bin` again unless it already comes first, so
nested shells put pnpm's `node` back in front.

Projects that pin a runtime with `devEngines.runtime` keep it for scripts:
after `pnpm install`, `pnpm run` and `pnpm exec` use the pinned Node.js from
`node_modules/.bin`, while a bare `node` follows vfox.

To let pnpm manage Node.js instead, do not select `nodejs` with vfox in the
same shell.
