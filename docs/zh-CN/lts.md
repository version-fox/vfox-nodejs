# LTS 版本

[中文](lts.md) | [English](../lts.md)

Node.js 中编号为偶数的大版本会成为 **LTS**（长期支持）版本线：奇数版本结束生命周期很久之后，它们仍会继续收到修复，所以大多数生产环境都会固定使用某条 LTS 版本线。每条 LTS 版本线都有一个代号（4 是 `argon`，6 是 `boron`，……，24 是 `krypton`）。

## 安装一条 LTS 版本线

插件没有给 `vfox install` 提供 `lts` 别名：`vfox install nodejs@lts` 会失败，报 `version not found for provided version lts`。请改为写版本线，这样会安装这条版本线的最新版本：

```bash
vfox install nodejs@24
```

`vfox search nodejs` 会用 `(LTS)` 标出 LTS 版本线的版本，所以最新的 LTS 版本就是第一个带这个标记的行：

```text
$ vfox search nodejs | grep -m1 '(LTS)'
 - 24.22.0 (LTS) [npm 11.19.1]
```

用 `vfox install nodejs@24.22.0` 安装它，或者用 `nodejs@24` 跟随这条版本线。这个标记来自版本索引的 `lts` 字段，Node.js 从一条版本线进入长期支持的那天起设置它：24.11.0 是 Krypton 中第一个带它的版本，24.10.0 及更早的版本没有。`lts/<codename>` 只在 `.nvmrc` 和 `.node-version` 文件里才会被识别，见 [nvmrc.md](nvmrc.md)。

## 插件认识哪些代号

在 `latest_available` 策略下，插件从版本索引里动态获取 LTS 代号（`index.json` 在每个版本的 `lts` 字段里写明了代号），所以插件发布之后才出现的代号，在这个策略下仍然有效。其他情况下，以及离线时的回退，用的是 `hooks/parse_legacy_file.lua` 里硬编码的表，因为 `specified` 和 `latest_installed` 必须在没有网络的情况下完成解析。“首个 LTS 版本”和“最后一个版本”取自 2026-10-21 的索引，Krypton 仍在发布新版本：

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
| jod | 22 | 22.11.0 | 22.23.3 |
| krypton | 24 | 24.11.0 | 24.22.0 |

## Node.js 升级版本线时

编号为偶数的版本线每年十月进入长期支持，并在那时得到代号。根据[发布计划](https://github.com/nodejs/Release)，Node.js 26 定于 2026-10-28 进入长期支持，目前还没有公布代号。

- 在 `latest_available` 下，新代号一出现在索引里，插件当天就能找到。这时 `lts` 和 `lts/*` 指的是新版本线的最新版本。
- 在 `specified` 和 `latest_installed` 下由上面的表决定，而这张表只有随着插件发布新版本才会改变。在那之前，`lts/<new codename>` 什么都选不中，`lts` 和 `lts/*` 仍然指表里最高的版本线，撰写本文时为 24。
- `vfox search` 里的 `(LTS)` 跟随索引，所以会立刻变化。

这张表在 `hooks/parse_legacy_file.lua` 里，见 [development.md](development.md#nodejs-把一条版本线升为-lts-时)。

## 示例

假设有一个 `.nvmrc`（`.node-version` 同理），并且已安装 `22.23.3` 和 `24.21.0`。示例 1 到 4 都在 `latest_installed` 策略下运行，这个策略由示例 1 设置，各个策略见 [nvmrc.md](nvmrc.md#由策略决定)：

```sh
# 1. LTS 代号 -> 大版本，再由策略选出具体的版本。
$ cat .nvmrc
lts/jod
$ vfox config legacyVersionFile.strategy latest_installed
$ cd <dir-with-.nvmrc> && eval "$(vfox activate bash)" && eval "$(vfox env -s bash)" && node --version
v22.23.3
```

```sh
# 2. 单独的 `lts`（或 `lts/*`）表示“映射表里最高的大版本”，
# 撰写本文时为 24。
$ printf 'lts\n' > .nvmrc
$ cd <dir-with-.nvmrc> && eval "$(vfox activate bash)" && eval "$(vfox env -s bash)" && node --version
v24.21.0
```

```sh
# 3. 写全版本号时，完全不经过代号表。
$ printf '22.23.3\n' > .nvmrc
$ cd <dir-with-.nvmrc> && eval "$(vfox activate bash)" && eval "$(vfox env -s bash)" && node --version
v22.23.3
```

```sh
# 4. 当前的 LTS 版本线也是同样的做法。
$ printf 'lts/krypton\n' > .nvmrc
$ cd <dir-with-.nvmrc> && eval "$(vfox activate bash)" && eval "$(vfox env -s bash)" && node --version
v24.21.0
```

```sh
# 5. 在 latest_available 下会查询索引，所以连比上面的表更新的代号
# 也能解析（离线时回退到这张表）。
$ vfox config legacyVersionFile.strategy latest_available
$ printf 'lts/<future-codename>\n' > .nvmrc
$ cd <dir-with-.nvmrc> && eval "$(vfox activate bash)" && eval "$(vfox env -s bash)" && node --version
v<newest release carrying that codename>
$ vfox config legacyVersionFile.strategy specified
```

示例 1 是怎样一步步解析出来的（`latest_installed`）：

```
.nvmrc "lts/jod" --resolve_version--> "22" --prefix-match installed--> "22.23.3"
```
