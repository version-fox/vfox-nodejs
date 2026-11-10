# 镜像

[中文](mirror.md) | [English](../mirror.md)

Node.js 的包和版本索引（`index.json`、`SHASUMS256.txt`）默认从 `https://nodejs.org/dist` 下载。想用别的镜像，设置 `VFOX_NODEJS_MIRROR`：

```bash
export VFOX_NODEJS_MIRROR="https://npmmirror.com/mirrors/node"
vfox install nodejs@26.11.1
```

请把它指向镜像站上与 `nodejs.org/dist` 对应的根地址；插件会把自己用到的路径（`/index.json`、`/v<version>/...`）接在这个基础 URL 后面。末尾的斜杠会被处理，所以 `https://nodejs.org/dist` 和 `https://nodejs.org/dist/` 都可以用。

## 怎样设置

这个变量是从运行 vfox 的进程的环境里读取的，所以要按你所用 Shell 设置环境变量的方式来设置它：

```bash
# bash、zsh：写在 ~/.bashrc 或 ~/.zshrc 里
export VFOX_NODEJS_MIRROR="https://npmmirror.com/mirrors/node"

# fish
set -Ux VFOX_NODEJS_MIRROR https://npmmirror.com/mirrors/node

# 只对一条命令生效
VFOX_NODEJS_MIRROR=https://npmmirror.com/mirrors/node vfox search nodejs
```

```powershell
# PowerShell：只对当前会话有效
$env:VFOX_NODEJS_MIRROR = "https://npmmirror.com/mirrors/node"

# PowerShell：对当前用户生效，之后打开的 Shell 里都有
[Environment]::SetEnvironmentVariable("VFOX_NODEJS_MIRROR", "https://npmmirror.com/mirrors/node", "User")
```

值为空等同于没有设置，使用的是 `https://nodejs.org/dist`。

## 镜像要提供什么

和 `nodejs.org/dist` 相同的目录结构：

```text
<mirror>/index.json
<mirror>/v24.21.0/SHASUMS256.txt
<mirror>/v24.21.0/node-v24.21.0-linux-x64.tar.gz
```

- `index.json` 决定了 `vfox search nodejs`、`nodejs@latest`、`nodejs@24` 和 `nodejs@24.21` 能看到哪些版本。更新滞后的镜像列出的版本更少；列出了却没有提供的版本，会在下载时失败。
- 下载的文件会与镜像自己的 `SHASUMS256.txt` 里的校验和比对。文件与校验和对不上的镜像，最终会报 `checksum error`。
- 镜像可能在文件还没有备齐时就列出了某个版本。2026-11-03，也就是 Node.js 26.13.0 发布六天之后，npmmirror 和华为云列出了它，也有它的 34 个包，却没有它的 `SHASUMS256.txt`，所以通过其中任何一个执行 `vfox install nodejs@26.13.0`，都会以 `get checksum failed: HTTP 404 from https://npmmirror.com/mirrors/node/v26.13.0/SHASUMS256.txt` 结束。插件只询问一个镜像，所以在第一个镜像追上之前，请把 `VFOX_NODEJS_MIRROR` 指向下面列表里的另一个镜像，或者取消设置，改用 nodejs.org。
- 会跟随重定向。`https://npmmirror.com/mirrors/node` 对 `index.json` 的请求回应的是重定向，也能正常使用。

## 可用的镜像

这些镜像在 2026-10-21 检查过：每个镜像提供的 `index.json` 都和 nodejs.org 一样列有 872 个版本，`node-v24.21.0-linux-x64.tar.gz` 的 SHA-256 校验和以及包本身都与 nodejs.org 一致，也都提供了 26.12.0 的 musl 包。天翼云是 2026-11-03 用同样的方法检查的。这份列表只是记录检查结果，不为任何镜像背书。镜像随时可能变化或消失，插件无从得知。

| 镜像 | `VFOX_NODEJS_MIRROR` |
| --- | --- |
| npmmirror | `https://npmmirror.com/mirrors/node`（`https://cdn.npmmirror.com/binaries/node` 是同一份数据） |
| 华为云 | `https://mirrors.huaweicloud.com/nodejs` |
| 清华大学（TUNA） | `https://mirrors.tuna.tsinghua.edu.cn/nodejs-release` |
| 中国科学技术大学（USTC） | `https://mirrors.ustc.edu.cn/node` |
| 阿里云 | `https://mirrors.aliyun.com/nodejs-release` |
| 腾讯云 | `https://mirrors.cloud.tencent.com/nodejs-release` |
| 南京大学 | `https://mirror.nju.edu.cn/nodejs-release` |
| 北京外国语大学 | `https://mirrors.bfsu.edu.cn/nodejs-release`（会重定向到 TUNA） |
| 天翼云 | `https://mirrors.ctyun.cn/nodejs-release` |

2026-11-03，又用 vfox 1.0.13 通过它们各安装了一次 24.21.0（`VFOX_NODEJS_MIRROR=<mirror> vfox install nodejs@24.21.0`），每一个都安装成功并且能运行。0.5.4 之前，通过华为云、TUNA、USTC 和北外安装会以 `checksum error` 结束：下载由 vfox 自己完成，它请求时使用的是 Go HTTP 客户端的 `User-Agent`，即 `Go-http-client/1.1`，华为云（HTTP 418）、TUNA 和北外（403）以及 USTC（204，没有内容）对它返回的是错误页面或者空内容，而不是安装包，vfox 把这个回应存成了文件。插件请求 `index.json` 和 `SHASUMS256.txt` 时用的是 vfox 为它生成的 `User-Agent`，即 `vfox/1.0.13 vfox-nodejs/0.5.5`，这些镜像都正常响应，下载时也改用同一个。

只做重定向的地址没有列出：2026-11-03，`mirror.sjtu.edu.cn/nodejs-release` 把请求转到了 nodejs.org，`mirrors.cernet.edu.cn/nodejs-release` 则转到了中科大的一台服务器。

Node.js 的镜像不是 npm 的 registry。`npm install` 获取的包来自 npm 配置里的 registry，例如 `npm config set registry https://registry.npmmirror.com`，见 [npm.md](npm.md)。

## 确认设置生效

没有响应的镜像会直接失败，不会回退到 nodejs.org，据此可以确认变量确实被读取了：

```bash
VFOX_NODEJS_MIRROR=https://example.invalid/dist vfox search nodejs
# Failed to fetch Node.js versions: Get "https://example.invalid/dist/index.json": ...
```

在同一个镜像上，`vfox install nodejs@24.21.0` 会失败，报 `get checksum failed: Get "https://example.invalid/dist/v24.21.0/SHASUMS256.txt": ...`。镜像在那个地址上没有提供 `index.json` 时，搜索会失败，报 `Failed to fetch Node.js versions: HTTP 404`，见 [troubleshooting.md](troubleshooting.md#网络)。vfox 会把搜索结果缓存 12 小时，所以改动之后请执行 `vfox config cache.availableHookDuration 0`，否则在一段时间内看到的还是旧列表。

代理是另一项设置，对镜像同样有效，见 [troubleshooting.md](troubleshooting.md#网络)。

## musl 与非官方构建

`VFOX_NODEJS_MIRROR` 只管 `nodejs.org/dist`，**不**适用于 `https://unofficial-builds.nodejs.org/download/release`，插件在 musl Linux 上把它当作回退来源（见 [musl](musl.md)）：

- Linux musl x64，并且 nodejs.org 提供该版本的 musl 包（22.23.3、24.20.0 到 24.22.0、26.8.0 及之后）：使用官方的 `*-musl` 压缩包，所以镜像照常生效（前提是镜像提供它）。
- Linux musl arm64（所有版本），或者其他任何版本上的 musl x64：官方索引里没有这样的文件，所以插件直接从 `unofficial-builds.nodejs.org` 下载，忽略镜像。

连 `SHASUMS256.txt` 都提供不了的镜像，安装仍然会失败，不会回退；只有缺少 musl 文件名时，才会转到非官方构建。
