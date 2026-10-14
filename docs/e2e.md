# E2E

The offline Lua hook tests (`tests/hooks_test.lua`) run in the **Test Plugin**
workflow. The end-to-end suite runs in containers against real vfox on Linux
and Windows; each `vfox` x `mirror` combination gets its own throwaway
container.

## What the suite verifies

Every combination runs the same flow (one long-lived container per combo,
driven from Go through `docker exec`-style calls):

1. vfox is installed from the requested channel — the latest release
   (`latest`) or built from source with the in-image Go toolchain (`main`) —
   and the local `nodejs` plugin is registered from this checkout.
2. `$VFOX_NODEJS_MIRROR` is honoured positively and negatively: the
   configured mirror serves the version index, while a bogus mirror makes
   both `nodejs@latest` and a pinned install fail instead of silently
   falling back to `nodejs.org`.
3. A pinned Node.js release installs with checksum verification and runs
   (`node --version`, `npm --version`, `process.platform`, `process.arch`),
   so the `linux-x64` / `linux-arm64` / `win-x64` / `win-arm64` package
   selection is checked for real. The LTS release (`LTS_NODE_VERSION`)
   installs as well, backing the codename probe below.
4. `nodejs@latest` resolves through the plugin's `Available` list (the
   first, newest entry) and installs.
5. The major and major.minor shorthands resolve through `PreUse` against the
   installed versions.
6. `.nvmrc` and `.node-version` drive `vfox env` selection: the exact
   pinned version under the default `specified` strategy, and an LTS
   codename (`lts/<codename>`, see [lts](lts.md)) resolving to the LTS
   release under `latest_installed`. Each legacy probe activates
   inside its own shell so the selection is recomputed rather than answered
   from the `vfox env` state cache of an earlier probe.
7. `vfox search nodejs` lists the installed release with the same npm
   version the binary bundles.

The default matrix is:

| Platform | vfox        | Mirrors                                                       |
| -------- | ----------- | ------------------------------------------------------------- |
| amd64    | latest, main | default (`https://nodejs.org/dist`), CN (`npmmirror.com`)     |
| arm64    | latest, main | default                                                       |

Only `latest` runs the extra mirror by default, to keep CI time bounded;
pin `VFOX_VERSION` and `MIRROR` explicitly to widen or narrow the matrix.

## Environment knobs

| Variable            | Default            | Meaning                                                                 |
| ------------------- | ------------------ | ----------------------------------------------------------------------- |
| `VFOX_VERSION`      | `latest main`      | Space-separated vfox channels (`latest`, `main`)                        |
| `MIRROR`            | see matrix above   | Space-separated mirrors; `default` means `nodejs.org`                   |
| `NODE_VERSION`      | `26.11.1`          | Pinned Node.js release installed by the suite                           |
| `LTS_NODE_VERSION`  | `24.21.0`          | LTS release backing the `lts/<codename>` probe (see docs/lts.md)        |
| `E2E_MAX_JOBS`      | `3` (Linux), `2` (Windows) | Parallel containers per host                                     |
| `E2E_RETRY_ATTEMPTS`| `3`                | Attempts per network-touching exec (linear 10s backoff)                 |
| `E2E_LINUX_BASE`    | `ubuntu`           | Linux userland: `ubuntu` (glibc) or `alpine` (musl, see docs/musl.md)   |

## Ubuntu

Only Docker Engine (in either rootful or rootless mode) is required on the
host. ARM64 runs the default mirror only.

### rootful Docker

Execute in Bash,

```bash
sudo apt install --assume-yes git
git clone git@github.com:version-fox/vfox-nodejs.git
cd ./vfox-nodejs/
docker compose -f tests/e2e/linux/compose.yaml run --rm e2e
```

### rootless Docker

With rootless Docker the daemon socket lives elsewhere; point `DOCKER_SOCK`
at it instead:

```bash
sudo apt install --assume-yes git
git clone git@github.com:version-fox/vfox-nodejs.git
cd ./vfox-nodejs/
DOCKER_SOCK="$XDG_RUNTIME_DIR/docker.sock" docker compose -f tests/e2e/linux/compose.yaml run --rm e2e
```

## Alpine (musl)

Same host requirement. The Alpine suite builds
`tests/e2e/linux/Dockerfile-alpine` (musl userland with `libstdc++`) and
asserts the musl userland before running the standard flow, proving the
plugin selects the `*-musl` tarballs
([issue #29](https://github.com/version-fox/vfox-nodejs/issues/29)).
See [docs/musl.md](musl.md) for the tarball matrix.

```bash
docker compose -f tests/e2e/linux/compose.alpine.yaml run --rm e2e
```

Scope it down locally the same way, e.g.
`VFOX_VERSION=latest MIRROR=default E2E_MAX_JOBS=1` in front of the command.

## Windows 11 Pro

Windows containers cannot be emulated across architectures, so the ARM64
suite needs an ARM64 host (a Copilot+ PC or the `windows-11-arm` CI runner).

The `windows-11-arm` runner has no Windows Hypervisor Platform feature, so
Hyper-V isolation is unavailable; process isolation needs only the
Containers feature.

The `main` combos run with `VFOX_HOME` pointing inside a path containing a
space (`C:\Users\John Doe\.vfox`), mirroring
[issue #33](https://github.com/version-fox/vfox-flutter/issues/33). Only vfox
`main` carries the fix for such paths
([vfox#712](https://github.com/version-fox/vfox/pull/712)), so `latest`
combinations still run with an unspaced home.

### x64

All commands below run in PowerShell 7. If it is not installed yet, install
it first (this single bootstrap command may run in the built-in Windows
PowerShell):

```powershell
winget install --id Microsoft.PowerShell --source winget --exact
```

1. Execute in PowerShell 7,

```powershell
winget install --id Git.Git --source winget --exact
# Configure Git appropriately.

curl.exe -fsSL `
    "https://raw.githubusercontent.com/microsoft/Windows-Containers/Main/helpful_tools/Install-DockerCE/install-docker-ce.ps1" `
    -o ./install-docker-ce.ps1
```

2. Execute in PowerShell 7 with administrator privileges,

```powershell
./install-docker-ce.ps1
```

3. Execute in PowerShell 7,

```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.docker\cli-plugins" | Out-Null

curl.exe -fsSL `
    "https://github.com/docker/compose/releases/download/v5.5.1/docker-compose-windows-x86_64.exe" `
    -o "$env:USERPROFILE\.docker\cli-plugins\docker-compose.exe"

git clone git@github.com:version-fox/vfox-nodejs.git
cd ./vfox-nodejs/
docker compose -f tests/e2e/windows/compose.amd64.yaml run --rm --build e2e
```

### arm64

All commands below run in PowerShell 7. If it is not installed yet, install
it first (this single bootstrap command may run in the built-in Windows
PowerShell):

```powershell
winget install --id Microsoft.PowerShell --source winget --exact
```

1. Execute in PowerShell 7,

```powershell
winget install --id Git.Git --source winget --exact
# Configure Git appropriately.
winget install --id GoLang.Go --source winget --exact
git clone git@github.com:version-fox/vfox-nodejs.git
cd ./vfox-nodejs/
pwsh -NoProfile -File .\tests\e2e\windows\install-docker-arm64.ps1
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.docker\cli-plugins" | Out-Null

curl.exe -fsSL `
    "https://github.com/docker/compose/releases/download/v5.5.1/docker-compose-windows-aarch64.exe" `
    -o "$env:USERPROFILE\.docker\cli-plugins\docker-compose.exe"

docker compose -f tests/e2e/windows/compose.arm64.yaml run --rm --build e2e
```

## Local checks

Execute in Bash on Ubuntu before pushing.

```bash
docker run --rm -v "$PWD:/work" -w /work apache/skywalking-eyes:0.9.0 header check
docker run --rm -v "$PWD:/work" -w /work apache/skywalking-eyes:0.9.0 header fix
docker run --rm -v "$PWD:/src" ghcr.io/google/addlicense:v1.2.0 -check -f .license.tpl tests/e2e/windows/*.ps1
docker run --rm -v "$PWD:/src" ghcr.io/google/addlicense:v1.2.0 -f .license.tpl tests/e2e/windows/*.ps1

cd tests/e2e
go test -short ./...
test -z "$(gofmt -l .)"
go vet ./...
cd ../..

go run github.com/yuin/gopher-lua/cmd/glua@v1.1.1 tests/hooks_test.lua

stylua --check .
mise x aqua:LuaLS/lua-language-server@3.19.1 -- lua-language-server --check . --checklevel=Warning
```
