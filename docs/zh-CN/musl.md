# musl libc 支持（Alpine、OpenWrt/ImmortalWrt）

[中文](musl.md) | [English](../musl.md)

Node.js 官方的 Linux 压缩包链接的是 glibc（`ld-linux-*`）。musl 系统上没有 glibc 的加载器，所以下载官方原版的包后无法运行，会报 `not found` 或 `Error loading shared library ld-linux-aarch64.so.1`。见 [issue #29](https://github.com/version-fox/vfox-nodejs/issues/29)。

这个插件会检测 musl，改为安装 musl 压缩包。

## Alpine 上的最短流程

```sh
apk add bash libstdc++ libatomic
vfox add nodejs
vfox install nodejs@24
vfox use --global nodejs@24
```

`vfox use` 要求 vfox 已经挂载到 Shell，而 vfox 不支持 BusyBox 的 `ash`（`vfox activate sh` 会报 `unknown target shell sh`），所以要在 bash 里运行，并且先在那里执行 `eval "$(vfox activate bash)"`。这两个库的作用见下文。

## 依赖的系统库

Node.js 的 musl 包会链接一些系统库，插件不负责安装它们。原版 Alpine 镜像里一个都没有，常见的工具链也不一定会把它们装进来：

| 库 | 需要它的包 | Alpine | OpenWrt、ImmortalWrt |
| --- | --- | --- | --- |
| `libstdc++` | 所有 musl 包 | `apk add libstdc++` | `libstdcpp` 包 |
| `libatomic` | 26.8.0 及以后的 musl 包 | `apk add libatomic` | `libatomic`，未验证 |

安装时会检查这些库，避免安装看似成功、之后 `node --version` 却失败。刚解压完，`PostInstall` 钩子先在常见的库目录里查找 `libstdc++`，再运行一次 `node --version`：还缺别的库的话，动态加载器会指出是哪一个。报错信息会写出缺的是哪个包以及安装它的命令，这次安装不会被登记（只装过这一个版本的话，`vfox list nodejs` 会显示 `no available version`），装好库之后，再执行一次 `vfox install`。在无法运行命令的环境里，或者 `node` 因别的原因失败时，插件不会干预这次安装。

```text
plugin [PostInstall] method error: <path>:<line>: Node.js (musl build) requires the libstdc++ system package, which was not found on this system. Install it with `apk add libstdc++` and reinstall. See https://github.com/version-fox/vfox-nodejs/blob/main/README.md
failed to install nodejs
```

```text
plugin [PostInstall] method error: <path>:<line>: Node.js (musl build) requires the libatomic system package, which was not found on this system. Install it with `apk add libatomic` and reinstall. See https://github.com/version-fox/vfox-nodejs/blob/main/README.md
failed to install nodejs
```

在 OpenWrt 上，命令是 `opkg install libstdcpp`。既不是 Alpine 也不是 OpenWrt 的系统，得到的信息里不带命令。库里缺少某个符号时，加载器会报 `Error relocating ...: symbol not found`，安装最终则报 `Node.js (musl build) cannot run on this system: Error relocating ...`。

未发布：0.5.2 只查找 `libstdc++`，它的报错信息写的是 `It is normally installed automatically; install it and reinstall.`，没有给出命令。它不查找 `libatomic`：安装会成功，之后 `node` 运行失败。

```text
Error loading shared library libatomic.so.1: No such file or directory (needed by /root/.vfox/cache/nodejs/v-26.12.0/nodejs-26.12.0/bin/node)
Error relocating /root/.vfox/cache/nodejs/v-26.12.0/nodejs-26.12.0/bin/node: __atomic_compare_exchange: symbol not found
```

哪些版本需要 `libatomic`，是在 Alpine 3.24.1（x86_64）上、只装了 `libstdc++` 的情况下检查的：18.20.8、22.23.3、24.20.0、24.22.0、25.2.0、25.6.0、25.9.0、26.0.0 和 26.5.1 能运行，26.8.0、26.11.1 和 26.12.0 不能。后面这三个的共同点是都由 nodejs.org 提供：它的 26 的 musl 包从 26.8.0 开始，更早的 26.x 来自 Unofficial Builds，见下文。nodejs.org 提供的 22.23.3、24.20.0 和 24.22.0 的包，没有 `libatomic` 也能运行。已经装了 `gcc` 的系统自带 `libatomic`，所以 E2E 镜像（`go` 依赖 `gcc`）不会暴露这个问题。

`libatomic1` 是同一个库在 Debian 和 Ubuntu 上的包名，Node.js 25 及以后的 glibc 包会链接它，见 [platforms.md](platforms.md#linux)。

## 安装哪个压缩包

| 系统 | 压缩包 | 来源 |
| --- | --- | --- |
| Linux glibc，x64/arm64 | `node-v<V>-linux-x64.tar.gz` 等 | `nodejs.org/dist` |
| Linux musl，x64 | `node-v<V>-linux-x64-musl.tar.gz` | nodejs.org 有这个版本时用 `nodejs.org/dist`，否则用 `unofficial-builds.nodejs.org` |
| Linux musl，arm64 | `node-v<V>-linux-arm64-musl.tar.gz` | `unofficial-builds.nodejs.org`（nodejs.org 从不提供） |

说明：

- nodejs.org 上没有的版本会自动回退到 `https://unofficial-builds.nodejs.org/download/release`，插件会给出提示：`Note: node-v25.9.0-linux-x64-musl.tar.gz is not listed in https://nodejs.org/dist/v25.9.0/, using unofficial musl build`。
- musl 上镜像的行为（镜像何时生效，何时改用非官方构建），见[镜像](mirror.md)。
- musl 构建只有 `x64` 和 `arm64`。其他 Linux 架构（比如 `x86` 或 `armv7l`）会报错，信息里指向 README。
- 每次 musl 安装一开始都会打印一条提示，写明装的是哪个包，并指向 README：`Note: musl libc detected, installed node-v22.23.3-linux-x64-musl.tar.gz. See ...`。

## 哪些版本有 musl 构建

截至 2026-10-21，数据来自 nodejs.org 和 Unofficial Builds 各自的 `index.json` 与 `SHASUMS256.txt`：

| | nodejs.org | Unofficial Builds |
| --- | --- | --- |
| x64 | 22.23.3、24.20.0 到 24.22.0，以及 26.8.0 及以后 | 8.16.0 及以后，但不是每个版本都有 |
| arm64 | 无 | 20.20.1 和 20.20.2，22.21.1 及以后的 22.x，24.9.0 及以后，25.2.0 及以后，以及 26 的所有版本 |

- x64 上，12.0.0 起的每个版本都有，12.11.0、13.9.0、13.10.0 和 19.8.0 除外。8.x、10.x 和 11.x 只有一部分有构建，9.x 和 8.16.0 之前的版本都没有。
- arm64 上，18、19、21 和 23 都没有，20.20.1 之前的版本线也没有。
- 没有对应包的版本，安装最终会报 `Node.js package node-v9.11.2-linux-x64-musl.tar.gz is not listed in https://nodejs.org/dist/v9.11.2/SHASUMS256.txt`。换一个版本，或者见 [platforms.md](platforms.md)。
- 两个站点的内容都会变。[development.md](development.md#更新平台表) 说明了怎样重新查一遍。

## 检测与覆盖

`lib/util.lua` 里的检测顺序：

1. `$VFOX_NODEJS_LIBC`：`musl` 强制使用 musl，`gnu`/`glibc` 强制使用 glibc。适合非常规的用户空间环境和测试。
2. vfox 核心将来如果提供 `RUNTIME.envType`，就用它（`musl`/`gnu`）。
3. 能从 Lua 里读取的文件探测：`/etc/alpine-release`，以及 `/lib`、`/usr/lib`、`/lib64` 下的 `ld-musl-*.so.1`。两种链接器同时存在时（比如 `gcompat` 这类 shim），以 musl 为准。非 Linux 系统一律不算 musl。

```sh
# 强制选择 musl（仅用于调试）
VFOX_NODEJS_LIBC=musl vfox install nodejs@26.11.1
```

反过来强制使用 glibc，装上的是无法在 musl 上运行的 glibc 包。在 Alpine 上，`VFOX_NODEJS_LIBC=gnu vfox install nodejs@20.20.2` 装的是 `node-v20.20.2-linux-x64.tar.gz`，运行其中的 `node` 会报 `not found`。
