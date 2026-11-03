# 使用场景

[中文](scenarios.md) | [English](../scenarios.md)

这个插件给 vfox 提供的，正是 [nvm-sh/nvm](https://github.com/nvm-sh/nvm) 给 POSIX Shell 提供的东西：多个 Node.js 版本并存，可以为一个 Shell、一个项目选定其中一个，或者设为默认，并且能读取 `.nvmrc` 文件。nvm-sh/nvm 是一组 Shell 函数。它的 README 列出的是 Unix、macOS 和 WSL 上的 sh、dash、ksh、zsh 和 bash，另外在某些情况下也可以用于 Git Bash 和 Cygwin，其他 Windows 用户则被指向别的工具。PowerShell 不在这个列表里。vfox 是一个程序，为每种 Shell 都提供挂载脚本，所以同样的事情既可以在 Windows 10 和 11 自带的 Windows PowerShell 5.1 里做，也可以在 PowerShell 7、bash、zsh 和 fish 里做。

下面每个场景都写明你想做什么、要输入什么、会看到什么。输出取自 2026-11-03 的 Linux x64，使用 vfox 1.0.13 和 `main` 上的本插件，主目录一律写成 `/home/me`。PowerShell 的命令在 Linux 上的 PowerShell 7.6.9 里运行过，只有 Windows 独有的除外：`Set-ExecutionPolicy`，以及写入用户级环境变量的 `[Environment]::SetEnvironmentVariable`。Windows PowerShell 5.1 本身不在测试套件里（见 [platforms.md](platforms.md#ci-覆盖什么)），所以凡是依据 PowerShell 的文档或 vfox 的源码、而没有在那里实际运行过的内容，场景里都会注明。

## 从 nvm 迁移

| nvm-sh/nvm | vfox | 说明 |
| --- | --- | --- |
| `nvm install 22` | `vfox install nodejs@22` | 最新的 22.x，并对照 SHA-256 校验和检查。见 [versions.md](versions.md) |
| `nvm install node` | `vfox install nodejs@latest` | 未发布：0.5.3 在索引里有预发布版本时会失败，2026-10-29 起就是这样。`nodejs@26` 在哪里都能用 |
| `nvm install --lts`、`nvm install 'lts/*'` | `vfox install nodejs@26` | 没有 `lts` 这个名字，请写明版本线。2026-11-03 时 26 是最新的 LTS 版本线，`vfox search nodejs \| grep -m1 '(LTS)'` 会显示最新的 LTS 版本。见 [lts.md](lts.md) |
| `nvm use 22` | `vfox use nodejs@22` | 只对当前 Shell 有效。`22` 是已安装的最新的 22.x |
| `nvm alias default 22` | `vfox use --global nodejs@22` | 之后的每个新 Shell |
| `nvm ls` | `vfox list nodejs` | |
| `nvm ls-remote` | `vfox search nodejs` | 所有版本及其 npm |
| `nvm current` | `vfox current nodejs` | |
| `nvm exec 22.23.4 node app.js`、`nvm run 22.23.4 app.js` | `vfox exec nodejs@22.23.4 -- node app.js` | 要写完整的版本号。见[下文](#用指定版本运行一条命令) |
| `nvm uninstall 22.23.4` | `vfox uninstall nodejs@22.23.4` | 要写完整的版本号 |
| `nvm install-latest-npm` | `npm install -g npm@latest` | 只对正在使用的版本有效。见 [npm.md](npm.md#更新-npm) |
| `nvm install --reinstall-packages-from=20 22` | 没有 | 全局包属于某个版本。见 [npm.md](npm.md#全局包属于某个版本) |
| `.nvmrc` | `.nvmrc`、`.node-version`、`.vfox.toml` | 见 [nvmrc.md](nvmrc.md) |
| `NVM_NODEJS_ORG_MIRROR` | `VFOX_NODEJS_MIRROR` | 见 [mirror.md](mirror.md) |

和 nvm 教给你的习惯相比，有四点不同：

- `vfox use` 要修改当前 Shell 的环境，只有 vfox 的挂载才能做到（`eval "$(vfox activate bash)"`，或者 [Windows PowerShell 5.1](#windows-powershell-51) 里的那行配置）。没有挂载时，`vfox use` 在 Linux 和 macOS 上会停下来，报 `vfox requires hook support. Please ensure vfox is properly initialized with 'vfox activate'`。`vfox install` 和 `vfox exec` 不需要挂载。
- 没有不带参数的 `nvm use`，也没有会读取 `.nvmrc` 的 `nvm install`。vfox 自己读取 `.nvmrc` 和 `.node-version`，只在已安装的版本里选择，什么也不安装。它什么时候读取，正是[一个 Shell 里的多个项目](#一个-shell-里的多个项目)要说的。
- 没有别名。`lts`、`node` 和 `stable` 都不是 `vfox install` 或 `vfox use` 认识的名字。只有 `.nvmrc` 文件认识 `lts/*` 和 `lts/<codename>`，选中什么还取决于一项设置，见 [nvmrc.md](nvmrc.md#由策略决定)。
- 全局包留在它所属的版本里，vfox 不会把它们复制到下一个版本。

## Windows PowerShell 5.1

你有一台 Windows 电脑和 `powershell.exe`，也就是 Windows PowerShell 5.1，而项目的 README 里写着 `nvm use 22`。在那里 `nvm` 不是一个命令。装好 vfox 之后（它的[快速入门](https://vfox.dev/zh-hans/guides/quick-start.html)列出了 Scoop、winget 和安装程序），四步就能得到同样的工作流程。

1. **让 PowerShell 运行你的配置文件。** 在没有人设置过执行策略的 Windows 客户端上，Windows PowerShell 5.1 用的是 `Restricted`，它也会拦住 `$PROFILE`（[about_Execution_Policies](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_execution_policies)），而挂载就放在配置文件里。`CurrentUser` 范围不需要管理员权限：

   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
   ```

   组策略设置的策略会覆盖它。如果有的话，`Get-ExecutionPolicy -List` 会把它列为 `MachinePolicy` 或 `UserPolicy`。

2. **把 vfox 挂载到 PowerShell。** 这是 vfox 快速入门里的那一行：

   ```powershell
   if (-not (Test-Path -Path $PROFILE)) { New-Item -Type File -Path $PROFILE -Force }; Add-Content -Path $PROFILE -Value 'Invoke-Expression "$(vfox activate pwsh)"'
   ```

   Windows PowerShell 5.1 和 PowerShell 7 读取的是不同的配置文件，所以你用到哪个，就在哪个里面执行一次。`vfox activate pwsh` 打印的挂载脚本（vfox 1.0.13）是普通的 PowerShell：它包装了 `prompt` 函数，设置 `$env:PATH` 之类的环境变量，其中没有任何东西需要 PowerShell 7。

3. **打开一个新窗口**，安装 Node.js：

   ```powershell
   vfox add nodejs
   vfox install nodejs@24
   vfox use --global nodejs@24
   node -v
   ```

4. **按上面的对照表使用它。** `vfox use` 的作用域要明确写出来：`--global`、`--project` 或 `--session`（`-g`、`-p`、`-s`）。

在 Windows 上有哪些不同：

- `vfox use --global` 还会把全局版本的链接写进你这个用户的 `Path`（`HKEY_CURRENT_USER\Environment`），并通知正在运行的程序，同时打印 `Applied global environment variables to Windows registry.`（vfox 1.0.13，来自它的源码）。之后启动的程序，比如 cmd.exe 或者从开始菜单打开的编辑器，不运行任何挂载也能找到同一个 `node`。之前就已经打开的终端和程序，仍然用它们启动时的 `Path`。
- 一切都只属于当前用户。各个版本在 `%USERPROFILE%\.vfox` 里，vfox 用 junction 链接它们，junction 不需要管理员权限，它修改的 `Path` 也是你自己的（同样来自 vfox 的源码）。
- vfox 的文档把不带作用域的 `vfox use` 列为：Windows 上是全局，其他系统上是会话。在没有挂载的 Shell 里没有会话，这时 vfox 不像在 Linux 上那样停下来，而是这样提示：

  ```text
  Warning: The current shell lacks hook support. Switching to global scope automatically.
  ```

  如果 `vfox use --session` 打印了这一行，说明配置文件没有运行：要么是第 1 步的执行策略，要么是挂载那一行写在了另一个 PowerShell 的配置文件里。
- 只有 `PATH` 里的第一个 `node` 会运行。nodejs.org 的安装程序、winget 或 Scoop 装的，或者另一个版本管理器的，都可能排在 vfox 前面。这时 `vfox use` 会打印一条提示，指出是哪一个，并说明它排在 vfox 前面，见 [pnpm.md](pnpm.md)。请卸载另一个。
- Windows PowerShell 5.1 用 `>` 写出的 `.nvmrc` 是 UTF-16。未发布：0.5.3 读不了它，见[下文](#在-windows-powershell-51-里写这个文件)。

## 全团队使用同一个 Node.js

有两个文件可以说明一个项目要哪个版本。按团队里的人怎么用来选。

**所有人都用 vfox：`.vfox.toml`。** `vfox use --project nodejs@22.23.4` 会写出它，修改它也用 `--project`：

```toml
[tools]
nodejs = "22.23.4"
```

仓库里有 `.gitignore` 时，vfox 会把 `.vfox/` 加进去，并提示 `Added '.vfox/' to .gitignore`。没有的话，`git status` 会列出 `.vfox/` 和 `.vfox.toml`，需要你自己忽略 `.vfox/`。把 `.vfox.toml` 提交上去。新来的同事执行下面的命令，装上它指定的版本：

```text
$ vfox install --all -y
Install the following plugins and SDKs:
SDK:
  nodejs@22.23.4
 [1/1] SDK: nodejs@22.23.4 installing...
 [1/1] Installation completed.
Green indicates successful installation, while red indicates installation failure.
SDK:
  nodejs@22.23.4
$ vfox install --all -y
All plugins and SDKs are already installed
```

（转动的进度提示行省略了。不带 `-y` 时 vfox 会先询问，在脚本里则会停下来，报 `Use the -y flag to automatically confirm installation in non-interactive environments`。）

**团队里有一部分人用 nvm-sh/nvm：`.nvmrc`。** 保留他们已有的文件。`.node-version` 的用法相同。vfox 的默认设置下，只有写全的版本号（`22.23.4`）才能选中版本，而 `22` 或 `lts/*` 需要 `latest_installed`，见 [nvmrc.md](nvmrc.md#由策略决定)。vfox 不会安装文件里指明的版本，所以要自己装一次：

```bash
vfox install "nodejs@$(tr -d '[:space:]' < .nvmrc)"
```

```powershell
vfox install "nodejs@$((Get-Content .nvmrc -TotalCount 1).Trim())"
```

`v22.23.4` 可以，因为 vfox 会去掉 `v`；`22` 也可以，它会安装最新的 22.x。`lts/*` 和 `.nvmrc` 里的其他名字则不行：安装会以 `version not found for provided version lts/*` 结束。

每个提示符出现在项目目录里时都会应用 `.nvmrc`，所以 `cd` 进去就会切换。未发布：0.5.3 在 Shell 于该目录里启动时应用它，比如编辑器在这个文件夹里打开的终端；从已经运行的 Shell 里 `cd` 进来则不应用。离开这个目录进入完全没有配置的目录时，两边都不会切换回来，见[一个 Shell 里的多个项目](#一个-shell-里的多个项目)。如果仓库里不该出现 vfox 的文件，`vfox use --project` 仍然可以让你自己得到一个 `.vfox.toml`，它在每个版本里、两个方向上都会切换。把 `.vfox.toml` 和 `.vfox/` 写进 `.git/info/exclude`，再执行 `vfox config gitignore.enable false`（对所有项目生效），这样 vfox 就不会把 `.vfox/` 加进仓库所跟踪的 `.gitignore`。

### 在 Windows PowerShell 5.1 里写这个文件

Windows PowerShell 5.1 的 `>`、`>>` 和 `Out-File` 写出 UTF-16，`-Encoding UTF8` 写出带字节顺序标记的 UTF-8，不带 `-Encoding` 的 `Set-Content` 写的是 ANSI 代码页，对版本号来说就是纯文本（[about_Character_Encoding](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_character_encoding)）。插件在读取文本之前，会先对 UTF-16 解码并去掉标记。未发布：0.5.3 按原样读取字节，所以标记或者 UTF-16 的零字节会成为文本的一部分，没有任何版本能匹配它，而 vfox 对此不会有任何提示。下表给出每种文件开头的字节，以及已安装 22.23.4、使用默认策略时，带有该文件的目录选中了什么：

| 文件开头的字节 | Windows PowerShell 5.1 用什么写出 | 0.5.3 | 未发布 |
| --- | --- | --- | --- |
| `32 32 2e 32 33 2e 34 0d 0a` | `Set-Content .nvmrc 22.23.4 -Encoding ascii`，或者 `Set-Content .nvmrc 22.23.4` | 22.23.4 | 22.23.4 |
| `ef bb bf 32 32 2e ...` | `Set-Content .nvmrc 22.23.4 -Encoding UTF8` | 无 | 22.23.4 |
| `ff fe 32 00 32 00 2e 00 ...` | `'22.23.4' > .nvmrc`、`'22.23.4' \| Out-File .nvmrc` | 无 | 22.23.4 |

这些字节是在 Linux 上写出的，两个版本的插件都在那里试过。Windows PowerShell 写出什么，依据的是微软的文档。PowerShell 7 对上面这些写法都写出不带标记的 UTF-8，每个版本都能读。下面这样写在哪里都可以：

```powershell
Set-Content -Path .nvmrc -Value '22.23.4' -Encoding ascii
```

## 一个 Shell 里的多个项目

一个用 Node.js 18 的旧 API，一个用 24 的 Web 应用，其余的都用全局的 26。在挂载了 vfox 的 Shell 里，在它们之间 `cd`。下面是同一个 Shell 里每一步 `node -v` 的输出，已安装 18.20.8、24.22.2 和 26.13.0，全局版本是 26.13.0（bash 5.3，PowerShell 7.6.9 的结果一致）：

| 步骤 | 0.5.3 | 未发布 |
| --- | --- | --- |
| Shell 在完全没有配置的目录里启动 | v26.13.0 | v26.13.0 |
| `cd` 进 `.nvmrc` 写着 18.20.8 的目录 | v26.13.0 | v18.20.8 |
| `cd` 进 `.node-version` 写着 24.22.2 的目录 | v26.13.0 | v24.22.2 |
| `cd` 进完全没有配置的目录 | v26.13.0 | v24.22.2 |
| `cd` 进 `.vfox.toml` 写着 18.20.8 的目录 | v18.20.8 | v18.20.8 |
| `cd` 进 `.vfox.toml` 写着 24.22.2 的目录 | v24.22.2 | v24.22.2 |
| `cd` 进完全没有配置的目录 | v26.13.0 | v26.13.0 |

- **`.vfox.toml`** 在每次 `cd` 时都会切换，离开去没有配置的目录时也会切回全局版本。每个版本都是这样。
- **`.nvmrc` 和 `.node-version`** 在每个提示符出现在它所在的目录里时都会读取（未发布）。从一个这样的目录 `cd` 到另一个会切换，改动文件则在下一个提示符生效。0.5.3 只在 Shell 于该目录里启动时读取，所以上面的 `cd` 步骤一个都没有切换。
- **离开**带有这类文件的目录、进入完全没有配置的目录时，两边都不会切换回来：Shell 保持它原有的版本，第四步就是这样。在没有东西可读的目录里不会调用插件，vfox 沿用它保存的结果。新开的终端，或者带有 `.vfox.toml` 或它自己的版本文件的目录，会切换。

原因在 [nvmrc.md](nvmrc.md#什么时候读取这个文件)：vfox 把 Shell 第一次计算的结果保存下来，并不跟踪版本文件（vfox 1.0.13），而插件在每次读取版本文件时都会让 vfox 重新计算。所以：

- 对需要在同一个 Shell 里来回切换的项目，`.vfox.toml` 在每个版本里、两个方向上都管用：在每个项目里执行 `vfox use --project nodejs@18.20.8` 这样的命令。
- 在该目录里启动的东西，`.nvmrc` 就够了：编辑器里的终端、同一文件夹里新开的标签页、脚本。这也是本仓库的 Windows E2E 套件为每个目录都新启动一个 Shell 的原因。

## 只在这个窗口里换一个版本

你想用 26 跑一遍测试，其他的都保持原样：

```powershell
vfox use --session nodejs@26
node -v                      # v26.13.0
vfox current nodejs          # -> v26.13.0
```

这个选择从下一个提示符起生效，也就是命令一结束就生效。关掉窗口它就没了，新开的窗口又是全局版本。项目里不会写入任何东西。在 `.vfox.toml` 写了 `nodejs` 的目录里，那个文件优先于 `--session`；`.nvmrc` 则优先于不带 `--project` 的 `vfox use`，见 [nvmrc.md](nvmrc.md#使用方法)。

## 用指定版本运行一条命令

`vfox exec` 用你指定的版本运行一条命令。它不改变任何作用域，不在项目里写文件，也不需要挂载。所以它适合没有挂载的 Shell，比如 Dockerfile、CI 作业或计划任务，vfox 自己的 [FAQ](https://vfox.dev/zh-hans/guides/faq.html) 也推荐这样做。

```bash
vfox exec nodejs@22.23.4 -- node -v           # v22.23.4
vfox exec nodejs@22.23.4 -- npm test
for v in 20.20.2 22.23.4 24.22.2; do vfox exec "nodejs@$v" -- node -v; done
```

```powershell
foreach ($v in '20.20.2', '22.23.4', '24.22.2') { vfox exec "nodejs@$v" -- node -v }
```

三个版本分别打印了 `v20.20.2`、`v22.23.4` 和 `v24.22.2`，在 bash 和 PowerShell 7 里都是这样。需要知道的是：

- **要写完整的版本号。** `vfox exec` 不像 `vfox use` 那样理解 `22`，会失败：

  ```text
  $ vfox exec nodejs@22 -- node -v
  SDK nodejs@22 not found, installing...
  nodejs@22.23.4 is already installed
  failed to get runtime package for nodejs@22: open /home/me/.vfox/cache/nodejs/v-22: no such file or directory
  ```

- **没有安装的版本会先安装**，同样会检查它的 SHA-256 校验和，然后再运行命令。写错的版本号也一样处理，并且在安装失败的地方结束：`nodejs@22.99.0` 会报 `get checksum failed: HTTP 404 from https://nodejs.org/dist/v22.99.0/SHASUMS256.txt`。
- **命令的退出状态就是 vfox 的退出状态。** `vfox exec nodejs@22.23.4 -- node -e "process.exit(3)"` 会打印 `exit status 3`，并以 3 退出，所以测试失败时，循环或者 CI 步骤也会失败。
- **不写版本就用已配置的那个。** `vfox exec nodejs -- node -v` 使用项目、会话和全局作用域里设置的版本。
- **在 Windows 上，请按磁盘上的名字写出程序**，即 `node.exe` 或 `npm.cmd`。`vfox exec` 会在该版本的目录里查找你写的这个名字。这一点来自 vfox 的源码，没有在 Windows 上运行过。

## 跟随版本线或固定版本

Node.js 以同一条版本线的新版本发布修复，比如先是 24.22.1，然后是 24.22.2。一个项目要么停在某个版本上，要么跟随它的版本线。

- **固定。** 在 `.vfox.toml` 或 `.nvmrc` 里写完整的版本号。在有人改这个文件之前，所有人运行的 Node.js 都相同。要升级：`vfox install nodejs@24` 会安装最新的 24.x（已经有的话会提示 `nodejs@24.22.2 is already installed`），再用 `vfox use --project nodejs@24` 把它选定的版本写进 `.vfox.toml`，即 `nodejs = "24.22.2"`。
- **跟随。** 在 `.nvmrc` 里写 `24`，并执行 `vfox config legacyVersionFile.strategy latest_installed`。新的 24.x 在每台安装了它的机器上都会生效，各机器在一段时间内可能不一致。见 [nvmrc.md](nvmrc.md#由策略决定)。

全局包不会移到新版本里。切换之前先列出来，之后再装一遍。每个版本都有自己的全局包：

```text
$ npm ls -g --depth=0
/home/me/.vfox/cache/nodejs/v-22.23.4/nodejs-22.23.4/lib
├── corepack@0.36.0
├── npm@10.9.9
└── semver@7.8.6
$ vfox exec nodejs@24.22.2 -- npm ls -g --depth=0
/home/me/.vfox/cache/nodejs/v-24.22.2/nodejs-24.22.2/lib
├── corepack@0.36.0
└── npm@11.19.1
```

`vfox uninstall nodejs@24.22.1` 会把旧版本连同它的全局包一起删掉。在 Linux 上，一个版本占用 157 到 225 MB（从 18.20.8 到 26.13.0）。`uninstall` 接受哪些名字，见 [versions.md](versions.md#安装后的版本名)。

## 防火墙或公司代理之后

Node.js 压缩包和 npm 包来自两个地方，各有各的设置：

```bash
export VFOX_NODEJS_MIRROR="https://npmmirror.com/mirrors/node"
npm config set registry https://registry.npmmirror.com
```

```powershell
[Environment]::SetEnvironmentVariable("VFOX_NODEJS_MIRROR", "https://npmmirror.com/mirrors/node", "User")
npm config set registry https://registry.npmmirror.com
```

PowerShell 的第一行为你这个用户设置变量，之后打开的终端里才有。你们公司自己提供的镜像，只要目录结构和 `nodejs.org/dist` 一样，用法也相同。代理用 `vfox config proxy.enable true` 和 `vfox config proxy.url <address>` 设置。这两项在 [mirror.md](mirror.md) 和 [troubleshooting.md](troubleshooting.md#网络) 里都有说明。

镜像可能落后于它自己的 `index.json`。2026-11-03，npmmirror 列出了 26.13.0，却没有它的 `SHASUMS256.txt`，所以在那里 `nodejs@26` 失败了，而 `nodejs@24` 正常：

```text
get checksum failed: HTTP 404 from https://npmmirror.com/mirrors/node/v26.13.0/SHASUMS256.txt
```

可以安装它前一个版本（`nodejs@26.12.1`），或者稍后再试。

## 编辑器和 IDE

- 想跟随你的全局选择，就让编辑器或构建工具指向 `~/.vfox/sdks/nodejs/bin/node`，在 Windows 上指向 `%USERPROFILE%\.vfox\sdks\nodejs\node.exe`。要固定某个版本，就用该版本的路径，即 `~/.vfox/cache/nodejs/v-22.23.4/nodejs-22.23.4/bin/node`。见 [npm.md](npm.md#文件在哪里)。
- 从开始菜单启动的编辑器不会运行任何挂载。在 Windows 上，它仍然能通过 `vfox use --global` 写入的 `Path` 找到全局的 `node`，见 [Windows PowerShell 5.1](#windows-powershell-51)。编辑器里的终端会运行你的配置文件，所以挂载、`.vfox.toml`，以及它所打开文件夹里的 `.nvmrc`，在那里都生效。
- 需要固定在某个版本上运行的任务，用 `vfox exec`。在 `.vscode/tasks.json` 里就是 `"command": "vfox"`，加上 `"args": ["x", "nodejs@22.23.4", "--", "node", "${file}"]`。
