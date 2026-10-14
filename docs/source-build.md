# Installing the plugin from source

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
`vfox add --source https://github.com/version-fox/vfox-nodejs/releases/download/v0.0.5/vfox-nodejs_0.0.5.zip`.

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

## Updating

Re-run the zip + `vfox add` steps after pulling (re-adding replaces the
installed plugin), or `vfox remove nodejs` first for a clean slate.
