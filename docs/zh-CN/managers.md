# 其他 Node.js 管理器

[中文](managers.md) | [English](../managers.md)

pnpm 单独有一页（[pnpm.md](pnpm.md)）：`pnpm runtime set node -g` 会在
`$PNPM_HOME/bin` 里放进第二个 `node`。这一页处理同样的问题，只是换成
vfox 旁边常见的其他管理器：mise、asdf、nvm、Homebrew，以及 winget
（官方安装程序把 `node` 装在和 winget 同一个地方）。

现象总是一样的：`vfox use nodejs@<version>` 打印 `Now using`，
`vfox current nodejs` 也一致，但 `node --version` 打印的是另一个管理器
的版本，因为它的 `node` 排在 `PATH` 里 vfox 的前面（`type -a node`
把它列在最前）。在 vfox 1.1.0 及以后的版本里，vfox 自己给出警告，并
附带插件能认出来的那个管理器的提示；在更早的 vfox 里，插件打印自己的
`Note:`。未发布：0.5.4 会由插件打印 `Note:`；在 vfox 1.1.0 及以后的
版本里，这条警告由 vfox 自己打印，并附带插件的提示。

一个 Shell 里最多让一个管理器管 `node`。最快的是
`vfox link --detect nodejs`（要带 `vfox link` 的 vfox 1.1.0 及以后）：
它直接问插件要本机上真实的安装，选一个链上就行，什么也不会下载或
复制：

```sh
vfox link --detect nodejs
vfox use nodejs@22.14.0
```

它找的是装着可用 `node` 的 nvm、mise、asdf 和 Homebrew Cellar 目录
（包括 Intel 的 `/usr/local/Cellar/node`），Windows 上还有 winget
目录，每个都用二进制自己报出的纯版本号命名，所以 `vfox use 22`
照常用。同一个版本找到两次只链一次，vfox 装过的会跳过。shim、
pnpm 的全局运行时和没有版本化家目录的复制（比如手装的
`/usr/local/bin/node`）一律不报：那些自己手动链，或者按下面的办法
把 `PATH` 交给 vfox。

每个管理器下面有两条路。路 A 是默认做法，把 `PATH` 交给 vfox：对方
的 `node` 不再遮挡，vfox 安装并选用自己的版本。路 B 是把对方的真实
安装目录原地注册给 vfox：

```sh
vfox link nodejs@<name> <dir>
vfox use nodejs@<name>
```

`<dir>` 是插件要的 SDK 目录：Linux 和 macOS 上是装着 `bin/`（里面有
`bin/node`）的那个目录，Windows 上是直接装着 `node.exe` 的目录。
`vfox link` 会检查，不像就拒绝。链真实安装，不要链 shim 目录
（`mise/shims`、`.asdf/shims`、`$PNPM_HOME/bin`）：shim 是按目录切换
版本的代理，pnpm 的 shim 还不带 npm，链过去选不中稳定版本。链过去的
版本还是人家管的：对方升级或清理会动 vfox 底下的文件（`brew upgrade`
换掉 Cellar 目录，mise/asdf 清理安装），vfox 只会提示，
`vfox install --reinstall` 对它无效，`vfox uninstall` 只删链接。链上
的版本用二进制报出的纯版本号命名（`22.14.0`），这样 `vfox use 22`
照常用；vfox 装过的版本就直接 `vfox use` 它，不用再链。名字只能用
字母、数字、`.`、`_`、`+`、`-`，不能叫 `latest`。

## mise

mise 把 shim 放在 `~/.local/share/mise/shims/`（Windows 是
`%LOCALAPPDATA%\mise\shims\`，比如 `...\mise\shims\node.exe`），真正的
安装在 `~/.local/share/mise/installs/node/<version>/`。`mise activate`
把 shim 目录放到 `PATH` 最前面，所以它的 `node` 会胜出。

想让 vfox 接管 `node`，先去掉配置里的请求，再删掉已安装的版本：

```sh
mise unuse -g node
mise uninstall --all node
```

在项目目录里执行 `mise unuse node`，改的是该项目的配置，而不是全局
配置。官方文档：[uninstall](https://mise.jdx.dev/cli/uninstall.html)
和 [unuse](https://mise.jdx.dev/cli/unuse.html)。

也可以链一个真实安装（路 B），不要链 shim 目录。
`vfox link --detect nodejs` 自己会找到这些：

```sh
mise ls node
vfox link nodejs@22.0.0 ~/.local/share/mise/installs/node/22.0.0
vfox use nodejs@22.0.0
```

## asdf

asdf 把 shim 放在 `~/.asdf/shims/`（设置了 `$ASDF_DATA_DIR` 时是
`$ASDF_DATA_DIR/shims`），比如 `~/.asdf/shims/node`，真正的安装在
`~/.asdf/installs/nodejs/<version>/`。shim 目录被加到 `PATH` 最前面，
所以它的 `node` 会胜出。

想让 vfox 接管 `node`，先卸载对应版本，再去掉版本固定：

```sh
asdf uninstall nodejs <version>
```

然后删掉 `./.tool-versions` 和 `~/.tool-versions` 里的 `nodejs ...`
那一行（asdf 0.16 及以后可以用 `asdf unset nodejs`），残留的 shim 用
`asdf reshim nodejs` 清掉。官方文档：
[versions](https://asdf-vm.com/manage/versions.html)（卸载和 shim 在
同一页）。

也可以链一个真实安装（路 B），不要链 shim 目录。
`vfox link --detect nodejs` 自己会找到这些：

```sh
asdf list nodejs
asdf where nodejs 22.13.0
vfox link nodejs@22.13.0 ~/.asdf/installs/nodejs/22.13.0
vfox use nodejs@22.13.0
```

## nvm

nvm（nvm-sh）把版本放在 `~/.nvm/versions/node/v<version>/`，比如
`~/.nvm/versions/node/v22.14.0/bin/node`，`nvm use` 会把那个 `bin/`
放到 `PATH` 最前面，所以它的 `node` 会胜出。用 `nvm which current`
可以确认。

想在当前 Shell 里把 `node` 交给 vfox，同时不删任何已安装版本，执行：

```sh
nvm deactivate
```

安装都还在，以后还能 `nvm use` 切回去。`nvm unload` 更重：它连 `nvm`
命令本身一起卸载，交接请用 `deactivate`。官方文档：
[restoring PATH](https://github.com/nvm-sh/nvm#restoring-path)。

也可以链一个已安装版本（路 B）。
`vfox link --detect nodejs` 自己会找到这些：

```sh
nvm which 22
vfox link nodejs@22.14.0 ~/.nvm/versions/node/v22.14.0
vfox use nodejs@22.14.0
```

## Homebrew

Homebrew 把 `node` 链接到它的 prefix 下：Apple silicon 是
`/opt/homebrew/bin/node`，Intel Mac 是 `/usr/local/bin/node`，Linuxbrew
是 `/home/linuxbrew/.linuxbrew/bin/node`。`PATH` 里排在最前面的那个
`node` 会真正运行（`which -a node`）。

想让 vfox 接管 `node`，同时保留已下载的包，执行：

```sh
brew unlink node
```

`brew link node` 可以恢复。彻底删掉用 `brew uninstall node`。Intel 的
`/usr/local/bin/node` 里没有 `homebrew` 字样，那里 vfox 只会给出通用
警告而没有 Homebrew 提示，处理办法是一样的。官方文档：
[manpage](https://docs.brew.sh/Manpage)（`unlink`、`uninstall`）。

也可以链 Cellar 目录（路 B），但 `brew upgrade` 会换掉它，链接可能悬
空，到时重链。`vfox link --detect nodejs` 自己会找到这些：

```sh
ls $(brew --cellar node)
vfox link nodejs@24.5.0 /opt/homebrew/Cellar/node/24.5.0
vfox use nodejs@24.5.0
```

## winget 和官方安装程序

winget 实际运行的是官方 MSI，整机安装到 `C:\Program Files\nodejs\`，
比如 `C:\Program Files\nodejs\node.exe`，并把这个目录追加到系统
`PATH`。LTS 版本线用的包 id 是 `OpenJS.NodeJS.LTS`，而不是
`OpenJS.NodeJS`。

想让 vfox 接管 `node`，先卸载它（“应用和功能”里卸载走的是同一个卸载
程序）：

```powershell
winget list --name Node.js
winget uninstall -e --id OpenJS.NodeJS
```

装的是 LTS 就把 id 换成 `OpenJS.NodeJS.LTS`。之后重开一个终端，旧的
`PATH` 条目才会消失。官方下载页：
[nodejs.org](https://nodejs.org/en/download)。

也可以链这个目录（路 B），MSI 升级会换掉底下的文件，vfox 只会提示。
`vfox link --detect nodejs` 自己会找到它；手动链：

```powershell
& "C:\Program Files\nodejs\node.exe" --version
vfox link nodejs@22.14.0 "C:\Program Files\nodejs"
vfox use nodejs@22.14.0
```
