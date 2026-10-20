# vfox-nodejs

[中文](README_CN.md) | [English](README.md)

[vfox](https://vfox.dev/) 的 Node.js 插件。

它安装 [nodejs.org](https://nodejs.org/dist/) 或其[镜像](docs/zh-CN/mirror.md)上发布的 Node.js 版本压缩包，并对照一同发布的 SHA-256 校验和检查每次下载。每个版本都自带自己的 npm。在 Alpine、OpenWrt 和其他 musl 系统上，安装的是 musl 构建。vfox 通过它读取 `.nvmrc` 和 `.node-version`。

## 安装

先安装 [vfox](https://github.com/version-fox/vfox)，然后执行下面的命令安装插件：

```bash
vfox add nodejs
```

要让 `node` 出现在 `PATH` 里，需要先把 vfox 挂载到 Shell，见 vfox 的[快速入门](https://vfox.dev/zh-hans/guides/quick-start.html)。

### 示例

```bash
vfox add nodejs
vfox install nodejs@24
vfox use --global nodejs@24
```

可以用下面的命令验证：

```bash
node -v
```

`vfox search nodejs` 会列出每个版本及其自带的 npm，属于 LTS 版本线的版本带有标记。在交互式终端里可以从中选一个。

### 示例：Ubuntu 26.04

```bash
vfox add nodejs
vfox install nodejs@26.11.1
sudo apt install --assume-yes libatomic1
vfox use --global nodejs@26.11.1
```

注意：`libatomic1` 这一步是为了绕开 Node.js 上游的一个打包缺陷（[nodejs/node#60790](https://github.com/nodejs/node/issues/60790)，目前仍未关闭）：Node 25 及以上版本会链接 `libatomic.so.1`，而原版 Debian/Ubuntu 镜像不自带这个库。系统库由用户自己负责，插件不会安装它们。

### 示例：Alpine / musl

```bash
apk add bash libstdc++ libatomic
vfox add nodejs
vfox install nodejs@24
vfox use --global nodejs@24
```

Node.js 的 musl 构建需要 `libstdc++`，26.8.0 及以后的构建还需要 `libatomic`。原版 Alpine 镜像两者都没有，而插件不会安装系统库。安装会中止，并给出一条提示，写明缺少哪个包以及安装它的命令（`apk add libatomic`；OpenWrt 把 `libstdc++` 称为 `libstdcpp` 包）。musl 构建只提供 x64 和 arm64。musl 的详细情况（OpenWrt、压缩包对照表、镜像回退、哪些版本有构建）见 [docs/zh-CN/musl.md](docs/zh-CN/musl.md)。

## 版本与命名

版本就是版本号：`24.21.0`，也可以只写开头的部分，如 `24.21` 和 `24`，它们安装对应版本线的最新版本。`latest` 是所有版本线中最新的版本，不论是否属于 LTS。这里没有 `lts` 别名，请写明版本线（`nodejs@24`）。安装后的版本名就是版本号 `24.21.0`，`vfox uninstall` 需要写完整。`vfox use` 和 `vfox search` 怎样处理这些写法，详见 [docs/zh-CN/versions.md](docs/zh-CN/versions.md)。

## 平台

Node.js 为 Linux（x64、arm64、ppc64le、s390x）、macOS（x64 和 arm64）和 Windows（x64、arm64，以及到 22.x 为止的 x86）发布包。并不是每个版本都有上面所有的包：Windows on ARM 从 19.9.0 起，Linux arm64 从 4.0.0 起，Apple silicon 从 16.0.0 起（更早的版本在 Rosetta 2 下安装 x64 的包）。32 位 ARM Linux 到 23.11.1 为止有包。不支持 riscv64 和 loong64。不论你的平台是什么，`vfox search` 都会列出所有版本。表格见 [docs/zh-CN/platforms.md](docs/zh-CN/platforms.md)。

## npm 与全局包

用 `npm install -g` 安装的包属于当时正在使用的那个 Node.js 版本，其他版本里没有它们。Node.js 25 及以后的版本不自带 Corepack。见 [docs/zh-CN/npm.md](docs/zh-CN/npm.md)。

## 镜像

设置 `VFOX_NODEJS_MIRROR` 即可使用 `nodejs.org/dist` 的镜像，例如 `https://npmmirror.com/mirrors/node`。详细说明和检查过的镜像见 [docs/zh-CN/mirror.md](docs/zh-CN/mirror.md)。

## `.nvmrc` 和 `.node-version`

进入目录时，vfox 会读取这些文件，并选中其中指定的版本（前提是已经安装）。文件里能写什么取决于 vfox 的 `legacyVersionFile.strategy`：默认值 `specified` 下，只有完整的版本号才能选中某个版本。详见 [docs/zh-CN/nvmrc.md](docs/zh-CN/nvmrc.md)。

## LTS

LTS 版本线有哪些、怎样安装其中一条，以及 `lts/<codename>` 如何解析，见 [docs/zh-CN/lts.md](docs/zh-CN/lts.md)。

## pnpm

pnpm 作为包管理器，可以和这个插件并存。不过 pnpm 自己安装的 `node` 可能遮蔽 vfox 的。见 [docs/zh-CN/pnpm.md](docs/zh-CN/pnpm.md)。

## 问题排查

插件打印的各种提示、代理设置，以及 Node.js 的位置，见 [docs/zh-CN/troubleshooting.md](docs/zh-CN/troubleshooting.md)。

## 从源码安装

详见 [docs/zh-CN/source-build.md](docs/zh-CN/source-build.md)。

## 开发

插件怎样工作、怎样修改，见 [docs/zh-CN/development.md](docs/zh-CN/development.md)；容器测试见 [docs/zh-CN/e2e.md](docs/zh-CN/e2e.md)；每个版本改了什么，见 [docs/zh-CN/changes.md](docs/zh-CN/changes.md)。

## 发布这个插件

维护者在默认分支上执行 **Actions → Plugin → Run workflow**，填入不带 `v` 前缀的稳定版插件版本号即可发布。共享工作流会更新 `metadata.lua`，创建版本提交和标签，并把 ZIP 包和 manifest 发布到本仓库；不需要在本地打标签，也不需要额外的发布令牌。PR 只运行检查，PR 标题不再触发发布。

仍然支持直接推送版本标签来发布，前提是 `PLUGIN.version` 已经与标签一致。发布失败时，重新运行失败的那个作业即可接着发布。

工作流引用的是共享的 `@v1` 发布工具，升级这个工具不会发布本插件。包的约定和首次接入的要求，见[共享工作流的文档](https://github.com/version-fox/plugin-manifest-action)。

## 致谢

- [Node.js](https://nodejs.org/)，插件安装用的版本压缩包、校验和与版本索引都来自它
- [Node.js Unofficial Builds](https://github.com/nodejs/unofficial-builds)，nodejs.org 没有的 musl 构建来自这里
