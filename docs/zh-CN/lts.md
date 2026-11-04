# LTS 版本

[中文](lts.md) | [English](../lts.md)

Node.js 中编号为偶数的大版本会成为 **LTS**（长期支持）版本线：奇数版本结束生命周期很久之后，它们仍会继续收到修复，所以大多数生产环境都会固定使用某条 LTS 版本线。每条 LTS 版本线都有一个代号（4 是 `argon`，6 是 `boron`，……，26 是 `lithium`）。

## 安装一条 LTS 版本线

插件没有给 `vfox install` 提供 `lts` 别名：`vfox install nodejs@lts` 会失败，报 `version not found for provided version lts`。请改为写版本线，这样会安装这条版本线的最新版本：

```bash
vfox install nodejs@24
```

`vfox search nodejs` 会用 `(LTS)` 标出 LTS 版本线的版本，所以最新的 LTS 版本就是第一个带这个标记的行（2026-11-03 的结果）：

```text
$ vfox search nodejs | grep -m1 '(LTS)'
 - 26.13.0 (LTS) [npm 11.20.0]
```

用 `vfox install nodejs@26.13.0` 安装它，或者用 `nodejs@26` 跟随这条版本线。这个标记来自版本索引的 `lts` 字段，Node.js 从一条版本线进入长期支持的那天起设置它：24.11.0 是 Krypton 中第一个带它的版本，24.10.0 及更早的版本没有。`lts/<codename>` 只在 `.nvmrc` 和 `.node-version` 文件里才会被识别，见 [nvmrc.md](nvmrc.md)。

## 插件认识哪些代号

`index.json` 在每个版本的 `lts` 字段里写明了 LTS 版本线的代号（`"lts": "Lithium"`，不在长期支持内的版本是 `false`）。插件从那里读取代号，而不是靠维护者手工维护的一份清单：

- 在 `latest_available` 策略下，插件读取文件时向索引查询，也就是带有这个文件的目录里每个提示符都查一次，所以插件发布之后才出现的代号，当天就能用。
- 在 `specified` 和 `latest_installed` 下，插件同样在每个提示符运行，不能每次都去取索引。它使用上一次拿到索引时学到的内容：`vfox search`，或者安装 `latest` 或某个大版本（比如 `nodejs@26`），向它要版本列表时（vfox 会把答案保留一段时间，所以不是每次搜索都会这样），以及安装某个版本、而这个文件不存在或者已有一天的时候。它把学到的内容放在插件旁边的 `.lts-cache` 里，vfox 自己的 `.available.cache` 也在那里。删掉这个文件就等于让它忘掉，下一次安装时会重新学到。
- 在学到任何内容之前，或者文件无法写入的地方，它使用下面的表。这张表只是个起点：表里没有的版本线，插件一拿到索引就会学到。

“首个 LTS 版本”和“最后一个版本”取自 2026-11-03 的索引，Jod、Krypton 和 Lithium 仍在发布新版本：

| 代号 | 大版本 | 首个 LTS 版本 | 最后一个版本 |
| --- | --- | --- | --- |
| argon | 4 | 4.2.0 | 4.9.1 |
| boron | 6 | 6.9.0 | 6.17.1 |
| carbon | 8 | 8.9.0 | 8.17.0 |
| dubnium | 10 | 10.13.0 | 10.24.1 |
| erbium | 12 | 12.13.0 | 12.22.12 |
| fermium | 14 | 14.15.0 | 14.21.3 |
| gallium | 16 | 16.13.0 | 16.20.2 |
| hydrogen | 18 | 18.12.0 | 18.20.8 |
| iron | 20 | 20.9.0 | 20.20.2 |
| jod | 22 | 22.11.0 | 22.23.4 |
| krypton | 24 | 24.11.0 | 24.22.2 |
| lithium | 26 | 26.13.0 | 26.13.0 |

## Node.js 升级版本线时

编号为偶数的版本线每年十月进入长期支持，并在那时得到代号。Node.js 26 在 2026-10-28 就是这样，代号是 Lithium：26.13.0 是索引里第一个带 `lts` 标记的版本。升级版本线在实践中是这样的：

- 在 `latest_available` 下，新代号一出现在索引里，插件当天就能找到。这时 `lts` 和 `lts/*` 指的是新版本线的最新版本，`lts/lithium` 在那里当天就能用，0.5.3 也一样。
- 在 `specified` 和 `latest_installed` 下，插件从升级之后第一次拿到索引起就认识这条版本线：也就是把新版本线带给你的那次 `vfox search` 或者安装。`latest_installed` 在没有安装这条版本线的任何版本之前什么也选不中，所以这已经够早了。在那之前，`lts/<new codename>` 什么都选不中，`lts` 和 `lts/*` 指的是插件认识的最新的版本线。
- `vfox search` 里的 `(LTS)` 跟随索引，所以会立刻变化。

未发布：0.5.3 只有那张表，没有这个文件。这张表发布时 Lithium 还没有出现，到 Krypton 为止，所以 2026-11-03，已安装 22.23.4、24.22.2 和 26.13.0 时，它在 `latest_installed` 下 `lts/*` 选中 24.22.2，`lts/lithium` 什么也选不中，要让它认识一条版本线，只有发布插件的新版本。插件如何学到这些，见 [development.md](development.md#插件如何学到-lts-版本线)。

## 示例

假设有一个 `.nvmrc`（`.node-version` 同理），并且已安装 `22.23.4`、`24.21.0` 和 `26.13.0`，情形是 2026-11-03 的。示例 1 到 4 都在 `latest_installed` 策略下运行，这个策略由示例 1 设置，各个策略见 [nvmrc.md](nvmrc.md#由策略决定)：

```sh
# 1. LTS 代号 -> 大版本，再由策略选出具体的版本。
$ cat .nvmrc
lts/jod
$ vfox config legacyVersionFile.strategy latest_installed
$ cd <dir-with-.nvmrc> && eval "$(vfox activate bash)" && eval "$(vfox env -s bash)" && node --version
v22.23.4
```

```sh
# 2. 单独的 `lts`（或 `lts/*`）表示“插件认识的最新的 LTS 版本线”，
# 撰写本文时为 26（未发布：0.5.3 里是 24）。
$ printf 'lts\n' > .nvmrc
$ cd <dir-with-.nvmrc> && eval "$(vfox activate bash)" && eval "$(vfox env -s bash)" && node --version
v26.13.0
```

```sh
# 3. 写全版本号时，不需要代号。
$ printf '22.23.4\n' > .nvmrc
$ cd <dir-with-.nvmrc> && eval "$(vfox activate bash)" && eval "$(vfox env -s bash)" && node --version
v22.23.4
```

```sh
# 4. 当前的 LTS 版本线也是同样的做法，它的上一条也一样。
$ printf 'lts/lithium\n' > .nvmrc
$ cd <dir-with-.nvmrc> && eval "$(vfox activate bash)" && eval "$(vfox env -s bash)" && node --version
v26.13.0
$ printf 'lts/krypton\n' > .nvmrc
$ cd <dir-with-.nvmrc> && eval "$(vfox activate bash)" && eval "$(vfox env -s bash)" && node --version
v24.21.0
```

```sh
# 5. 在 latest_available 下会查询索引，所以连插件还没有学到的代号
# 也能解析（离线时回退到插件学到的内容，再回退到上面的表）。
$ vfox config legacyVersionFile.strategy latest_available
$ printf 'lts/<future-codename>\n' > .nvmrc
$ cd <dir-with-.nvmrc> && eval "$(vfox activate bash)" && eval "$(vfox env -s bash)" && node --version
v<newest release carrying that codename>
$ vfox config legacyVersionFile.strategy specified
```

示例 1 是怎样一步步解析出来的（`latest_installed`）：

```
.nvmrc "lts/jod" --resolve_version--> "22" --prefix-match installed--> "22.23.4"
```
