# 变更记录

[中文](changes.md) | [English](../changes.md)

按发布版本列出用户能感受到的变化。GitHub 的 [Release 页面](https://github.com/version-fox/vfox-nodejs/releases)列出了对应的 PR。写这篇文档时最新的发布版是 0.5.2，`main` 比它多出“未发布”下面的所有内容。想现在就用上这些变化，见 [source-build.md](source-build.md)。

## 未发布

- 32 位 ARM 的 Linux 会安装 `linux-armv7l` 包，Node.js 到 23.11.1 为止都发布了这个包：`vfox install nodejs@20` 在那里可以用。vfox 的 `armv7` 构建报告的是 `arm`，而 0.5.2 请求 `linux-arm`，这个包并不存在，所以 32 位 ARM 上的每次安装都以 `Node.js package node-v20.19.5-linux-arm.tar.gz is not listed in ...` 告终。从 24 起没有这个包了，ARMv6 的包也永远不会被选中。见 [platforms.md](platforms.md#不支持的情况)。
- 在 musl 上，解压出来的 `node` 因缺少库而无法运行时，安装会中止。解压之后，插件会运行一次 `node --version`，由动态加载器指出缺少什么。26.8.0 及以后的 musl 包需要 `libatomic`，原版 Alpine 没有它：安装会以 ``Node.js (musl build) requires the libatomic system package, which was not found on this system. Install it with `apk add libatomic` and reinstall.`` 结束，不会登记任何内容。0.5.2 只检查 `libstdc++`，所以安装能成功，而 `node` 会报 `Error loading shared library libatomic.so.1`。关于 `libstdc++` 的提示同样会给出命令，0.5.2 的提示则是 `It is normally installed automatically`。见 [musl.md](musl.md#依赖的系统库)。
- 在 `legacyVersionFile.strategy` 为 `latest_installed` 和 `latest_available` 时，`.nvmrc` 和 `.node-version` 按版本号的数字匹配版本。已安装 22.9.0 和 22.23.3 时，`22` 选中 22.23.3，而 0.5.2 选中 22.9.0，因为 vfox 是按文本排列已安装版本的。`22.2` 不再匹配 22.23.3。`22.x`、`22.x.x` 和 `22.*` 都表示 22，0.5.2 对 `22.x` 什么也选不中。只会去掉开头的 `v`，所以代号里带 `v` 的 `lts/<codename>` 也能用。不是版本号的文本（`node`、`(`、`22[`）不做处理，0.5.2 对它们会报 `unfinished capture at EOS`，而 vfox 把这个错误藏了起来。见 [nvmrc.md](nvmrc.md#前缀怎样匹配)。
- 获取 `SHASUMS256.txt` 的请求失败时会说明原因：`get checksum failed: HTTP 404 from https://nodejs.org/dist/v24.99.0/SHASUMS256.txt`，或者网络错误，比如 `x509: certificate signed by unknown authority`。0.5.2 只打印 `get checksum failed`，没有别的内容。见 [troubleshooting.md](troubleshooting.md#插件给出的提示)。
- `VFOX_NODEJS_MIRROR` 的结尾可以有多个斜杠。0.5.2 只去掉一个。
- 文档有了中文版，见 [README_CN.md](../../README_CN.md)。

## 0.5.2（2026-10-17）

- 当另一个 `node`（比如 `pnpm runtime set node -g` 装的那个）在 `PATH` 里排在 vfox 前面，导致 `node` 不会运行刚选中的版本时，`vfox use` 会打印一条提示。以前 `vfox use` 报告 `Now using`，而 `node -v` 打印的是另一个版本。见 [pnpm.md](pnpm.md)（[#38](https://github.com/version-fox/vfox-nodejs/pull/38)）。
- Windows 的 E2E 作业在含有空格的主目录下运行，这需要 vfox 1.0.13（[#39](https://github.com/version-fox/vfox-nodejs/pull/39)）。

## 0.5.1（2026-10-17）

- Alpine、OpenWrt 等 musl 系统现在装的是 musl 包。以前装的是 glibc 包，`node` 会报 `not found`。nodejs.org 没有 musl 包时，插件改从 unofficial-builds.nodejs.org 获取，这涵盖了全部 arm64 和大部分 x64。`VFOX_NODEJS_LIBC` 可以覆盖检测结果。缺少 `libstdc++` 时，安装会失败，并在提示里指出这个库。见 [musl.md](musl.md)（[#31](https://github.com/version-fox/vfox-nodejs/pull/31)、[#29](https://github.com/version-fox/vfox-nodejs/issues/29)）。
- 在 vfox 1.x 下，`legacyVersionFile.strategy` 设为 `latest_installed` 时，`.nvmrc` 和 `.node-version` 可以正常使用。0.3.0 到 0.5.0 调用 `ctx:getInstalledVersions()`，vfox 1.x 会以 `expected 0 arguments for func() []string, got 1` 拒绝它，而且 vfox 把这个错误藏了起来：文件什么也选不中，连 `22.23.3` 也不行。默认策略 `specified` 不受影响（[#30](https://github.com/version-fox/vfox-nodejs/pull/30)）。
- 在 `latest_available` 下，`lts` 和 `lts/<codename>` 在版本索引里查找，所以比插件还新的代号也仍然有效。其他策略使用的代号表里有 Krypton（24）。见 [lts.md](lts.md)（[#31](https://github.com/version-fox/vfox-nodejs/pull/31)）。
- 仓库有了覆盖 Linux、Alpine、Windows 和 WSL 的容器 E2E 套件，以及一个开发容器，见 [e2e.md](e2e.md)（[#30](https://github.com/version-fox/vfox-nodejs/pull/30)、[#33](https://github.com/version-fox/vfox-nodejs/pull/33)、[#34](https://github.com/version-fox/vfox-nodejs/pull/34)、[#37](https://github.com/version-fox/vfox-nodejs/pull/37)）。

## 0.5.0（2026-09-12）

- 获取不到索引时，`vfox search nodejs` 会以 `Failed to fetch Node.js versions: ...` 报错。以前它什么也不列出，vfox 还会把这个空列表缓存起来（[#28](https://github.com/version-fox/vfox-nodejs/pull/28)、[#16](https://github.com/version-fox/vfox-nodejs/issues/16)）。
- 32 位 x86 请求 `x86` 包。以前请求的是 `386`，这个包并不存在。vfox 给出的架构为空时，安装会以 `Cannot determine Node.js package architecture from RUNTIME.archType` 中止（[#28](https://github.com/version-fox/vfox-nodejs/pull/28)、[#23](https://github.com/version-fox/vfox-nodejs/issues/23)）。
- `SHASUMS256.txt` 没有列出的包，会让安装以 `Node.js package ... is not listed in ...` 中止。以前 vfox 会在没有校验和的情况下继续下载，结果得到 404（[#28](https://github.com/version-fox/vfox-nodejs/pull/28)）。
- `VFOX_NODEJS_MIRROR` 的结尾可以带一个斜杠。以前 URL 里会出现 `//`（[#25](https://github.com/version-fox/vfox-nodejs/pull/25)）。

## 0.4.1（2025-09-29）

- Node.js 16.0.0 在 Apple silicon 上安装 arm64 的包。以前 16 装的是 amd64 的包，而只有 16 之前的版本才应该这样。这些版本会打印 `Note: Node.js versions below 16 do not support Apple Silicon (arm64), using x64 architecture with Rosetta 2`（[#21](https://github.com/version-fox/vfox-nodejs/pull/21)）。

## 0.4.0（2025-09-28）

- `.nvmrc` 和 `.node-version` 遵循 `legacyVersionFile.strategy`。以前它们总是使用 `latest_installed`。见 [nvmrc.md](nvmrc.md)（[#17](https://github.com/version-fox/vfox-nodejs/pull/17)）。
- `lts` 和 `lts/*` 选中代号表里最新的 LTS 版本线，`lts/jod` 也能识别了（[#17](https://github.com/version-fox/vfox-nodejs/pull/17)）。
- 版本未知时会提示 `version not found for provided version <what you typed>`。以前钩子会以 `cannot perform concat operation between string and nil` 失败（[#14](https://github.com/version-fox/vfox-nodejs/pull/14)）。

## 0.3.0（2024-04-22）

- vfox 能读取 `.nvmrc` 和 `.node-version`：完整的版本号、大版本号和 `lts/<codename>`，见 [nvmrc.md](nvmrc.md)（[#7](https://github.com/version-fox/vfox-nodejs/pull/7)）。

## 0.2.x（2024-04）

- 0.2.2（2024-04-09）：`vfox use nodejs@20` 和 `nodejs@20.11` 能找到已安装的版本（[#6](https://github.com/version-fox/vfox-nodejs/pull/6)）。
- 0.2.1（2024-04-08）：`vfox install nodejs@20` 和 `nodejs@20.11` 会安装这条版本线上最新的版本。它们以前会失败（[#5](https://github.com/version-fox/vfox-nodejs/pull/5)）。
- 0.2.0（2024-04-07）：`VFOX_NODEJS_MIRROR`，见 [mirror.md](mirror.md)（[#3](https://github.com/version-fox/vfox-nodejs/issues/3)）。Apple silicon 上安装 Node.js 16 及更早版本时使用 amd64 的包（[#4](https://github.com/version-fox/vfox-nodejs/issues/4)）。

## 0.0.x 和 0.1.x（2024-03 和 2024-04）

- 0.0.1（2024-03-26）是第一个发布版。`vfox search nodejs` 在其中会失败，从 0.0.5 起可用。安装完整的版本号，并检查它的 SHA-256 校验和，从一开始就可以。
- 0.1.1（2024-04-01）为 `vfox use` 增加了对版本线的查找，这个查找到 0.2.2 之前什么也找不到。
