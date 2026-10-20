# 从源码安装插件

[中文](source-build.md) | [English](../source-build.md)

通常从插件注册表安装：

```sh
vfox add nodejs
```

需要尚未发布的内容（`main` 分支，或者检出的某个 PR）时，就从源码安装：把检出的代码打包成 zip，交给 `vfox add --source`。zip 的顶层必须有 `metadata.lua`、`hooks/` 和 `lib/`，这是插件包的约定（见[共享工作流文档](https://github.com/version-fox/plugin-manifest-action)）。

已发布的插件 zip 的 URL 也可以用作 `--source`，例如 `vfox add --source https://github.com/version-fox/vfox-nodejs/releases/download/v0.0.5/vfox-nodejs_0.0.5.zip`。

所有系统都需要事先装好 [vfox](https://github.com/version-fox/vfox) 本身和 `git`。

## Windows 11

在 PowerShell 7 里执行（`tar` 是系统自带的，不需要另装 zip 工具）：

```powershell
git clone https://github.com/version-fox/vfox-nodejs.git
cd vfox-nodejs
# 如果是 PR：git fetch origin pull/<number>/head:pr; git checkout pr
tar -a -c -f $env:TEMP\nodejs.zip metadata.lua hooks lib
vfox add nodejs --source "$env:TEMP\nodejs.zip"
vfox install nodejs@26.11.1
```

## Ubuntu 26.04

```bash
sudo apt install --assume-yes git zip
git clone https://github.com/version-fox/vfox-nodejs.git
cd vfox-nodejs
# 如果是 PR：git fetch origin pull/<number>/head:pr && git checkout pr
zip -qr /tmp/nodejs.zip metadata.lua hooks lib
vfox add nodejs --source /tmp/nodejs.zip
vfox install nodejs@26.11.1
```

## macOS

命令与 Ubuntu 上相同，去掉 `apt` 那一行：`zip` 是系统自带的，`git` 随 Xcode 命令行工具提供。

## Alpine 3.24.2

```sh
apk add git zip
git clone https://github.com/version-fox/vfox-nodejs.git
cd vfox-nodejs
# 如果是 PR：git fetch origin pull/<number>/head:pr && git checkout pr
zip -qr /tmp/nodejs.zip metadata.lua hooks lib
vfox add nodejs --source /tmp/nodejs.zip
vfox install nodejs@26.11.1
```

在 Alpine 上，安装的 Node.js 需要先装好系统库，见 [musl.md](musl.md#依赖的系统库)。

## 验证

```bash
vfox info nodejs
vfox install nodejs@24
vfox use --global nodejs@24
node -v
```

`vfox info nodejs` 打印的是已添加的插件的版本，也就是 `metadata.lua` 里的 `PLUGIN.version`。`main` 的源码构建带的是上一个发布版的版本号，所以靠它看不出你用的是哪个提交。

## 已经添加过 nodejs 时

`vfox add` 会拒绝，报 `plugin named nodejs already exists`。可以替换原有的插件，也可以让源码构建的版本与它并存。

替换要先执行 `vfox remove nodejs`，它会连同通过这个插件装的 Node.js 版本一起删掉：vfox 在询问之前会先说 `Removing this plugin will remove the installed sdk along with the plugin.`（`-y` 可以跳过询问）。之后需要重新安装这些版本。

想两个都保留，就给新的另起一个名字：

```bash
vfox add nodejs --source /tmp/nodejs.zip --alias nodejs-dev
vfox install nodejs-dev@24
vfox remove -y nodejs-dev          # 只删除 nodejs-dev 和它装的东西
```

别名有它自己的已安装版本列表，放在 `~/.vfox/cache/nodejs-dev/` 下，但两个插件都把选中的版本链接成 `~/.vfox/sdks/nodejs`。每个作用域里只从其中一个选版本：全局作用域下，先执行 `vfox unuse --global nodejs`，再执行 `vfox use --global nodejs-dev@...`，反过来也一样。两个都选了的话，这个链接会指向其中一个，`node` 跟着它走，指向哪一个说不准。

## 更新

拉取代码，重新打包 zip，再添加一次。以原名添加的插件必须先删除，而这会连已安装的版本一起删掉，所以经常更新时用别名更省事：

```bash
vfox remove -y nodejs-dev
vfox add nodejs --source /tmp/nodejs.zip --alias nodejs-dev
```

`vfox update nodejs` 会拿 `metadata.lua` 里的版本号和注册表里的比较，两者相同时只会打印 `nodejs is already the latest version`，所以在发布出比它更新的版本之前，不会动源码构建的版本。

开发插件，见 [development.md](development.md)。
