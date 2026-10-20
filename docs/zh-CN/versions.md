# 版本与命名

[中文](versions.md) | [English](../versions.md)

`vfox install` 和 `vfox use` 里 `nodejs@` 后面的部分，是 Node.js 的版本号，或者版本号的开头部分：

```bash
vfox install nodejs@24.21.0    # 恰好是这个版本
vfox install nodejs@24.21      # 最新的 24.21.x
vfox install nodejs@24         # 最新的 24.x
vfox install nodejs@latest     # 所有版本线中最新的版本
```

这里没有 `lts`、`lts/iron` 或 `stable` 这样的名字。要装处于长期支持的版本线，请写明版本线（`nodejs@24`），见 [lts.md](lts.md)。`.nvmrc` 文件则能识别 `lts/<codename>`，见 [nvmrc.md](nvmrc.md)。

## 安装

`vfox install` 先问插件哪个包符合要求，再由 vfox 下载、校验并解压。2026-10-21 当天的结果如下：

| 输入 | 安装的版本 |
| --- | --- |
| `24.21.0` | `24.21.0` |
| `v24.21.0` | `24.21.0`，vfox 会去掉 `v` |
| `24.21` | `24.21.0`，即最新的 24.21.x |
| `24` | `24.22.0`，即最新的 24.x |
| `latest` | `26.12.0`，即索引里最新的版本。vfox 会先打印 `Using latest version: 26.12.0` |

- “最新”指索引里列出的所有版本中数字最大的那个，不论是否属于 LTS。尚未进入长期支持的版本线（比如现在的 26）可以比最新的 LTS 版本线更新，所以 `latest` 并不等于 LTS 版本。
- `24` 和 `24.21` 是在索引里查找的，不是在已安装的版本里查找。`vfox install nodejs@24` 会装上比你已有的更新的 24.x；已经是最新版本时，则打印 `nodejs@24.22.0 is already installed`。
- 索引里只列出由三段数字组成的版本，别的一概没有：没有 `-rc` 构建、每日构建，也没有四段数字的版本号。这些写法最终都会报 `version not found for provided version ...`。
- 不存在的版本号（`24.99.0`）最终会报 `get checksum failed: HTTP 404 from ...`，因为 nodejs.org 上没有对应的目录（未发布：0.5.2 省略了 `failed` 后面的部分）。版本存在但没有你所在平台的包时，最终会报 `Node.js package ... is not listed in ...`。见 [troubleshooting.md](troubleshooting.md#插件给出的提示) 和 [platforms.md](platforms.md)。
- 每次下载都会对照该版本 `SHASUMS256.txt` 里的 SHA-256 校验和进行检查。vfox 会打印 `Verifying checksum <sum>...`，校验和不一致时会报 `checksum error` 并停止，什么也不会安装。
- 安装时如果发现同名的版本已经存在，就不会下载任何东西。

镜像改变的是文件的来源，不改变名字的含义，见 [mirror.md](mirror.md)。

## 安装后的版本名

安装后的版本名就是版本号：不带 `v`，不带平台，也不带其他变体。`vfox list nodejs` 显示这些名字，正在使用的那个带有标记。vfox 按字符串排序，大的在前，所以 `22.9.0` 排在 `22.23.3` 前面：

```text
$ vfox list nodejs
-> 26.12.0
-> 24.21.0 <— current
-> 22.9.0
-> 22.23.3
-> 20.20.2
```

`vfox uninstall` 需要写完整的名字：

```bash
vfox uninstall nodejs@22.23.3
```

`vfox uninstall nodejs@22` 和 `nodejs@22.23` 会提示 `is not installed`。卸载正在使用的版本时，vfox 会切换到 `vfox list nodejs` 里剩下的第一项，并给出提示（`Auto switch to the other version.`），那可能是另一条版本线。

文件位于 `~/.vfox/cache/nodejs/v-<version>/nodejs-<version>/`，见 [troubleshooting.md](troubleshooting.md#nodejs-在哪里)。

## 使用

`vfox use` 把你输入的内容映射到已安装的版本，不会下载任何东西：

| 输入 | 选中 |
| --- | --- |
| `24.21.0`、`v24.21.0` | 这个版本 |
| `24.21` | 已安装的最新的 24.21.x |
| `24` | 已安装的最新的 24.x |
| 其他任何写法，比如 `lts` 或 `99` | 什么也选不中：`nodejs@lts is not installed` |

“最新”按数字比较，所以装了 22.3.0、22.9.0 和 22.23.3 时，`nodejs@22` 选中 22.23.3，`nodejs@22.3` 选中 22.3.0。简写必须能匹配到某个已安装的版本：只装了 22.23.3 时，`nodejs@22.2` 什么也选不中，因为没有 22.2.x。

作用域用 `vfox use` 的参数选择：`--global`、`--project`，或者默认的 `--session`。这几种都需要先把 vfox 挂载到 Shell（bash 里是 `eval "$(vfox activate bash)"`）。没有挂载时，`vfox use` 在 Linux 上会报下面的错并停止：

```text
vfox requires hook support. Please ensure vfox is properly initialized with 'vfox activate'
```

`--project` 会写出一个 `.vfox.toml`，里面记录的是安装后的版本名：

```toml
[tools]
nodejs = "22.23.3"
```

同一目录里的 `.nvmrc` 或 `.node-version` 也会被读取，见 [nvmrc.md](nvmrc.md)。`PATH` 里有另一个 `node` 排在 vfox 前面时，`vfox use` 会打印一条提示，见 [pnpm.md](pnpm.md)。

## 搜索

```bash
vfox search nodejs
```

每一行都是可以接在 `nodejs@` 后面的名字，新的在前。名字后面依次是：`(LTS)`（属于长期支持版本线的版本才有）、这个版本自带的 npm，以及 `(installed)`：

```text
$ vfox search nodejs
Available versions:
 - 26.12.0 [npm 11.20.0] (installed)
 - 26.11.1 [npm 11.20.0]
 ...
 - 24.22.0 (LTS) [npm 11.19.1]
 - 24.21.0 (LTS) [npm 11.19.0] (installed)
 ...
 - 0.6.3 [npm 1.1.0-alpha-2]
 - 0.6.2 [npm ]
```

- 列表就是 nodejs.org（或你的[镜像](mirror.md)）的 `index.json`：2026-10-21 共有 872 个版本，从 0.1.14 到 26.12.0。npm 从 0.6.3 起才有，更早的版本是空的。
- `(LTS)` 对应索引里的 `lts` 字段，Node.js 从一条版本线进入长期支持的那天起才会设置它。Krypton 版本线里第一个带有该字段的版本是 24.11.0，24.10.0 及更早的版本没有。见 [lts.md](lts.md)。
- 插件会忽略参数：`vfox search nodejs 24` 打印的仍是同一份完整的列表。要过滤的话，用管道，比如 `vfox search nodejs | grep '^ - 24\.'`。在管道里，vfox 只打印输出。
- 在交互式终端里，vfox 改为显示一个选择列表（`Please select a version of nodejs to install [type to search]`）：方向键移动，输入内容过滤，回车确认。
- 列表包含所有版本，不论你的平台有没有对应的包，见 [platforms.md](platforms.md)。
- vfox 会把列表缓存 12 小时（`vfox config cache.availableHookDuration`），所以一分钟前刚发布的版本可能还看不到。`vfox config cache.availableHookDuration 0` 会关闭缓存。
- 取不到索引时，搜索会失败并报 `Failed to fetch Node.js versions: ...`，而不是什么也不列出，见 [troubleshooting.md](troubleshooting.md#网络)。

`vfox install nodejs 24` 装的并不是 24：用空格分隔的参数表示多个 SDK，它会停下来并报 `install requires specifying a version for nodejs`。请写 `nodejs@24`。
