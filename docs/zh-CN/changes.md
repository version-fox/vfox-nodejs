# 变更记录

[中文](changes.md) | [English](../changes.md)

按发布版本列出用户能感受到的变化。GitHub 的 [Release 页面](https://github.com/version-fox/vfox-nodejs/releases)列出了对应的 PR。

## 0.5.6（2026-11-10）

- 在 vfox 1.1.0 及以后的版本里，从带有 `.nvmrc` 或 `.node-version` 的目录离开、进入完全没有配置的目录时，会切换回全局版本。vfox 从 1.1.0 起自己跟踪版本文件（[version-fox/vfox#745](https://github.com/version-fox/vfox/issues/745)，由 [version-fox/vfox#748](https://github.com/version-fox/vfox/pull/748) 修复），所以每当 vfox 请插件读取这样的文件时，插件不再删除 `env-state.json`，没有任何变化的提示符沿用保存的结果。0.5.5 在带有这类文件的目录里，每个提示符都会重新计算一次，而且离开时不会切换回来。在 vfox 1.1.0 之前的版本里，文件只在 Shell 于它所在的目录里启动时生效。见 [nvmrc.md](nvmrc.md#什么时候读取这个文件)（[#46](https://github.com/version-fox/vfox-nodejs/issues/46)，[#50](https://github.com/version-fox/vfox-nodejs/pull/50)）。

## 0.5.5（2026-11-10）

- 在 vfox 1.1.0 及以后的版本里，遮蔽 vfox 的 `node` 由 vfox 自己报告，并附带插件的提示，不再由插件打印 `Note:`。0.5.4 会在所有 vfox 上从 `PreUse` 打印 `Note: <shadowing node> comes before vfox in PATH, ...`，所以在新 vfox 上，同一个遮蔽会同时打印核心警告和插件的提示。插件现在为 pnpm、mise、asdf、nvm、Homebrew 和 winget 声明 `PLUGIN.shadowHints`（各自的交接命令，以及指向 `docs/pnpm.md` 或 `docs/managers.md` 的链接），只在 1.1.0 之前的 vfox 上保留自己的 `Note:`，老 vfox 会忽略这个新的元数据字段。见 [pnpm.md](pnpm.md)、[managers.md](managers.md)和 [troubleshooting.md](troubleshooting.md)（[#48](https://github.com/version-fox/vfox-nodejs/pull/48)）。
- `vfox link --detect nodejs` 会把本机已有的 Node.js 链进来，不用再下载一份：装着可用 `node` 的 nvm、mise、asdf 和 Homebrew Cellar 目录，Windows 上还有 winget 目录，每个都用二进制自己报出的纯版本号命名。shim、pnpm 的全局运行时和没有版本化家目录的复制会被跳过。见 [managers.md](managers.md)（[#48](https://github.com/version-fox/vfox-nodejs/pull/48)）。

## 0.5.4（2026-11-04）

- `vfox install nodejs@latest` 重新安装最新的版本，`vfox search nodejs` 也不再列出预发布版本。2026-10-29 起，nodejs.org 的索引里最新的一条是 `27.0.0-alpha.0.0.0`。0.5.3 把它排在最前面，所以 `latest` 解析成它，安装以 `version not found for provided version 27.0.0-alpha.0.0.0` 告终。`nodejs@26` 等按编号安装的写法不受影响。现在只列出由三段数字组成的版本。见 [versions.md](versions.md#安装)（[#43](https://github.com/version-fox/vfox-nodejs/pull/43)）。
- 华为云、TUNA、USTC 和北外现在可以用作镜像。0.5.3 把安装包的下载交给 vfox，而 vfox 请求时使用 Go HTTP 客户端的 `User-Agent`，这四个镜像对它返回的是错误页面或者空内容，而不是文件（依次是 HTTP 418、403、204 和 403），安装以 `checksum error` 结束。插件现在让 vfox 下载时使用它自己请求时的 `User-Agent`（vfox 1.0.13 下是 `vfox/1.0.13 vfox-nodejs/0.5.4`），[mirror.md](mirror.md#可用的镜像) 里的所有镜像都能安装 24.21.0。天翼云 `https://mirrors.ctyun.cn/nodejs-release` 也加进了这份列表（[#45](https://github.com/version-fox/vfox-nodejs/pull/45)）。
- 插件从版本索引里学到 LTS 版本线，所以 Node.js 以后再升的版本线，不需要为插件发布新版本。它把学到的内容放在插件旁边的 `.lts-cache` 里。`vfox search`，或者安装 `latest` 或某个大版本时读到索引，以及安装某个确切版本、而这个文件不存在或者已有一天时，它会写这个文件；在 `specified` 和 `latest_installed` 下，`lts/<codename>`、`lts` 和 `lts/*` 读这个文件，不发任何请求。在学到任何内容之前，或者文件无法写入的地方，它使用一张代号表，这张表现在到 Lithium（26）为止：Node.js 26 在 2026-10-28 进入长期支持。0.5.3 只有这张表，而且到 Krypton（24）为止，所以在那里 `latest_installed` 下 `lts/lithium` 什么也选不中，`lts` 和 `lts/*` 选中某个 24.x。见 [lts.md](lts.md#插件认识哪些代号)（[#44](https://github.com/version-fox/vfox-nodejs/pull/44)）。
- UTF-16 的 `.nvmrc` 或 `.node-version`，以及带字节顺序标记的 UTF-8 文件，现在可以读取了。Windows PowerShell 5.1 用 `>` 和 `Out-File` 写出前者，用 `-Encoding UTF8` 写出后者。0.5.3 按原样读取字节，所以没有任何版本能匹配这段文本，而 vfox 不会有任何提示。见 [nvmrc.md](nvmrc.md#文件里可以写什么)（[#44](https://github.com/version-fox/vfox-nodejs/pull/44)）。
- `.nvmrc` 和 `.node-version` 在每个提示符出现在它们所在的目录里时都会读取，所以 `cd` 进去就会切换，改动文件则在下一个提示符生效。0.5.3 在 Shell 于该目录里启动时读取，`cd` 之后不读取，因为 vfox 1.0.13 会保留它为 Shell 第一次算出的结果，并且不跟踪版本文件。现在，每当 vfox 请插件读取这样的文件时，插件就会删除那个结果。从这个目录 `cd` 到完全没有配置的目录时还不会切换回来，而 `.vfox.toml` 一直都会。见 [nvmrc.md](nvmrc.md#什么时候读取这个文件)（[#44](https://github.com/version-fox/vfox-nodejs/pull/44)）。这个缓存是 vfox 的，已经请 vfox 修复（[version-fox/vfox#745](https://github.com/version-fox/vfox/issues/745)，这里用 [#46](https://github.com/version-fox/vfox-nodejs/issues/46) 跟踪）。
- 文档新增了一页使用场景：nvm-sh/nvm 与 vfox 的命令对照、从零开始使用 Windows PowerShell 5.1、全团队使用同一个 Node.js、一个 Shell 里的多个项目、`vfox exec`、镜像和编辑器。见 [scenarios.md](scenarios.md)（[#44](https://github.com/version-fox/vfox-nodejs/pull/44)）。

## 0.5.3（2026-10-20）

- 32 位 ARM 的 Linux 会安装 `linux-armv7l` 包，Node.js 到 23.11.1 为止都发布了这个包：`vfox install nodejs@20` 在那里可以用。vfox 的 `armv7` 构建报告的是 `arm`，而 0.5.2 请求 `linux-arm`，这个包并不存在，所以 32 位 ARM 上的每次安装都以 `Node.js package node-v20.19.5-linux-arm.tar.gz is not listed in ...` 告终。从 24 起没有这个包了，ARMv6 的包也永远不会被选中。见 [platforms.md](platforms.md#不支持的情况)（[#41](https://github.com/version-fox/vfox-nodejs/pull/41)）。
- 在 musl 上，解压出来的 `node` 因缺少库而无法运行时，安装会中止。解压之后，插件会运行一次 `node --version`，由动态加载器指出缺少什么。26.8.0 及以后的 musl 包需要 `libatomic`，原版 Alpine 没有它：安装会以 ``Node.js (musl build) requires the libatomic system package, which was not found on this system. Install it with `apk add libatomic` and reinstall.`` 结束，不会登记任何内容。0.5.2 只检查 `libstdc++`，所以安装能成功，而 `node` 会报 `Error loading shared library libatomic.so.1`。关于 `libstdc++` 的提示同样会给出命令，0.5.2 的提示则是 `It is normally installed automatically`。见 [musl.md](musl.md#依赖的系统库)（[#41](https://github.com/version-fox/vfox-nodejs/pull/41)）。
- 在 `legacyVersionFile.strategy` 为 `latest_installed` 和 `latest_available` 时，`.nvmrc` 和 `.node-version` 按版本号的数字匹配版本。已安装 22.9.0 和 22.23.3 时，`22` 选中 22.23.3，而 0.5.2 选中 22.9.0，因为 vfox 是按文本排列已安装版本的。`22.2` 不再匹配 22.23.3。`22.x`、`22.x.x` 和 `22.*` 都表示 22，0.5.2 对 `22.x` 什么也选不中。只会去掉开头的 `v`，所以代号里带 `v` 的 `lts/<codename>` 也能用。不是版本号的文本（`node`、`(`、`22[`）不做处理，0.5.2 对它们会报 `unfinished capture at EOS`，而 vfox 把这个错误藏了起来。见 [nvmrc.md](nvmrc.md#前缀怎样匹配)（[#41](https://github.com/version-fox/vfox-nodejs/pull/41)）。
- 获取 `SHASUMS256.txt` 的请求失败时会说明原因：`get checksum failed: HTTP 404 from https://nodejs.org/dist/v24.99.0/SHASUMS256.txt`，或者网络错误，比如 `x509: certificate signed by unknown authority`。0.5.2 只打印 `get checksum failed`，没有别的内容。见 [troubleshooting.md](troubleshooting.md#插件给出的提示)（[#41](https://github.com/version-fox/vfox-nodejs/pull/41)）。
- `VFOX_NODEJS_MIRROR` 的结尾可以有多个斜杠。0.5.2 只去掉一个（[#41](https://github.com/version-fox/vfox-nodejs/pull/41)）。
- 文档新增了版本与命名、平台、`.nvmrc` 和 `.node-version`、npm、问题排查、开发和变更记录各页，并有了中文版，见 [README_CN.md](../../README_CN.md)（[#41](https://github.com/version-fox/vfox-nodejs/pull/41)）。
- Windows 的 E2E 套件改为从宿主通过 `tests/e2e/windows/run.ps1` 运行，取代了 Docker Compose runner。脚本把 PowerShell、PortableGit 和 Go 取到一个缓存里，每个组合容器都以只读方式把它挂载到 `C:\tools`，所以不再有镜像去运行 PowerShell 的 MSI 和 Git 的安装程序，CI 也会同时启动所有 Windows 组合。见 [e2e.md](e2e.md#windows-11)（[#40](https://github.com/version-fox/vfox-nodejs/pull/40)）。

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
