# 平台支持

[中文](platforms.md) | [English](../platforms.md)

插件会按操作系统和 vfox 二进制所属的 CPU 架构（`RUNTIME.osType` 和 `RUNTIME.archType`，即 Go 的 `GOOS` 和 `GOARCH`）选择包，在 Linux 上还要按 C 库选择。它请求的文件名是这样的：

```text
node-v<version>-<os>-<arch><extension>
```

`<os>` 是 `linux`、`darwin` 或 `win`。`<arch>` 是 `x64`、`x86`、`armv7l`、`arm64`、`ppc64le` 或 `s390x`：`amd64` 变成 `x64`，`386` 变成 `x86`，`arm` 变成 `armv7l`，其余的名字按 vfox 报告的原样传递。`<extension>` 在 Windows 上是 `.zip`，其他系统上是 `.tar.gz`。musl Linux 上，架构后面还有 `-musl`，见 [musl.md](musl.md)。

插件会读取该版本目录下的 `SHASUMS256.txt`。这个文件里没有列出该包时，安装会在下载任何内容之前停止：

```text
Node.js package node-v19.8.1-win-arm64.zip is not listed in https://nodejs.org/dist/v19.8.1/SHASUMS256.txt
```

## 各平台有哪些版本

这张表取自 2026-10-21 的 nodejs.org，数据来自 `index.json` 里 872 个版本各自的 `SHASUMS256.txt`。“版本”一列写的是：按插件使用的文件名，有包的第一个版本和最后一个版本；中间的空缺，是 Node.js 没有发布这个包的版本。重新获取这张表的方法见 [development.md](development.md#更新平台表)。

| vfox 报告的平台 | 包 | 版本 |
| --- | --- | --- |
| Linux amd64 | `linux-x64.tar.gz` | 0.8.6 及以后，0.9.0、0.11.4 和 0.11.6 除外 |
| Linux arm64 | `linux-arm64.tar.gz` | 4.0.0 及以后 |
| Linux ppc64le | `linux-ppc64le.tar.gz` | 4.3.2 及以后，5.0.0 到 5.6.0 除外 |
| Linux s390x | `linux-s390x.tar.gz` | 6.6.0 及以后 |
| Linux 386 | `linux-x86.tar.gz` | 0.8.6 到 9.11.2，0.9.0、0.11.4 和 0.11.6 除外 |
| Linux arm | `linux-armv7l.tar.gz` | 4.0.0 到 23.11.1，8.1.1 除外 |
| Linux amd64，musl | `linux-x64-musl.tar.gz` | 见 [musl.md](musl.md#哪些版本有-musl-构建) |
| Linux arm64，musl | `linux-arm64-musl.tar.gz` | 见 [musl.md](musl.md#哪些版本有-musl-构建) |
| macOS amd64 | `darwin-x64.tar.gz` | 0.8.6 及以后，0.9.0、0.11.4 和 0.11.6 除外 |
| macOS arm64 | `darwin-arm64.tar.gz` | 16.0.0 及以后。更早的版本装的是 amd64 的包，见 [macOS](#macos) |
| Windows amd64 | `win-x64.zip` | 4.5.0 及以后，5.0.0 到 5.12.0 和 6.0.0 到 6.2.0 除外 |
| Windows 386 | `win-x86.zip` | 4.5.0 到 22.23.3，5.0.0 到 5.12.0、6.0.0 到 6.2.0 和 18.0.0 到 18.2.0 除外 |
| Windows arm64 | `win-arm64.zip` | 19.9.0 及以后 |

从 19.9.0 起，表里没有上限的每一行，每个版本都有包。32 位的几行结束得早：Windows 上到 22.23.3 为止，Linux arm 上到 23.11.1 为止，Linux x86 上到 9.11.2 为止，所以 32 位的 vfox 装不了较新的版本。

不论在哪个平台，`vfox search nodejs` 都会列出全部 872 个版本，因为索引里没有写明一个版本有哪些平台的包。所以在 Windows arm64 上，`vfox install nodejs@19.8.1` 一开始一切正常，最后会报上面那条信息，见 [troubleshooting.md](troubleshooting.md#插件给出的提示)。

## 不支持的情况

- **ARMv6，以及 24 起的 32 位 ARM。** vfox 提供一个 `armv7` 的二进制，它报告的是 `arm`，插件为它选 `linux-armv7l` 包，而这个包 Node.js 只发布到 23.11.1。24 起就没有了，安装最终会报 `Node.js package node-v26.12.0-linux-armv7l.tar.gz is not listed in ...`。ARMv6 的包（nodejs.org 上的 `linux-armv6l`，4.0.0 到 11.15.0）从不会被选中。
- **Linux riscv64 和 loong64。** nodejs.org 没有它们的包。[Unofficial Builds](https://github.com/nodejs/unofficial-builds) 站点有 riscv64（17.7.1 到 26.0.0）和 loong64（18.18.0 及以后），但插件只在 musl 上使用那个站点。

## Linux

插件使用 glibc 的包；检测到 musl 时用 musl 的包，见 [musl.md](musl.md#检测与覆盖)。某个版本需要什么样的 glibc 和内核，是 Node.js 自己的事，见[Node.js 支持的平台](https://github.com/nodejs/node/blob/main/BUILDING.md)。系统库由用户自己负责，插件一个也不会安装。需要留意的有两个：

- Node.js 25 及以后的 glibc 包会链接 `libatomic.so.1`，而原版的 Debian 和 Ubuntu 镜像里没有它。这时 `node` 会失败，报 `error while loading shared libraries: libatomic.so.1`。用 `sudo apt install --assume-yes libatomic1` 安装它。24 及更早的版本不链接它（检查过 25.9.0 和 26.12.0，对照的是 24.21.0 和 20.20.2），见 [nodejs/node#60790](https://github.com/nodejs/node/issues/60790)。
- musl 包需要 `libstdc++`，见 [musl.md](musl.md#依赖的系统库)。

在 WSL 里，vfox 是 Linux 二进制，所以使用 Linux 的包。

## macOS

包是 `darwin-x64.tar.gz` 和 `darwin-arm64.tar.gz`。Node.js 在 16.0.0 之前没有发布 arm64 的包，所以在 Apple silicon 上，这些版本会改用 amd64 的包，插件会给出提示：

```text
Note: Node.js versions below 16 do not support Apple Silicon (arm64), using x64 architecture with Rosetta 2
```

要运行这些版本，必须装有 Rosetta 2（`softwareupdate --install-rosetta`）。16.0.0 及以后的版本以原生方式安装。

E2E 套件里没有 macOS 作业，见[下文](#ci-覆盖什么)。钩子测试检查了 `darwin/arm64` 的包名。

## Windows

包是 zip 格式。`node.exe`、`npm.cmd` 和 `npx.cmd` 直接放在安装目录里，所以插件把这个目录本身加进 `PATH`。不像 Linux 和 macOS 那样有 `bin` 目录。

- 用户主目录里带空格（`C:\Users\John Doe`）时，需要 vfox 1.0.13 及以后的版本（[vfox#712](https://github.com/version-fox/vfox/pull/712)）。E2E 套件对每种组合都用这样的主目录跑一遍。
- 在 Git Bash 里，vfox 挂载到 Shell 之后，`node`、`npm.cmd` 和不带扩展名的 `npm` 都能运行（[vfox#293](https://github.com/version-fox/vfox/issues/293)）。
- `VFOX_NODEJS_MIRROR` 从运行 vfox 的进程的环境里读取。在 PowerShell 里用 `$env:VFOX_NODEJS_MIRROR = '...'` 为当前会话设置，见 [mirror.md](mirror.md#怎样设置)。

## vfox 自己支持的平台

vfox 1.0.13 提供这些平台的二进制：Linux 的 x86_64、aarch64、armv7、i386 和 loong64，macOS 的 x86_64 和 aarch64，Windows 的 x86_64、aarch64 和 i386。插件直接采用二进制报告的名字，所以你自己为 Linux ppc64le 或 s390x 编译的 vfox，装的是 ppc64le 或 s390x 的包。

## CI 覆盖什么

容器 E2E 套件（见 [e2e.md](e2e.md)）会在下面这些平台上安装一个固定的版本、一个固定的 LTS 版本和 `nodejs@latest`：

| 平台 | Runner |
| --- | --- |
| Linux glibc，amd64 | `ubuntu-latest` |
| Linux glibc，arm64 | `ubuntu-26.04-arm` |
| Linux musl（Alpine），amd64 和 arm64 | 同样两个 runner |
| Windows 容器，amd64 和 arm64 | `windows-latest`、`windows-11-arm` |
| WSL 上的 Ubuntu 24.04 | `windows-2025` |

macOS、32 位系统、ppc64le 和 s390x 没有覆盖。钩子测试（`tests/hooks_test.lua`）离线运行，检查以下平台的包名：`windows` 的 amd64、386 和 arm64，`linux` 的 amd64 和 arm，musl 的 amd64 和 arm64，以及 `darwin` 的 arm64。
