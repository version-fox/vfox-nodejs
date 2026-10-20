# E2E

[中文](zh-CN/e2e.md) | [English](e2e.md)

The offline Lua hook tests (`tests/hooks_test.lua`) run in the **Test Plugin**
workflow. The end-to-end suite runs in containers against real vfox on Linux
and Windows; each `vfox` x `mirror` combination gets its own throwaway
container. On Linux, CI runs the suite natively on the stock runners (Docker
plus Go from `actions/setup-go`), the way the repository dev container
reproduces it locally. On Windows it runs from the host through
`tests/e2e/windows/run.ps1`, since dev containers cannot host Windows
container images (see below).

## Dev container

`.devcontainer/` opens a Linux development environment that works on all four
host platforms:

| Host                  | How the dev container runs                     |
| --------------------- | ---------------------------------------------- |
| Linux amd64 / arm64   | natively                                       |
| Windows amd64 / arm64 | Docker Desktop in Linux-container mode (WSL 2) |

It carries Go 1.27.1 (the version CI installs), the Docker CLI, stylua,
lua-language-server, and the license tools — all pinned to the versions in
`.github/workflows/lint.yml` and `license.yml` — and mounts the host Docker
daemon socket. The suites then run testcontainers against that daemon
(Docker-out-of-Docker), spawning the same target containers a native CI
runner spawns; this is deliberately not Docker-in-Docker, so image cache and
networking stay the host's. The image needs no workspace files, so the build
context stays at `.devcontainer/`; `postCreateCommand` warms the Go module
cache for `tests/e2e` so the first test run does not stop to download.

Open it with any Dev Containers spec tool — **Dev Containers: Reopen in
Container** in VS Code/Cursor, or the CLI:

```bash
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . bash
```

`TESTCONTAINERS_RYUK_DISABLED=true` is preset: Ryuk publishes a port on the
host daemon and waits for the suite to dial it back, which a
Docker-out-of-Docker container cannot do. The suites terminate every
container explicitly via `t.Cleanup` instead; leftovers from killed runs
share the `vfox-nodejs-e2e-` name prefix for pruning. Rootless Docker users
export `DOCKER_SOCK="$XDG_RUNTIME_DIR/docker.sock"` on the host before
opening the container. On Windows hosts, keeping the checkout inside WSL 2
(e.g. under `\\wsl$`) keeps file and bind-mount access fast; a checkout on
the Windows filesystem works too.

Windows *container* coverage (`tests/e2e/windows`) cannot run in a dev
container: the Dev Containers spec does not support Windows container images
([vscode-remote-release#445](https://github.com/microsoft/vscode-remote-release/issues/445)),
and Windows containers only run on a Windows daemon. That suite runs from a
Windows host through `tests/e2e/windows/run.ps1`; see [Windows 11](#windows-11)
below.

## What the suite verifies

Every combination runs the same flow (one long-lived container per combo,
driven from Go through `docker exec`-style calls):

1. vfox is installed from the requested channel — the latest release
   (`latest`) or built from source with the pinned Go (`main`; inside the
   container on Linux, once per run on the host by `run.ps1` on Windows) —
   and the local `nodejs` plugin is registered from this checkout.
2. `$VFOX_NODEJS_MIRROR` is honoured positively and negatively: the
   configured mirror serves the version index, while a bogus mirror makes
   both `nodejs@latest` and a pinned install fail instead of silently
   falling back to `nodejs.org`.
3. A pinned Node.js release installs with checksum verification and runs
   (`node --version`, `npm --version`, `process.platform`, `process.arch`),
   so the `linux-x64` / `linux-arm64` / `win-x64` / `win-arm64` package
   selection is checked for real. On Windows, Git Bash also runs `node`,
   `npm.cmd`, and extensionless `npm` after activation to cover
   [issue #293](https://github.com/version-fox/vfox/issues/293). The LTS
   release (`LTS_NODE_VERSION`) installs as well, backing the codename probe
   below.
4. `nodejs@latest` resolves through the plugin's `Available` list (the
   first, newest entry) and installs when that platform's binary is published.
   Alpine ARM64 skips this probe only while the matching upstream unofficial
   musl build is absent; it still verifies the pinned and LTS releases.
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

## Linux (Ubuntu)

Inside the dev container, from the repository root:

```bash
cd tests/e2e
go test -v -timeout 55m -run TestE2E ./linux
```

Scope it down while iterating the same way:

```bash
VFOX_VERSION=latest MIRROR=default E2E_MAX_JOBS=1 go test -v -timeout 55m -run TestE2E ./linux
```

On a native host the same command works with two prerequisites — Docker
Engine (rootful or rootless) and Go 1.27.1 — which is exactly what CI
provisions. Rootless Docker users point the Docker client at their socket
(`export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/docker.sock"`); the dev
container's socket mount covers that case for you. ARM64 runs the default
mirror only.

## Alpine (musl)

The Alpine suite builds `tests/e2e/linux/Dockerfile-alpine` (musl userland
with `libstdc++`) and asserts the musl userland before running the standard
flow, proving the plugin selects the `*-musl` tarballs
([issue #29](https://github.com/version-fox/vfox-nodejs/issues/29)).
See [docs/musl.md](musl.md) for the tarball matrix.

The image installs `libstdc++` on purpose. It gets `libatomic` only through
`go`, which depends on `gcc`, so the suite does not cover a stock Alpine, where
the musl packages of 26.8.0 and later need `libatomic` and the install stops
without it. The hook tests cover that check (`post_install names the library the
loader cannot find`), see [docs/musl.md](musl.md#requirements).

Set `E2E_LINUX_BASE` to switch the same Linux suite onto the Alpine image:

```bash
cd tests/e2e
E2E_LINUX_BASE=alpine go test -v -timeout 55m -run TestE2E ./linux
```

CI exports the same variable in its musl job; the dev container needs
nothing else.

## Windows 11

Windows containers cannot be emulated across architectures, so the ARM64
suite needs an ARM64 host (a Copilot+ PC or the `windows-11-arm` CI runner).

There is no dev container for this suite — the Dev Containers spec rejects
Windows container images (see [Dev container](#dev-container)) — so it runs
from the Windows host through `tests/e2e/windows/run.ps1`. The host
requirement is Docker in Windows-container mode; the script needs nothing
beyond the `curl.exe` and `tar.exe` that ship with Windows. It fetches the
pinned PowerShell, PortableGit (Git for Windows, including Git Bash) and Go
into a per-arch cache (`$env:E2E_CACHE_DIR`, default
`%LOCALAPPDATA%\vfox-nodejs-e2e\<arch>`, reused across runs), builds
`vfox@main` once with that Go, compiles the suite, and runs it. None of it is
installed or put on the user `PATH`, so it cannot conflict with a
vfox-managed toolchain.

The cached tools are bind-mounted read-only at `C:\tools` into every combo
container, so `tests/e2e/windows/Dockerfile` only adds `PATH` entries and the
plugin files to stock servercore. Baking the tools into an image layer
instead costs minutes of layer commit on the hosted runners (they are tens of
thousands of files). The servercore pull — five to seven minutes on a fresh
CI runner — runs in the background while the tools are fetched and the Go
code is compiled.

The `windows-11-arm` runner has no Windows Hypervisor Platform feature, so
Hyper-V isolation is unavailable; process isolation needs only the
Containers feature.

Every combination runs with `VFOX_HOME` pointing inside a path containing a
space (`C:\Users\John Doe\.vfox`), mirroring
[issue #33](https://github.com/version-fox/vfox-flutter/issues/33). vfox
handles such paths since 1.0.13
([vfox#712](https://github.com/version-fox/vfox/pull/712)), so the `latest`
release and `main` both run against it.

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
git clone git@github.com:version-fox/vfox-nodejs.git
cd ./vfox-nodejs/
pwsh -NoProfile -File tests/e2e/windows/run.ps1
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
pwsh -NoProfile -File .\tests\e2e\windows\run.ps1
```

On arm64, a host Go is needed only to build the engine
(`install-docker-arm64.ps1`); `run.ps1` uses its own cached Go for the suite.
The script reuses an earlier build left in `C:\vfox-docker\bin`; CI restores
that directory with `actions/cache`, keyed on the script, so a cache hit
skips both `actions/setup-go` and the build.

`$env:E2E_RUN` narrows the `-test.run` pattern (default `TestE2E`), e.g.
`TestE2E/latest-default`. Scope the run down with
`$env:VFOX_VERSION = 'latest'; $env:MIRROR = 'default'` in front of it, as on
the other platforms; without `main` in `VFOX_VERSION` the script skips the
`vfox@main` build. CI sets `E2E_MAX_JOBS=3` on both Windows jobs so every
combo runs at once; the local default stays at 2.

## WSL

The WSL suite (`tests/e2e/wsl/`) drives the Ubuntu distribution on the
Windows host directly through `wsl.exe` — no containers. It exists to
reproduce [issue #32](https://github.com/version-fox/vfox-nodejs/issues/32):
inside WSL, `vfox install` reported success but `node` was missing from
`PATH`. On top of the shared flow (install with checksum, toolchain,
shorthands, search, legacy files) it asserts that `command -v node` resolves
under `VFOX_HOME` and that `vfox env -s bash` exports the SDK bin directory.

The pinned release defaults to `20.16.0` (the issue's version); `NODE_VERSION`
overrides it. The LTS release (`LTS_NODE_VERSION`, default per
`tests/e2e/common`) backs the `lts/<codename>` probe like the other suites.
Combos share one distro and run sequentially, each isolated in
its own `HOME`/`VFOX_HOME` slot. `MIRROR` defaults apply as usual; CI pins
`MIRROR=default` to keep the run to the `latest`/`main` vfox channels.

It runs from the Windows host (it needs `wsl.exe` and the installed distro),
not from the dev container.

### CI

The `WSL (windows-2025)` job installs `Ubuntu-24.04` with
`wsl --install --no-launch --web-download` (the image ships WSL without a
distro; `--web-download` skips the unreachable Store), boots it once as root
to skip user creation, then runs `go test -run TestE2E ./wsl` from
`tests/e2e`. The log records `wsl --version`, `wsl -l -v` (WSL 1 vs 2) and
`uname -a` for interpretation.

### Local run

On Windows 11 with WSL and Go installed, in PowerShell:

```powershell
wsl --install -d Ubuntu-24.04
$env:WSL_DISTRO = 'Ubuntu-24.04'
$env:VFOX_VERSION = 'latest'; $env:MIRROR = 'default'; $env:NODE_VERSION = '20.16.0'
cd ./vfox-nodejs/tests/e2e/
go test -v -timeout 55m -run TestE2E ./wsl
```

## Local checks

Execute from the dev container — everything below is preinstalled and pinned
to the versions the workflows use — or provision the same tools on a host.

```bash
# Lua and Go checks (.github/workflows/lint.yml).
cd tests/e2e
go test -short ./...
test -z "$(gofmt -l .)"
go vet ./...
cd ../..

go run github.com/yuin/gopher-lua/cmd/glua@v1.1.1 tests/hooks_test.lua

stylua --check .
lua-language-server --check . --checklevel=Warning
```

```bash
# License headers (.github/workflows/license.yml).
license-eye header check
license-eye header fix
addlicense -check -f .license.tpl tests/e2e/windows/*.ps1
addlicense -f .license.tpl tests/e2e/windows/*.ps1
```

On a Docker-only host the license checks run as containers instead (the same
images CI uses):

```bash
docker run --rm -v "$PWD:/work" -w /work apache/skywalking-eyes:0.9.0 header check
docker run --rm -v "$PWD:/work" -w /work apache/skywalking-eyes:0.9.0 header fix
docker run --rm -v "$PWD:/src" ghcr.io/google/addlicense:v1.2.0 -check -f .license.tpl tests/e2e/windows/*.ps1
docker run --rm -v "$PWD:/src" ghcr.io/google/addlicense:v1.2.0 -f .license.tpl tests/e2e/windows/*.ps1
```
