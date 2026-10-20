# 问题排查

[中文](troubleshooting.md) | [English](../troubleshooting.md)

下面的提示是用 vfox 1.0.12 和 1.0.13 得到的。插件自己的错误，vfox 会在前面加上 `plugin [PreInstall] method error: <path>:<line>:`（搜索时是 `[Available]`），后面跟一段 Lua 堆栈跟踪，本页省略了这一段。

## 插件给出的提示

### `version not found for provided version lts`

`nodejs@` 后面既不是版本号，也不是某个版本号的开头。插件认识 `latest`、`24.21.0`、`24.21` 和 `24`，见 [versions.md](versions.md)。`lts`、`lts/iron`、`stable`、`24.21.0.1` 和 `24.0.0-rc.1` 都会报这个错，`99` 和 `22.99` 也一样：它们的格式没有问题，但没有任何版本以它们开头。要安装某条 LTS 版本线，请按编号安装，见 [lts.md](lts.md#安装一条-lts-版本线)。

### `get checksum failed: HTTP 404 from https://nodejs.org/dist/v24.99.0/SHASUMS256.txt`

插件读不到这个版本的 `SHASUMS256.txt`，原因写在冒号后面。`HTTP 404 from <address>` 表示服务器上没有这个文件：要么这个版本不存在（`24.99.0`），要么镜像里没有它。网络错误（`Get "<address>": tls: failed to verify certificate: x509: certificate signed by unknown authority`、`... connection refused`、`... EOF`）表示连不上服务器：镜像不可用、代理有问题，或者 TLS 出了问题。见[网络](#网络)。

未发布：0.5.2 只打印 `get checksum failed`，没有别的内容，所以看不出原因。`vfox search nodejs` 向同一台服务器请求索引，会打印真正的错误。

### `Node.js package node-v19.8.1-win-arm64.zip is not listed in https://nodejs.org/dist/v19.8.1/SHASUMS256.txt`

这个版本是存在的，但 Node.js 没有以插件请求的名字为你的平台发布包。`vfox search nodejs` 列出的版本里，有的并没有你所在平台的包，因为索引里没有写明哪些版本有。提示里的文件名就是插件要找的那个。请对照 [platforms.md](platforms.md)，它也列出了不支持的情况（ARMv6、24 起的 32 位 ARM、riscv64、loong64）。

在 Alpine 等 musl 系统上，文件名以 `-musl.tar.gz` 结尾，插件还去 unofficial-builds.nodejs.org 找过。见 [musl.md](musl.md#哪些版本有-musl-构建)。

### `Failed to fetch Node.js versions: ...`

获取 `index.json` 的请求失败了。冒号后面是网络错误（`Get "https://nodejs.org/dist/index.json": ...`），或者 HTTP 状态码（`HTTP 404`，镜像在该地址没有 `index.json`）。见[网络](#网络)。0.5.0 之前，请求失败只会得到一个空列表，vfox 还会把它缓存起来。

### `Cannot determine Node.js package architecture from RUNTIME.archType`

vfox 没有告诉插件当前运行在哪种 CPU 上。这是不应该出现的情况，请连同 `vfox --version` 的输出一起报告。

### `Node.js musl builds are only available for x64 and arm64, got x86. See ...`

插件把这个系统当成了 musl 系统，而 Node.js 没有适用于这种 CPU 的 musl 包（会停在这里的是 `x86` 和 `armv7l`）。如果系统其实不是 musl，请设置 `VFOX_NODEJS_LIBC=glibc`，见 [musl.md](musl.md#检测与覆盖)。

### `Node.js (musl build) requires the libatomic system package, which was not found on this system. ...`

这个 musl 系统缺少 Node.js 的 musl 包所链接的库：所有 musl 包都链接 `libstdc++`，26.8.0 及以后的 musl 包还链接 `libatomic`。提示里写明了缺的是哪个包，以及在 Alpine（`apk add libatomic`）和 OpenWrt（`opkg install libatomic`）上安装它的命令。安装在解压之后失败，不会登记任何内容。请先安装这个库，再重新执行安装。见 [musl.md](musl.md#依赖的系统库)。

未发布：0.5.2 只查找 `libstdc++`，提示里也没有命令。缺少 `libatomic` 要到后面才会暴露，表现为 `node` 自己报的错，见下文。

### `Node.js (musl build) cannot run on this system: Error relocating ...`

解压出来的 `node` 需要一个符号，而系统里没有任何库提供它。安装在解压之后失败，不会登记任何内容。未发布：0.5.2 在解压之后不会运行 `node`，这个错误要到你自己运行它的时候才会出现。见 [musl.md](musl.md#依赖的系统库)。

### `checksum error`

vfox 会打印 `Verifying checksum <sum>...`，拿下载的文件和这个校验和比对，不一致就停下来，并指出它丢弃的文件：`Checksum error, file: ~/.vfox/cache/nodejs/node-v24.21.0-linux-x64.tar.gz`。常见的原因是下载被截断，或者镜像上的文件与它自己的 `SHASUMS256.txt` 对不上。不会安装任何东西。请重试，或者换一个[镜像](mirror.md)。

### `nodejs@24.99 is not installed`

`vfox use` 和 `vfox uninstall` 只认已安装的版本，`vfox list nodejs` 可以看到它们。对已安装的版本，`vfox use` 接受 `24`、`24.21` 和 `24.21.0`，`vfox uninstall` 需要写完整的版本号。见 [versions.md](versions.md#使用)。

### `vfox requires hook support. Please ensure vfox is properly initialized with 'vfox activate'`

`vfox use` 要修改当前 Shell 的环境，只有把 vfox 挂载到 Shell 之后才能做到。请把 `eval "$(vfox activate bash)"`（或者你所用 Shell 对应的那一行）加到该 Shell 的启动文件里，见 vfox 的[快速入门](https://vfox.dev/zh-hans/guides/quick-start.html)。vfox 不支持 Alpine 自带的 `sh`，请在那里安装 `bash`。

### `plugin named nodejs already exists`

`vfox add nodejs` 发现已经添加过这个插件了。如果添加的是源码构建的插件，见 [source-build.md](source-build.md#已经添加过-nodejs-时)。

### `Plugin nodejs is not installed. Use the -y flag to automatically install plugins in non-interactive environments`

插件没有添加，或者 `VFOX_HOME` 指向的目录不是添加它的那个目录。请运行 `vfox add nodejs`。

### 插件打印的 Note

这些都不是错误。

| Note | 含义 |
| --- | --- |
| `Note: Node.js versions below 16 do not support Apple Silicon (arm64), using x64 architecture with Rosetta 2` | 在 macOS arm64 上安装早于 16.0.0 的版本，见 [platforms.md](platforms.md#macos) |
| `Note: musl libc detected, installed node-v22.23.3-linux-x64-musl.tar.gz. See ...` | 插件安装的是 musl 包，见 [musl.md](musl.md) |
| `Note: node-v18.20.8-linux-x64-musl.tar.gz is not listed in https://nodejs.org/dist/v18.20.8/, using unofficial musl build` | nodejs.org 没有这个 musl 包，插件改从 unofficial-builds.nodejs.org 获取 |
| ``Note: /home/me/.local/share/pnpm/bin/node comes before vfox in PATH, so `node` will not run nodejs@24.21.0. See ...`` | 另一个 `node` 遮蔽了 vfox 的，见 [pnpm.md](pnpm.md) |

### Node.js 自己报的错

这些是安装成功之后 `node` 报的错。

- `node: error while loading shared libraries: libatomic.so.1: cannot open shared object file`。Node.js 25 及以后的版本要链接 `libatomic`，而原版 Debian 和 Ubuntu 没有它：`sudo apt install --assume-yes libatomic1`。见 [platforms.md](platforms.md#linux)。
- 在 Alpine 上报 `node: not found`，尽管文件是存在的。这是把 glibc 的包安装到了 musl 系统上：要么插件没有检测到 musl，要么 `VFOX_NODEJS_LIBC` 的值是 `gnu` 或 `glibc`。见 [musl.md](musl.md#检测与覆盖)。
- 在 Alpine 上先报 `Error loading shared library libatomic.so.1: No such file or directory`，接着报 `Error relocating ...: __atomic_compare_exchange: symbol not found`。26.8.0 及以后的 musl 包需要 `libatomic`：`apk add libatomic`。未发布：安装本身会以上面那条提示停下来，0.5.2 则要到这里才会报错。见 [musl.md](musl.md#依赖的系统库)。
- 在 musl 系统上报 `Error relocating ... symbol not found`，而且前面没有上一条里关于 `libatomic` 的那一行。说明缺少某个库，或者库的版本太旧。未发布：安装会以 `cannot run on this system` 停下来，0.5.2 则要到这里才会报错。见 [musl.md](musl.md#依赖的系统库)。

## 网络

插件向服务器请求两样东西，vfox 再下载第三样：

| 内容 | 地址 |
| --- | --- |
| 版本列表（`vfox search`、`latest`、`nodejs@24`） | `<mirror>/index.json` |
| 某个版本的校验和（`vfox install`） | `<mirror>/v<version>/SHASUMS256.txt` |
| 包（由 vfox 下载） | `<mirror>/v<version>/<package>` |

`<mirror>` 是 `https://nodejs.org/dist`，除非 `VFOX_NODEJS_MIRROR` 另有设置，见 [mirror.md](mirror.md)。musl 系统还可能用到 `https://unofficial-builds.nodejs.org/download/release`。

vfox 自己的代理设置对插件发出的请求和下载都有效：

```bash
vfox config proxy.enable true
vfox config proxy.url http://127.0.0.1:7890
```

`proxy.enable` 为 `false` 时，通常的 `HTTP_PROXY`、`HTTPS_PROXY` 和 `NO_PROXY` 环境变量依然有效。代理不可用时，搜索会显示 `proxyconnect tcp: dial tcp 127.0.0.1:7890: connect: connection refused`。

`vfox search nodejs` 的常见失败原因如下。`vfox install` 会在 `get checksum failed:` 之后报告同样的原因。未发布：0.5.2 会省略它，只有搜索会打印：

| `Failed to fetch Node.js versions:` 之后 | 原因 |
| --- | --- |
| `Get "https://nodejs.org/dist/index.json": tls: failed to verify certificate: x509: certificate signed by unknown authority` | 系统里没有 CA 证书，比如最基础的 Debian 或 Ubuntu Docker 镜像：`apt-get install ca-certificates` |
| `Get "...": ... connection refused`、`i/o timeout` 或 `no such host` | 连不上服务器：没有路由、代理不可用、镜像地址写错，或者 DNS 有问题。可以试试[镜像](mirror.md)或者代理设置 |
| `HTTP 404` | 镜像在该地址没有 `index.json`。请把 `VFOX_NODEJS_MIRROR` 指向存放它的目录 |

## 看起来不对，其实没问题

- **`vfox search` 里没有你预期的版本。** vfox 会缓存搜索结果 12 小时。`vfox config cache.availableHookDuration 0` 可以关闭缓存。镜像也可能落后于 nodejs.org。
- **`vfox search nodejs` 列出了一个装不上的版本。** 这个列表就是所有平台共用的索引，见 [platforms.md](platforms.md)。
- **`vfox search nodejs 24` 不会过滤。** 参数会被忽略，见 [versions.md](versions.md#搜索)。
- **`vfox install nodejs@24` 什么也没有下载。** 最新的 24.x 已经装好了：`nodejs@24.22.0 is already installed`。
- **`vfox use nodejs@24.21.0` 显示了 `Now using`，而 `node -v` 打印的是另一个版本。** 在带有 `.nvmrc` 或 `.node-version` 的目录里，下一次出现提示符时以文件为准，见 [nvmrc.md](nvmrc.md)。`PATH` 里排在 vfox 前面的另一个 `node` 也会胜出，`vfox use` 会提示这一点，见 [pnpm.md](pnpm.md)。
- **`vfox current nodejs` 和 `node -v` 的结果不一致。** 原因同上。前者给出的是会话或作用域里的选择，后者是 `PATH` 实际找到的。
- **`vfox use` 之后，全局安装的 npm 包不见了。** 全局包属于某个版本，见 [npm.md](npm.md#全局包属于某个版本)。
- **找不到 `corepack`。** Node.js 25 及以后的版本不自带它，见 [npm.md](npm.md#yarnpnpm-与-corepack)。
- **`.nvmrc` 什么也没选中。** 请检查策略和文件里的内容，见 [nvmrc.md](nvmrc.md#没有生效)。
- **`git status` 列出了 `.vfox/`。** vfox 会把这个版本以 `.vfox/sdks/nodejs` 的形式链接到项目里。请在 `.gitignore` 里忽略 `.vfox/`，并保留 `.vfox.toml`。
- **安装后的版本名里没有 `v`。** 版本的名字形如 `24.21.0`，你输入时带的 `v` 会被去掉。

## Node.js 在哪里

| 作用域 | `node` 来自哪里 |
| --- | --- |
| `--global` | `~/.vfox/sdks/nodejs`，指向该版本的链接。`~/.vfox/sdks/nodejs/bin` 在 `PATH` 里 |
| `--project` | 项目里的 `.vfox/sdks/nodejs`，指向该版本的链接，版本名记录在 `.vfox.toml` 里 |
| 会话（默认） | `~/.vfox/tmp/<date>-<pid>/nodejs` 下的一个目录 |

版本本身在 `~/.vfox/cache/nodejs/v-<version>/nodejs-<version>/`，里面有 `bin/node`、`bin/npm` 和 `lib/node_modules`。`vfox info nodejs@24.21.0` 打印的是它的上一级目录。`~/.vfox` 是 `$VFOX_HOME` 的默认值。设置了 `VFOX_HOME`（指向一个已存在的目录）之后，插件和各个版本（`cache/`）放在那里，`sdks/nodejs` 链接和会话目录仍留在 `~/.vfox`。`storage.sdkPath` 会让新安装的版本放到 `<path>/nodejs/` 下，见 vfox 的[配置文档](https://vfox.dev/zh-hans/guides/configuration.html)。在 Windows 上，`node.exe` 直接放在版本目录里。

## 报告问题

请到 [version-fox/vfox-nodejs](https://github.com/version-fox/vfox-nodejs/issues) 提 issue，附上 `vfox --version` 和 `vfox info nodejs` 的输出、操作系统和 CPU、你执行的命令以及它打印的全部内容。`vfox --debug <command>` 会打印更多信息；排查 `.nvmrc` 时，`vfox --debug env -s bash` 也一样。vfox 本身的问题请向 [vfox](https://github.com/version-fox/vfox/issues) 反馈。
