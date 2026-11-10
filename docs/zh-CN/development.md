# 开发

[中文](development.md) | [English](../development.md)

## 目录结构

```text
metadata.lua                    插件名、版本、把 .node-version 和 .nvmrc 注册为兼容版本文件，以及遮蔽 node 时的 shadowHints
hooks/available.lua             vfox search：版本索引
hooks/pre_install.lua           vfox install：选择包，以及它的 URL 和校验和
hooks/post_install.lua          musl：node 无法运行时报错，比如缺少 libstdc++ 或 libatomic
hooks/env_keys.lua              PATH：Linux 和 macOS 上是 bin，Windows 上是安装目录
hooks/pre_use.lua               vfox use：把 24 或 24.21 映射到已安装的版本（只在 vfox 1.1.0 之前，vfox 的 node 被遮蔽时给出提示）
hooks/parse_legacy_file.lua     .nvmrc 和 .node-version
lib/util.lua                    镜像 URL 与下载请求头、musl 检测与缺失的库、运行命令、版本比较与匹配、简写、PATH 探测、vfox 版本检查、插件学到的 LTS 版本线
.lts-cache                      不在仓库里：插件学到的 LTS 版本线，写在插件旁边
tests/hooks_test.lua            离线的钩子测试
tests/e2e/                      容器测试，见 e2e.md
Injection.lua                   vfox 注入对象的类型提示，不会被加载
.devcontainer/                  Linux 开发容器，见 e2e.md
.github/workflows/              test、lint、license、e2e 和 publish
```

vfox 加载 `metadata.lua`，命令需要时调用相应的钩子，并向钩子提供 `PLUGIN` 和 `RUNTIME`（`osType`、`archType`、`version`），以及模块 `http` 和 `json`。`osType` 和 `archType` 就是 vfox 二进制的 Go `GOOS` 和 `GOARCH`。如果 vfox 提供了 `RUNTIME.envType`，插件就会读取它（目前还没有哪个 vfox 版本提供），见 [musl.md](musl.md#检测与覆盖)。`lib/util.lua` 用 `require("util")` 加载。

## 一条命令会执行什么

| 你执行 | 调用的钩子 |
| --- | --- |
| `vfox search nodejs` | `Available` |
| `vfox install nodejs@24` | `PreInstall` 返回版本、URL 和校验和，对 `latest` 和版本前缀还会调用 `Available`。vfox 下载、校验并解压，然后调用 `PostInstall` |
| `vfox use nodejs@24` | `PreUse` 返回要选中的已安装版本。`EnvKeys` 提供 `PATH` |
| 已挂载到 Shell，`cd` 进有 `.nvmrc` 的目录 | `ParseLegacyFile`，然后是 `EnvKeys` |
| `vfox uninstall nodejs@24.21.0` | 无，名字必须精确 |

几条容易踩坑的约定：

- `PreInstall` 返回 `version`、`url`、`sha256`、`headers`，有时还有 `note`。`version` 就是安装后的版本名，所以这里必须把版本前缀解析成完整的版本。没有校验和时 vfox 只会警告（`Checksum is not provided`），然后继续下载，所以从 0.5.0 起，包不在 `SHASUMS256.txt` 里时钩子会报错，而不是不返回校验和。钩子用 `print` 打印的 Note 会出现在 vfox 的输出里。
- `headers` 是 vfox 下载 `url` 时带上的请求头，下载由 vfox 发起，不是插件。不写的话，vfox 请求时使用 Go HTTP 客户端的 `User-Agent`，即 `Go-http-client/1.1`，华为云、TUNA、USTC 和北外对它返回的是错误页面，vfox 把它存成安装包，安装就以 `checksum error` 结束。`util.download_headers()` 给出 vfox 为插件自己的请求生成的 `User-Agent`，即 `vfox/<RUNTIME.version> vfox-nodejs/<PLUGIN.version>`，这些镜像都正常响应。vfox 1.0.13 下载时会带上它，这是用一个记录请求的本地服务器确认的。非官方站点也用它。
- `Available` 遇到网络错误或 200 以外的状态码时会抛出错误。从 0.5.0 起它不再返回空列表，那样的结果会被 vfox 缓存。结果在进程存活期间保存在全局变量 `available_result` 里，测试会把它重置。vfox 自己还会把搜索结果缓存 12 小时。
- 对于无法映射的输入，`PreUse` 返回 `{ version = nil }`，vfox 就回答 `is not installed`。它拿到的 `ctx.installedSdks` 是以版本为键的表，而不是数组，所以 `calculate_shorthand` 用 `pairs` 遍历。
- `ParseLegacyFile` 调用 `ctx.getInstalledVersions()` 时不带参数。vfox 1.x 把它绑定成普通的 Go 函数，会拒绝 `ctx:getInstalledVersions()` 多传的那个参数。策略由 `ctx.strategy` 给出。vfox 把已安装的版本按字符串降序传进来，所以 `22.9.0` 排在 `22.23.3` 前面。测试把它当作普通函数传入，并断言调用时没有带参数。
- `PostInstall` 拿到 `ctx.rootPath` 和 `ctx.sdkInfo`，后者是以 SDK 名（`nodejs`，或者别名）为键的表，表项的 `path` 指向解压后的版本。此时 `bin/node` 已经就位。钩子遍历 `ctx.sdkInfo`，而不是直接读 `ctx.sdkInfo.nodejs`，所以用别名也行。`io.popen` 和 `os.execute` 在 vfox 的 Lua 里可以使用。`io.popen(...):close()` 返回的退出状态是数字，不像标准 Lua 里是 `true`，`util.capture` 两种都能处理。
- `EnvKeys` 只设置 `PATH`，不设置 `NODE_HOME` 之类的变量。
- vfox 会先去掉用户输入开头的 `v`，钩子拿到的已经不带它。

## 解析版本

`PreInstall`：

1. `latest` 取 `Available` 的第一项，这个列表由 `util.compare_versions` 按从新到旧排序，逐段比较数字。
2. 任何不是 `x.y.z` 的写法（`^%d+%.%d+%.%d+$`，由 `util.is_semver_simple` 判断）都要到 `util.calculate_shorthand(Available)` 里查。这是一张把 `24`、`24.21` 这样的前缀映射到各自最新版本的表。查不到时以 `version not found for provided version <what the user typed>` 报错。
3. 不存在的版本会通过前两步，在 `SHASUMS256.txt` 返回 404 时失败：`get checksum failed`。

`PreUse` 对已安装的版本执行第 2 步。`ParseLegacyFile` 有自己的规则，见下文。

## 安装包

`PreInstall` 根据 `RUNTIME` 拼出文件名 `node-v<version>-<os>-<arch><ext>`（`util.FileName`）：`amd64` 对应 `x64`，`386` 对应 `x86`，`arm` 对应 `armv7l`，Windows 对应 `win` 和 `.zip`。在 macOS arm64 上，大版本低于 16 时取 `x64`。在 Linux 上，`util.is_musl()` 为真时，`x64` 和 `arm64` 加上 `-musl`，其他 CPU 则报错。接着它读取 `<mirror>/v<version>/SHASUMS256.txt`，用 `util.get_checksum` 找到校验和，并返回与校验和文件同一目录下的 URL。请求失败时以 `get checksum failed: <error>` 或 `get checksum failed: HTTP <status> from <address>` 报错。如果 musl 的包在那里找不到，就用同样的方式再试 `UnofficialBaseUrl`。哪些包存在，表格见 [platforms.md](platforms.md) 和 [musl.md](musl.md)。

`util.getBaseUrl()` 返回镜像地址：去掉末尾斜杠的 `$VFOX_NODEJS_MIRROR`，没有设置时是 `https://nodejs.org/dist`。非官方站点不受它影响。

`post_install.lua` 在 musl 以外什么也不做。在 musl 上，如果在常见的库目录里找不到 `libstdc++.so.6`，它就报错（`util.has_libstdcxx`）。然后它用 `util.capture` 把解压出来的 `bin/node --version` 运行一次：动态加载器会指出缺少的库（`Error loading shared library libatomic.so.1`），钩子把它转成一条报错信息，写明需要的包，在 Alpine 和 OpenWrt 上还写明安装命令（`util.MuslLibraries` 存放包名，`util.install_command` 生成命令）。其他任何失败，以及运行环境无法执行命令的情况，都不会干预这次安装，所以一个无法工作的检查绝不会阻止安装。见 [musl.md](musl.md#依赖的系统库)。

## 兼容版本文件

`ParseLegacyFile` 首先从会话目录里删掉 `env-state.json`（`util.forget_env_state`）。vfox 把 `vfox env` 的结果保存在那里，并且不跟踪版本文件，没有这一步的话，`cd` 进只有版本文件的目录就注意不到。vfox 在加载那个文件之前就调用这个钩子，这就是这个权宜之计能起作用的原因，也是它在离开目录时帮不上忙的原因：没有东西可读的地方不会调用它。见 [nvmrc.md](nvmrc.md#什么时候读取这个文件)。

接着它读取文件并解码（`util.decode_text` 把带标记的 UTF-16 变成 UTF-8，并去掉 UTF-8 的标记，因为 Windows PowerShell 5.1 两种都会写出来）。去掉所有空白字符，再把文本交给 `resolve_version(query, strategy)`：它去掉开头的 `v`，转成小写，把 `lts-x` 变成 `lts/x`，把 `lts/<codename>` 映射到一个大版本，把 `lts` 和 `lts/*` 映射到最新的 LTS 版本线的大版本。在 `latest_available` 策略下，代号先从索引里取（`discover_lts`）。其他情况下，以及索引里没找到或请求失败时，由 `util.known_lts_lines` 作答，不发请求：插件从索引里学到的内容，加上内置的 `util.LtsLines`，见[下文](#插件如何学到-lts-版本线)。

接着 `resolve_legacy_version(strategy, query)` 用 `util.version_prefix` 解析查询：`22` 得到 `{ 22 }`，`22.23` 得到 `{ 22, 23 }`，`22.x`、`22.x.x` 和 `22.*` 都得到 `{ 22 }`。不是这类前缀的文本（`node`、`lts/unknown`、`>=20`）原样返回。对于前缀：

- `specified`：返回查询本身。
- `latest_installed`：返回 `ctx.getInstalledVersions()` 里以该前缀开头的最新版本（`util.newest_matching`，逐段按数字比较）。没有这样的版本时，按 `latest_available` 的做法处理。
- `latest_available`：返回 `Available` 里以该前缀开头的最新版本，没有的话返回查询本身。

`vfox` 随后会选中这个结果，前提是它已安装。面向用户的规则和示例见 [nvmrc.md](nvmrc.md) 和 [lts.md](lts.md)。

## 插件如何学到 LTS 版本线

`ParseLegacyFile` 在带有版本文件的目录里每个提示符都会运行，所以它不能去取 `index.json` 来弄清楚 `lts/*` 是什么。插件在本来就拿到索引的时候学到这些，并把它们放在插件旁边的 `.lts-cache` 里，这是个文本文件：

```text
# What vfox-nodejs learned from index.json about LTS lines. Safe to delete.
updated 1793000000
newest 26
line argon 4
...
line lithium 26
```

- `Available` 解码出索引之后调用 `util.remember_lts`。`util.lts_summary` 找出每条有名字的版本线的大版本，以及最新的 LTS 大版本（`lts` 为 `true` 的版本，也就是没有名字的版本线，只算进最新的那一项）。它在 vfox 自己对答案的缓存过期时运行。
- `PreInstall` 在安装拿到校验和之后调用 `util.refresh_lts_cache`，所以像不支持的架构这样提前失败的安装，什么也不会去取。vfox 安装确切的版本时不会去问 `Available`，所以这样的安装靠这里学到。文件不存在或者超过一天，并且文件可以写入时，它才调用 `Available`，这样只读的插件目录就不会让每次安装都白取一次索引。
- `ParseLegacyFile` 通过 `util.known_lts_lines` 读这个文件，它把学到的内容放在内置的 `util.LtsLines` 之上，`lts` 和 `lts/*` 取两者里最新的大版本。它从不发请求。
- vfox 没有给插件提供它自己的路径，所以 `util.plugin_dir` 在 `package.path` 里有 `hooks/?.lua` 和 `lib/?.lua` 的地方找到目录。新文件写在旧文件旁边，再重命名覆盖过去。任何失败，无论是没有目录、不可写还是文件损坏，都只会让插件退回那张表。
- 在仓库里，`package.path` 以 `./lib/?.lua` 开头，所以这个目录会是仓库本身。钩子测试把 `util.lts_cache_path` 指向它们自己的文件。

## Node.js 把一条版本线升为 LTS 时

每年十月，一条偶数版本线会得到代号，见 [lts.md](lts.md#nodejs-升级版本线时)。插件从索引里学到这条版本线，不需要为此发布新版本。下面是顺手要做的事，让还没学到任何内容的插件也认识它，也让文档保持正确：

1. 在 `lib/util.lua` 的 `UTIL.LtsLines` 里加上 `<codename> = <major>`。
2. 在 `tests/hooks_test.lua` 里，挨着 `legacy lts lithium maps to its major` 加一个用例，并修改 `legacy bare lts is the newest line of the table` 所期望的大版本。
3. 把代号加进 `tests/e2e/common/common.go` 的 `LTSCodenames`，并给 `TestLTSCodename` 加一个用例。E2E 套件会拿这张表和插件根据线上索引写出的文件作比较。
4. 在 [lts.md](lts.md#插件认识哪些代号) 的表里加一行，并修改 [lts.md](lts.md) 和 [nvmrc.md](nvmrc.md) 里写着“撰写本文时为 26”的句子，以及 [lts.md](lts.md#示例) 里的示例。
5. `tests/e2e/common/common.go` 里的 `DefaultLTSVersion` 可以不动：它只要仍在表内即可。

## 测试

钩子测试在离线状态下用 `gopher-lua` 运行，它就是 vfox 内嵌的 Lua 解释器：

```bash
go run github.com/yuin/gopher-lua/cmd/glua@v1.1.1 tests/hooks_test.lua
```

请在仓库根目录运行。`tests/hooks_test.lua` 自己模拟了 `http` 和 `json`（通过 `package.preload`），为每个用例设置 `RUNTIME`，请求的应答来自 `state.response`、`state.decoded` 和 `state.responder`。一个用例写作 `test("name", function() ... end)`，调用它会重置状态和 `available_result`。测试覆盖 `Available` 及其失败情况、各平台的包名和校验和请求失败时的错误、musl 与 `PostInstall`（通过 `with_util` 模拟了 `util.capture`、`util.file_exists` 和 `util.has_libstdcxx`）、各策略下的 `ParseLegacyFile`（包括 UTF-16 和带字节顺序标记的文件，以及删除 `env-state.json`，其中 `os.getenv` 和 `os.remove` 是模拟的）、插件如何学到 LTS 版本线（文件是临时的，每个用例开始时都有一个什么版本线也不认识的新文件）、新老 vfox 下有无遮蔽 `node` 时的 `PreUse`（`RUNTIME.version` 在 1.1.0 之前和之后）、`metadata.lua` 里的 `PLUGIN.shadowHints`，以及 `lib/util.lua` 里的辅助函数。改动需要的用例就加在那里。

gopher-lua 1.1.1 会丢掉闭包对 `local x = nil` 的赋值：外层作用域读到的仍然是 `nil`。要在 `with_util` 或 `pcall` 内部收集值的测试，必须把值放在表的字段里。它还有一个毛病：`local file = path ~= nil and io.open(path, "r") or nil` 之后的 `if file == nil` 会以 Go 的“nil pointer dereference”结束，所以要分成两条语句，先判断 `path`，再打开文件。新代码要用 `glua` 跑一遍，不能只靠 LuaLS。

想对着真实的服务器调用单个钩子，可以用 vfox 1.0.13 及以后版本的 `vfox plugin run`。它不会注册插件，`--os` 和 `--arch` 可以模拟其他平台，`--offline` 会拒绝 HTTP 请求，`VFOX_NODEJS_MIRROR` 同样生效：

```bash
vfox plugin run . Available --json
vfox plugin run . PreInstall --input '{"version":"24"}' --os windows --arch arm64 --json
vfox plugin run . PreUse --input '{"version":"22","installedSdks":{"22.23.3":{"version":"22.23.3"}}}' --json
vfox plugin run . ParseLegacyFile --input '{"filename":".nvmrc","filepath":"/tmp/p/.nvmrc","strategy":"latest_installed","installedVersions":["24.21.0"]}' --json
vfox plugin run . EnvKeys --input '{"path":"C:\\vfox\\nodejs-24.21.0"}' --os windows --arch amd64 --json
```

`vfox --debug <command>` 会显示 vfox 对钩子做了什么，vfox 吞掉的错误可以靠它找出来，比如 `ParseLegacyFile` 里的错误。

Lint、许可证头和容器测试见 [e2e.md](e2e.md#本地检查)。Lua 用 StyLua 格式化（`stylua.toml`：4 个空格缩进，每行 120 列），用 LuaLS 以 `Warning` 级别检查（`.luarc.json` 里声明了 `PLUGIN` 和 `RUNTIME`）。源文件（Lua、Go、YAML、PowerShell 和 Dockerfile）带有许可证头，Markdown 和 JSON 不带。

## 更新平台表

[platforms.md](platforms.md) 的数据取自 nodejs.org。`index.json` 按从新到旧列出所有版本，以及每个版本有哪些文件。下面的命令对每种包打印出有它的最早版本和最新版本，以及两者之间有多少个版本没有它：

```bash
curl -s https://nodejs.org/dist/index.json | jq -r '
  def span($key):
    [to_entries[] | select(.value.files | index($key))] as $hits
    | if ($hits | length) == 0 then "none"
      else "\($hits[-1].value.version) to \($hits[0].value.version), \($hits | length) releases, \($hits[-1].key - $hits[0].key + 1 - ($hits | length)) missing in between"
      end;
  ("linux-x64", "linux-arm64", "linux-ppc64le", "linux-s390x", "linux-x86", "linux-x64-musl",
   "osx-x64-tar", "osx-arm64-tar", "win-x64-zip", "win-x86-zip", "win-arm64-zip") as $key
  | "\($key): \(span($key))"'
```

这里的键是索引对插件所用文件的叫法（`osx-x64-tar` 对应 `darwin-x64.tar.gz`，`win-x64-zip` 对应 `win-x64.zip`）。索引与 `SHASUMS256.txt` 一致（插件读取的是后者），只有两个版本例外：索引在 `linux-x64`、`linux-x86` 和 macOS x64 下列出了 0.11.4 和 0.11.6，但它们没有包。要得到 musl 表，把同一段程序用在 `https://unofficial-builds.nodejs.org/download/release/index.json` 上，键换成 `linux-x64-musl` 和 `linux-arm64-musl`，再用在官方索引上，键换成 `linux-x64-musl`。每次查询只反映一个站点，所以要把两份结果合起来。

## 已知限制

- 32 位 ARM 取 `linux-armv7l` 的包，最高到 23.11.1。ARMv6 的包（`linux-armv6l`）从不会被选中，而从 24 起 32 位 ARM 已经没有任何包。
- riscv64 和 loong64 只在 Unofficial Builds 上有包，而插件只把它用于 musl。
- `PostInstall` 只在 musl 上运行 `node --version`。在 glibc 上，缺少 `libatomic.so.1`（Node.js 25 及以后）要等到 `node` 运行时才会暴露：README 把系统库留给用户自己处理。
- E2E 的 Alpine 镜像通过依赖 `gcc` 的 `go` 得到 `libatomic`，所以套件没有覆盖不带它的原版 Alpine，钩子测试覆盖了。
- `.nvmrc` 里的别名（`node`、`stable`、`lts/-1`）、范围和注释都不认识，见 [nvmrc.md](nvmrc.md#不认识的写法)。
- 插件目录不可写，或者插件装好之后从没拿到过索引，`specified` 和 `latest_installed` 就只有内置的表，它到 Lithium 为止。
- 从带有版本文件的目录 `cd` 到完全没有配置的目录时，不会切换回来。vfox 不跟踪版本文件，并沿用它上一次计算的结果，而没有文件可读的地方不会调用插件，所以 `util.forget_env_state` 只覆盖了进入的方向。修复应当放在 vfox 里：[version-fox/vfox#745](https://github.com/version-fox/vfox/issues/745)，这里用 [#46](https://github.com/version-fox/vfox-nodejs/issues/46) 跟踪。等 vfox 跟踪版本文件之后，就去掉 `util.forget_env_state`。
- 在带有版本文件的目录里，每个提示符都会重新计算一次环境，这是 `util.forget_env_state` 造成的。只装了一个 SDK 时，大约多花一毫秒。
- `latest_available` 在带有兼容版本文件的目录里，每次出现提示符都会下载 `index.json`。
- UTF-32，以及没有字节顺序标记的 UTF-16，都不会解码。
- `VFOX_NODEJS_MIRROR` 对非官方站点不起作用。
- macOS 没有 E2E 作业。

## 发布

维护者在默认分支上执行 **Actions → Plugin → Run workflow**，填入不带 `v` 的版本号。共享工作流具体做什么，README 里有说明。发布之后，[vfox-plugins](https://github.com/version-fox/vfox-plugins) 里的 `plugins/nodejs.json` 会显示 `vfox add nodejs` 提供的是哪个版本。

在 `main` 比最近一次发布更靠前的这段时间里，文档用“未发布”（英文是“Unreleased”）标记更新的内容：条目放在 [changes.md](changes.md) 顶部的“未发布”标题下面，描述新行为的页面会加一句以“未发布：X.Y.Z”开头的话，说明最近一次发布的行为，README 里则有一段话，解释这个标记，并指向 [changes.md](changes.md) 和 [source-build.md](source-build.md)。发布之后，把 [changes.md](changes.md) 里的条目移到新版本下面，每条附上对应的 PR，并去掉这些标注和 README 里的那段话，两种语言都要处理：`grep -rn -i -e unreleased -e 未发布 docs README*`。上一个版本的版本号也要搜一遍：有几句话是拿它做对比的，没有写“未发布”。

## 编写文档

英文页面在 `docs/`，中文页面在 `docs/zh-CN/`，文件名相同（中文版 README 是 `README_CN.md`），每页开头有指向另一种语言的链接。英文页面里的正文按 80 列折行，表格不折。引用数据的页面会写明数据取自哪一天（平台表和 musl 表、镜像列表、LTS 表、`vfox search` 的输出），也没有任何检查会核对这些内容。CI 不对 Markdown 做 lint，所以你加的命令请自己跑一遍，页面里的输出就取自它们实际打印的结果。插件的改动让某一页不再正确时，在同一个 PR 里修改这一页和它的译文。中文页面里指向 `page.md#heading` 的链接，用的是中文页面的标题，所以链接地址和英文页面的不一样。
