# E2E

[中文](e2e.md) | [English](../e2e.md)

离线的 Lua 钩子测试（`tests/hooks_test.lua`）在 **Test Plugin** 工作流里运行。端到端套件在容器里针对真实的 vfox 运行，覆盖 Linux 和 Windows；每个 `vfox` x `mirror` 组合都有自己的一次性容器。在 Linux 上，CI 直接在标准 runner 上运行这套测试（Docker 加 `actions/setup-go` 提供的 Go），仓库的开发容器在本地复现的就是这一环境。在 Windows 上，测试通过 `tests/e2e/windows/run.ps1` 从宿主运行，因为开发容器无法承载 Windows 容器镜像（见下文）。

## 开发容器

`.devcontainer/` 提供一个 Linux 开发环境，在四种宿主平台上都能用：

| 宿主 | 开发容器的运行方式 |
| --- | --- |
| Linux amd64 / arm64 | 原生运行 |
| Windows amd64 / arm64 | Docker Desktop 的 Linux 容器模式（WSL 2） |

它带有 Go 1.27.1（CI 安装的版本）、Docker CLI、stylua、lua-language-server 和许可证工具，版本都与 `.github/workflows/lint.yml` 和 `license.yml` 里固定的一致，并挂载宿主的 Docker daemon socket。套件随后通过 testcontainers 连接这个 daemon（Docker-out-of-Docker），启动的目标容器和原生 CI runner 启动的完全相同；这里刻意不用 Docker-in-Docker，这样镜像缓存和网络都还是宿主的。镜像不需要工作区里的文件，所以构建上下文保持在 `.devcontainer/`；`postCreateCommand` 会预热 `tests/e2e` 的 Go 模块缓存，第一次运行测试时就不必停下来下载。

用任何支持 Dev Containers 规范的工具都可以打开它：在 VS Code/Cursor 里执行 **Dev Containers: Reopen in Container**，或者用 CLI：

```bash
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . bash
```

`TESTCONTAINERS_RYUK_DISABLED=true` 是预先设好的：Ryuk 会在宿主 daemon 上发布一个端口，并等待套件回连，而 Docker-out-of-Docker 的容器做不到这一点。套件改为通过 `t.Cleanup` 显式终止每个容器；被强行中断的运行遗留的容器，名称都带有 `vfox-nodejs-e2e-` 前缀，可以按这个前缀清理。使用 rootless Docker 的用户，请在打开容器之前先在宿主上导出 `DOCKER_SOCK="$XDG_RUNTIME_DIR/docker.sock"`。在 Windows 宿主上，把仓库检出到 WSL 2 里（例如 `\\wsl$` 下）能让文件和 bind mount 的访问保持快速；检出到 Windows 文件系统上也能用。

Windows 容器的覆盖（`tests/e2e/windows`）无法在开发容器里运行：Dev Containers 规范不支持 Windows 容器镜像（[vscode-remote-release#445](https://github.com/microsoft/vscode-remote-release/issues/445)），而且 Windows 容器只能跑在 Windows daemon 上。这套测试要在 Windows 宿主上通过 `tests/e2e/windows/run.ps1` 运行，见下面的 [Windows 11](#windows-11)。

## 套件验证什么

每个组合都运行同样的流程（每个组合一个长期存活的容器，由 Go 通过类似 `docker exec` 的调用来驱动）：

1. 从指定的渠道安装 vfox，要么是最新发布版（`latest`），要么用固定版本的 Go 从源码构建（`main`；在 Linux 上于容器内构建，在 Windows 上由 `run.ps1` 在宿主上每次运行构建一次），然后从当前检出的代码注册本地的 `nodejs` 插件。
2. `$VFOX_NODEJS_MIRROR` 有正反两方面的检查：配置的镜像要能提供版本索引；而配成无效的镜像时，`nodejs@latest` 和固定版本的安装都应失败，而不是悄悄回退到 `nodejs.org`。
3. 固定的 Node.js 版本安装时会验证校验和，并且能正常运行（`node --version`、`npm --version`、`process.platform`、`process.arch`），因此 `linux-x64` / `linux-arm64` / `win-x64` / `win-arm64` 的包选择是实际检验过的。在 Windows 上，vfox 挂载之后，Git Bash 还会运行 `node`、`npm.cmd` 和不带扩展名的 `npm`，以覆盖 [issue #293](https://github.com/version-fox/vfox/issues/293)。LTS 版本（`LTS_NODE_VERSION`）也会安装，供下面的代号检查使用。
4. `nodejs@latest` 通过插件的 `Available` 列表解析（取第一项，也就是最新的一项），并在该平台的二进制已经发布时完成安装。Alpine ARM64 只在上游对应的非官方 musl 构建缺失期间才跳过这项检查；固定版本和 LTS 版本仍会验证。
5. 只写大版本，或只写大版本和小版本的简写，通过 `PreUse` 对照已安装的版本解析。
6. `.nvmrc` 和 `.node-version` 决定 `vfox env` 选中哪个版本：在默认的 `specified` 策略下，选中文件里固定的那个确切版本；在 `latest_installed` 策略下，LTS 代号（`lts/<codename>`，见 [lts](lts.md)）会解析为对应的 LTS 版本。每项兼容版本文件的检查都在自己的 Shell 里挂载 vfox，这样选择结果是重新计算出来的，而不是由前一次检查留下的 `vfox env` 状态缓存直接给出。
7. `vfox search nodejs` 列出已安装的版本，给出的 npm 版本与该二进制自带的 npm 版本相同。

默认矩阵是：

| 平台 | vfox | 镜像 |
| --- | --- | --- |
| amd64 | latest、main | default（`https://nodejs.org/dist`）、CN（`npmmirror.com`） |
| arm64 | latest、main | default |

默认只有 `latest` 会运行额外的镜像，以控制 CI 的耗时；要扩大或缩小矩阵，请显式指定 `VFOX_VERSION` 和 `MIRROR`。

## 环境变量

| 变量 | 默认值 | 含义 |
| --- | --- | --- |
| `VFOX_VERSION` | `latest main` | 用空格分隔的 vfox 渠道（`latest`、`main`） |
| `MIRROR` | 见上面的矩阵 | 用空格分隔的镜像；`default` 表示 `nodejs.org` |
| `NODE_VERSION` | `26.11.1` | 套件安装的固定 Node.js 版本 |
| `LTS_NODE_VERSION` | `24.21.0` | 用于 `lts/<codename>` 检查的 LTS 版本（见 docs/zh-CN/lts.md） |
| `E2E_MAX_JOBS` | `3`（Linux），`2`（Windows） | 每台宿主并行的容器数 |
| `E2E_RETRY_ATTEMPTS` | `3` | 每个涉及网络的 exec 的尝试次数（线性退避 10 秒） |
| `E2E_LINUX_BASE` | `ubuntu` | Linux 用户空间：`ubuntu`（glibc）或 `alpine`（musl，见 docs/zh-CN/musl.md） |

## Linux（Ubuntu）

在开发容器里，从仓库根目录执行：

```bash
cd tests/e2e
go test -v -timeout 55m -run TestE2E ./linux
```

迭代时可以用同样的方式缩小范围：

```bash
VFOX_VERSION=latest MIRROR=default E2E_MAX_JOBS=1 go test -v -timeout 55m -run TestE2E ./linux
```

在原生宿主上，同一条命令也能用，只需要两个前提：Docker Engine（rootful 或 rootless）和 Go 1.27.1，这正是 CI 准备的环境。使用 rootless Docker 的用户要把 Docker 客户端指向自己的 socket（`export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/docker.sock"`）；开发容器挂载的 socket 已经替你处理了这种情况。ARM64 只运行默认镜像。

## Alpine（musl）

Alpine 套件会构建 `tests/e2e/linux/Dockerfile-alpine`（带 `libstdc++` 的 musl 用户空间），先断言用户空间确实是 musl，再运行标准流程，以此证明插件选中的是 `*-musl` 压缩包（[issue #29](https://github.com/version-fox/vfox-nodejs/issues/29)）。压缩包的对应关系见 [docs/zh-CN/musl.md](musl.md)。

镜像有意安装 `libstdc++`。`libatomic` 只是经由 `go`（它依赖 `gcc`）装进来的，所以套件没有覆盖原版 Alpine：在原版 Alpine 上，26.8.0 及以后版本的 musl 包需要 `libatomic`，缺了它安装就会中止。钩子测试覆盖了这项检查（`post_install names the library the loader cannot find`），见 [docs/zh-CN/musl.md](musl.md#依赖的系统库)。

设置 `E2E_LINUX_BASE`，即可让同一套 Linux 套件切换到 Alpine 镜像运行：

```bash
cd tests/e2e
E2E_LINUX_BASE=alpine go test -v -timeout 55m -run TestE2E ./linux
```

CI 在它的 musl 作业里导出同一个变量；开发容器不需要任何其他设置。

## Windows 11

Windows 容器无法跨架构模拟，所以 ARM64 套件需要 ARM64 宿主（Copilot+ PC 或 `windows-11-arm` CI runner）。

这套测试没有开发容器，因为 Dev Containers 规范拒绝 Windows 容器镜像（见[开发容器](#开发容器)），所以它通过 `tests/e2e/windows/run.ps1` 从 Windows 宿主运行。对宿主的要求是 Windows 容器模式的 Docker；除了 Windows 自带的 `curl.exe` 和 `tar.exe`，脚本不需要别的东西。它会把固定版本的 PowerShell、PortableGit（含 Git Bash 的 Git for Windows）和 Go 下载到按架构区分的缓存里（`$env:E2E_CACHE_DIR`，默认是 `%LOCALAPPDATA%\vfox-nodejs-e2e\<arch>`，多次运行之间复用），用这个 Go 构建一次 `vfox@main`，编译套件，然后运行。这些工具都不会被安装，也不会放进用户的 `PATH`，所以不会与 vfox 管理的工具链冲突。

缓存的工具以只读方式 bind mount 到每个组合容器的 `C:\tools`，所以 `tests/e2e/windows/Dockerfile` 只需要在原版 servercore 上加 `PATH` 条目和插件文件。如果改为把工具构建进镜像层，托管的 runner 上仅提交镜像层就要花几分钟（这些工具共有几万个文件）。拉取 servercore 在全新的 CI runner 上要五到七分钟，它在后台进行，同时获取工具、编译 Go 代码。

`windows-11-arm` runner 没有 Windows Hypervisor Platform 功能，所以无法使用 Hyper-V 隔离；进程隔离只需要 Containers 功能。

每个组合运行时，`VFOX_HOME` 都指向一个带空格的路径（`C:\Users\John Doe\.vfox`），以复现 [issue #33](https://github.com/version-fox/vfox-flutter/issues/33)。vfox 从 1.0.13 起支持这样的路径（[vfox#712](https://github.com/version-fox/vfox/pull/712)），所以 `latest` 发布版和 `main` 都在这个路径下运行。

### x64

下面所有命令都在 PowerShell 7 中运行。如果还没有安装，请先装上（这一条引导命令可以在自带的 Windows PowerShell 里运行）：

```powershell
winget install --id Microsoft.PowerShell --source winget --exact
```

1. 在 PowerShell 7 中执行：

```powershell
winget install --id Git.Git --source winget --exact
# 按需配置 Git。

curl.exe -fsSL `
    "https://raw.githubusercontent.com/microsoft/Windows-Containers/Main/helpful_tools/Install-DockerCE/install-docker-ce.ps1" `
    -o ./install-docker-ce.ps1
```

2. 以管理员身份在 PowerShell 7 中执行：

```powershell
./install-docker-ce.ps1
```

3. 在 PowerShell 7 中执行：

```powershell
git clone git@github.com:version-fox/vfox-nodejs.git
cd ./vfox-nodejs/
pwsh -NoProfile -File tests/e2e/windows/run.ps1
```

### arm64

下面所有命令都在 PowerShell 7 中运行。如果还没有安装，请先装上（这一条引导命令可以在自带的 Windows PowerShell 里运行）：

```powershell
winget install --id Microsoft.PowerShell --source winget --exact
```

1. 在 PowerShell 7 中执行：

```powershell
winget install --id Git.Git --source winget --exact
# 按需配置 Git。
winget install --id GoLang.Go --source winget --exact
git clone git@github.com:version-fox/vfox-nodejs.git
cd ./vfox-nodejs/
pwsh -NoProfile -File .\tests\e2e\windows\install-docker-arm64.ps1
pwsh -NoProfile -File .\tests\e2e\windows\run.ps1
```

在 arm64 上，只有构建 Docker 引擎（`install-docker-arm64.ps1`）时才需要宿主上的 Go；`run.ps1` 跑套件时用的是它自己缓存的 Go。脚本会复用之前留在 `C:\vfox-docker\bin` 里的构建产物；CI 用 `actions/cache` 恢复这个目录，缓存以这个脚本为键，所以命中缓存时会同时跳过 `actions/setup-go` 和构建。

`$env:E2E_RUN` 用来收窄 `-test.run` 的匹配模式（默认是 `TestE2E`），例如 `TestE2E/latest-default`。想缩小运行范围，在运行命令之前加上 `$env:VFOX_VERSION = 'latest'; $env:MIRROR = 'default'`，和其他平台一样；`VFOX_VERSION` 里没有 `main` 时，脚本会跳过构建 `vfox@main`。CI 在两个 Windows 作业上都设置了 `E2E_MAX_JOBS=3`，让每个组合同时运行；本地默认值仍是 2。

## WSL

WSL 套件（`tests/e2e/wsl/`）在 Windows 宿主上通过 `wsl.exe` 直接驱动 Ubuntu 发行版，不使用容器。它是为了复现 [issue #32](https://github.com/version-fox/vfox-nodejs/issues/32) 而存在的：在 WSL 里，`vfox install` 报告成功，`node` 却不在 `PATH` 上。在共用的流程（带校验和验证的安装、工具链、简写、搜索、兼容版本文件）之外，它还断言 `command -v node` 解析到 `VFOX_HOME` 之下，并且 `vfox env -s bash` 导出了 SDK 的 bin 目录。

固定的版本默认是 `20.16.0`（issue 里的版本）；`NODE_VERSION` 可以覆盖它。LTS 版本（`LTS_NODE_VERSION`，默认值以 `tests/e2e/common` 为准）和其他套件一样，用于 `lts/<codename>` 检查。各组合共用一个发行版并依次运行，每个组合使用各自独立的 `HOME`/`VFOX_HOME`，彼此隔离。`MIRROR` 的默认值照常适用；CI 固定 `MIRROR=default`，使运行只覆盖 `latest`/`main` 这两个 vfox 渠道。

它在 Windows 宿主上运行（需要 `wsl.exe` 和已安装的发行版），而不是在开发容器里。

### CI

`WSL (windows-2025)` 作业用 `wsl --install --no-launch --web-download` 安装 `Ubuntu-24.04`（镜像自带 WSL，但没有发行版；`--web-download` 绕过无法访问的 Store），以 root 身份启动一次来跳过创建用户，然后在 `tests/e2e` 下运行 `go test -run TestE2E ./wsl`。日志里记录了 `wsl --version`、`wsl -l -v`（WSL 1 还是 2）和 `uname -a`，便于解读结果。

### 本地运行

在装有 WSL 和 Go 的 Windows 11 上，用 PowerShell 执行：

```powershell
wsl --install -d Ubuntu-24.04
$env:WSL_DISTRO = 'Ubuntu-24.04'
$env:VFOX_VERSION = 'latest'; $env:MIRROR = 'default'; $env:NODE_VERSION = '20.16.0'
cd ./vfox-nodejs/tests/e2e/
go test -v -timeout 55m -run TestE2E ./wsl
```

## 本地检查

在开发容器里执行，下面所有工具都已预装，版本和工作流使用的一致；也可以在宿主上装好同样的工具。

```bash
# Lua 和 Go 检查（.github/workflows/lint.yml）。
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
# 许可证头（.github/workflows/license.yml）。
license-eye header check
license-eye header fix
addlicense -check -f .license.tpl tests/e2e/windows/*.ps1
addlicense -f .license.tpl tests/e2e/windows/*.ps1
```

在只有 Docker 的宿主上，许可证检查改用容器运行（和 CI 用的镜像相同）：

```bash
docker run --rm -v "$PWD:/work" -w /work apache/skywalking-eyes:0.9.0 header check
docker run --rm -v "$PWD:/work" -w /work apache/skywalking-eyes:0.9.0 header fix
docker run --rm -v "$PWD:/src" ghcr.io/google/addlicense:v1.2.0 -check -f .license.tpl tests/e2e/windows/*.ps1
docker run --rm -v "$PWD:/src" ghcr.io/google/addlicense:v1.2.0 -f .license.tpl tests/e2e/windows/*.ps1
```
