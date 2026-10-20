# Installing the plugin from source

[中文](zh-CN/source-build.md) | [English](source-build.md)

Normally you install from the registry:

```sh
vfox add nodejs
```

Install from source when you need something not yet released (the `main`
branch, a pull request checkout): package the checkout into a zip and hand
it to `vfox add --source`. The zip must contain `metadata.lua`, `hooks/`
and `lib/` at its top level; that is the plugin package contract (see the
[shared workflow documentation](https://github.com/version-fox/plugin-manifest-action)).

A released plugin zip URL also works as `--source`, e.g.
`vfox add --source https://github.com/version-fox/vfox-nodejs/releases/download/v0.5.3/vfox-nodejs-0.5.3.zip`.

Prerequisites on all systems: [vfox](https://github.com/version-fox/vfox)
itself plus `git`.

## Windows 11

In PowerShell 7 (`tar` ships with the system, no extra zip tool needed):

```powershell
git clone https://github.com/version-fox/vfox-nodejs.git
cd vfox-nodejs
# For a PR: git fetch origin pull/<number>/head:pr; git checkout pr
tar -a -c -f $env:TEMP\nodejs.zip metadata.lua hooks lib
vfox add nodejs --source "$env:TEMP\nodejs.zip"
vfox install nodejs@26.11.1
```

## Ubuntu 26.04

```bash
sudo apt install --assume-yes git zip
git clone https://github.com/version-fox/vfox-nodejs.git
cd vfox-nodejs
# For a PR: git fetch origin pull/<number>/head:pr && git checkout pr
zip -qr /tmp/nodejs.zip metadata.lua hooks lib
vfox add nodejs --source /tmp/nodejs.zip
vfox install nodejs@26.11.1
```

## macOS

The same commands as on Ubuntu, without the `apt` line: `zip` ships with the
system, and `git` comes with the Xcode command line tools.

## Alpine 3.24.2

```sh
apk add git zip
git clone https://github.com/version-fox/vfox-nodejs.git
cd vfox-nodejs
# For a PR: git fetch origin pull/<number>/head:pr && git checkout pr
zip -qr /tmp/nodejs.zip metadata.lua hooks lib
vfox add nodejs --source /tmp/nodejs.zip
vfox install nodejs@26.11.1
```

On Alpine the installed Node.js needs system libraries first, see
[musl.md](musl.md#requirements).

## Check it

```bash
vfox info nodejs
vfox install nodejs@24
vfox use --global nodejs@24
node -v
```

`vfox info nodejs` prints the version of the plugin that is added, the
`PLUGIN.version` in `metadata.lua`. A source build of `main` carries the version
of the last release, so it cannot tell you which commit you have.

## When nodejs is already added

`vfox add` refuses with `plugin named nodejs already exists`. You can replace the
plugin or add the source build next to it.

To replace it, `vfox remove nodejs` comes first, and it removes the Node.js
releases installed through the plugin as well: vfox says `Removing this plugin
will remove the installed sdk along with the plugin.` before it asks (`-y`
skips the question). Install them again afterwards.

To keep both, give the new one another name:

```bash
vfox add nodejs --source /tmp/nodejs.zip --alias nodejs-dev
vfox install nodejs-dev@24
vfox remove -y nodejs-dev          # removes only nodejs-dev and what it installed
```

The alias has its own list of installed releases, under `~/.vfox/cache/nodejs-dev/`,
but both plugins link the chosen release as `~/.vfox/sdks/nodejs`. Select a
version from only one of them per scope: for the global scope, `vfox unuse
--global nodejs` before you `vfox use --global nodejs-dev@...`, or the other way
round. With both selected, the link points at one of them and `node` follows it,
and you should not count on which.

## Updating

Pull, package the zip again and add it again. A plugin added under its own name
has to be removed first, and that takes the installed releases with it, so the
alias is the easier route when you update often:

```bash
vfox remove -y nodejs-dev
vfox add nodejs --source /tmp/nodejs.zip --alias nodejs-dev
```

`vfox update nodejs` compares the version in `metadata.lua` with the registry's
and prints `nodejs is already the latest version` while they are equal, so it
leaves a source build alone until a release newer than that version is
published.

To work on the plugin, see [development.md](development.md).
