# `.nvmrc` 和 `.node-version`

[中文](nvmrc.md) | [English](../nvmrc.md)

vfox 可以通过这个插件，读取 [nvm](https://github.com/nvm-sh/nvm) 的项目文件 `.nvmrc`，以及 nodenv、fnm 等工具使用的 `.node-version`（插件在 `PLUGIN.legacyFilenames` 里声明了这两个文件）。已经为其中某个工具固定了 Node.js 版本的项目，不需要再为 vfox 另写一个文件：

```text
# .nvmrc
22.23.3
```

## 使用方法

```bash
eval "$(vfox activate bash)"       # 只需配置一次，写进 ~/.bashrc；其他 Shell 见 vfox 的快速入门

vfox install nodejs@22.23.3        # 这些文件不会安装任何东西
cd my-project                      # 里面有上面那个 .nvmrc
node -v                            # v22.23.3
```

vfox 挂载到 Shell 之后，进入目录时会读取这个文件，并选中其中指定的版本，不需要 `vfox use`。挂载由 vfox 自己完成，zsh、fish、PowerShell 等其他 Shell 的挂载方式见它的[快速入门](https://vfox.dev/zh-hans/guides/quick-start.html)。

- 只读取当前目录下的文件。进入项目的子目录就找不到它了，所以 `cd packages/app` 之后会回到全局版本。
- 同一目录里两个文件都有时，`.node-version` 优先。
- 同一目录里的 `.vfox.toml` 或 `.tool-versions`（asdf 的文件）只要写了 `nodejs`，就优先于这两个文件。`vfox use --project` 会写出 `.vfox.toml`。
- 在这个目录里，这个文件还优先于不带 `--project` 的 `vfox use`：下一个提示符就会切回来，而 `vfox current nodejs` 仍然显示会话里选的那个。
- vfox 会在这个目录里创建 `.vfox/sdks/nodejs`，并且不会把 `.vfox/` 加进 `.gitignore`，所以 `git status` 会列出它，需要你自己忽略。
- 版本必须已经安装。没有任何已安装的版本匹配时，这个文件会被忽略，也不会有任何提示。`vfox list nodejs` 可以看到已有哪些。
- `vfox config legacyVersionFile.enable false` 会关闭所有兼容版本文件，对每个插件都有效。默认值是 `true`。

## 由策略决定

文件里的文本能指明什么，取决于 vfox 的设置 `legacyVersionFile.strategy`：

```bash
vfox config legacyVersionFile.strategy latest_installed
```

| 策略 | 文本会怎样处理 |
| --- | --- |
| `specified`（默认） | 文本直接当作版本使用。只有写全的版本号（`22.23.3`）才会选中版本，因为 vfox 查找的是名字与之完全一致的已安装版本。不联网 |
| `latest_installed` | 选中最新的以该文本开头的已安装版本。不联网，只有在没有任何已安装版本匹配时才例外：这时插件会像 `latest_available` 那样去查索引，查到的版本只有已经安装才算数 |
| `latest_available` | 索引里最新的以该文本开头的版本就是结果，只有这个版本已安装时才会选中。在带有兼容版本文件的目录里，每个提示符出现时插件都会下载 `index.json`（约 330 KB） |

项目里的文件写的是 `22`、`lts/jod` 或 `lts/*` 时，选 `latest_installed`；写的是 `22.23.3` 时，保持 `specified`。`latest_available` 每次出现提示符都要联网，在带有兼容版本文件的目录里，提示符要等联网完成才会出现。

## 文件里可以写什么

插件在处理文本之前，会先去掉所有空白，去掉开头的 `v`，把其余部分转成小写，并把 `lts-jod` 改成 `lts/jod`。所以 `v22.23.3`、CRLF 换行的文件，以及版本前后的空白，都没有问题。`lts/jod` 这样的名字，会按 [lts.md](lts.md) 里的表变成它所在版本线的大版本（22）；`latest_available` 除外，它会向索引查询带有这个代号的最新版本。版本号末尾可以用 `x`、`X` 或 `*` 代替不作限定的部分：`22.x`、`22.x.x` 和 `22.*` 都表示 22。

下面是 2026-10-21 在已安装 20.20.2、22.23.3、24.21.0、25.9.0 和 26.12.0 的情况下得到的结果，此时 24.22.0 是最新的 24.x，22.23.3 是最新的 22.x：

| 文件里写 | `specified` | `latest_installed` | `latest_available` |
| --- | --- | --- | --- |
| `22.23.3`、`v22.23.3` | 22.23.3 | 22.23.3 | 22.23.3 |
| `22`、`v22`、`22.x`、`22.*` | 无 | 22.23.3 | 22.23.3 |
| `22.23` | 无 | 22.23.3 | 22.23.3 |
| `lts/jod`、`lts-jod`、`LTS/Jod` | 无 | 22.23.3 | 22.23.3 |
| `lts/krypton` | 无 | 24.21.0 | 无：最新的是 24.22.0，而它没有安装 |
| `lts/*`、`lts` | 无 | 24.21.0 | 无：最新的 LTS 版本是 24.22.0，而它没有安装 |
| `18.20.8` 或任何没有安装的版本 | 无 | 无 | 无 |

`latest_available` 不会回退到较旧的已安装版本。索引里列出的版本比你已安装的更新时，什么都不会选中。想选中已安装的最新版本，请用 `latest_installed`。

`lts` 和 `lts/*` 指最新的 LTS 版本线。在 `specified` 和 `latest_installed` 下，指的是代号表里最高的大版本（撰写本文时为 24）；在 `latest_available` 下，指的是索引里带有任意代号的最新版本。代号表，以及 Node.js 把一条新版本线升为 LTS 时会发生什么，见 [lts.md](lts.md)。

## 不认识的写法

插件认识的写法比 nvm 少。下面这些在任何策略下都什么也选不中：

- 别名：`node`、`stable`、`latest`、`unstable`、`system`。
- `lts/-1` 和 nvm 的其他相对写法，以及不带 `lts/` 的代号（`iron`、`jod`）。
- 版本范围：`>=20`、`^22.0.0`、`~22.23`，以及 `x` 后面还有数字的写法（`22.x.1`）。
- 注释。单独一行的 `# pin`，或者 `22.23.3 # pin`，会成为文本的一部分，因为读取文本之前已经去掉了所有空白。
- 空文件。

## 前缀怎样匹配

`latest_installed` 和 `latest_available` 把文本与每个版本的开头逐段、按数字比较，取最新的以它开头的版本：

- `22.2` 匹配 22.2.x，不匹配 22.23.3。
- vfox 交给插件的已安装版本是按文本降序排列的，所以 `22.9.0` 排在 `22.23.3` 前面。插件不按这个顺序取：已安装 22.9.0、22.3.0 和 22.23.3 时，`22` 选中 22.23.3，`22.3` 选中 22.3.0。`vfox use nodejs@22` 同样按数字比较。

## 没有生效

版本没有切换时：

- vfox 没有挂载到当前的 Shell。`eval "$(vfox activate bash)"` 要在当前 Shell 里执行过，只在别处执行过不算。
- 当前目录是文件所在目录的子目录。
- 版本没有安装，用 `vfox install nodejs@22.23.3` 安装。
- 策略是 `specified`，而文件里写的是 `22` 或 `lts/jod`。
- 在 `latest_available` 下，已经发布了比已安装版本更新的版本。
- 被 `.vfox.toml` 或 `.tool-versions` 挡住了，或者 `legacyVersionFile.enable` 是 `false`。
- 文本属于上面列出的不认识的写法，或者里面带有注释。

`vfox --debug env -s bash` 会打印插件返回了什么，以及 vfox 怎样处理它：

```text
Parsing legacy file /home/me/project/.nvmrc
CallFunction: ParseLegacyFile
Found nodejs@22
SDK nodejs@22 from project scope not installed, trying lower-priority config
```

## 与 nvm 的区别

`nvm install` 会安装 `.nvmrc` 里指明的版本，不带参数的 `nvm use` 会读取它。vfox 只在已安装的版本里选择，安装要用 `vfox install nodejs@<version>`。`.nvmrc` 里的一行不一定是 `vfox install` 接受的写法：`22.23.3` 可以，`22` 可以，`lts/jod` 不行（见 [lts.md](lts.md#安装一条-lts-版本线)）。
