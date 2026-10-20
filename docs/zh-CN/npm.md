# npm 与全局包

[中文](npm.md) | [English](../npm.md)

每个版本都自带 Node.js 随它一起发布的那个 npm。`vfox search nodejs` 会在每个版本后面列出它自带的 npm 版本；使用某个版本之后，`npm -v` 就会打印这个 npm 版本：

```bash
vfox install nodejs@24.21.0
vfox use --global nodejs@24.21.0
npm -v                            # 11.19.0
```

## 全局包属于某个版本

npm 把 `-g` 安装的包放在运行它的那个 Node.js 旁边。在 vfox 下，那就是已安装版本的目录，所以每个版本都有自己的全局包和自己的命令。版本正在使用时，这些命令位于 `PATH` 里的 `bin` 目录中：

```text
$ vfox use --global nodejs@24.21.0
$ npm install -g semver
$ npm root -g
/home/me/.vfox/cache/nodejs/v-24.21.0/nodejs-24.21.0/lib/node_modules
$ command -v semver
/home/me/.vfox/sdks/nodejs/bin/semver
$ vfox use --global nodejs@22.23.3
$ command -v semver
$                                  # 没有输出：22.23.3 里没有 semver
```

- 切换到另一个版本后，需要的包要重新安装。vfox 不会把全局包从一个版本复制到下一个版本。
- 这个目录是你自己的，所以 `npm install -g` 不需要 `sudo`，也不要对它使用 `sudo`。
- `vfox uninstall nodejs@24.21.0` 会把这个版本连同它的全局包一起删除。
- 设置有一部分是共享的。用户配置（`~/.npmrc`）和缓存（`~/.npm`）是所有版本共用的，npm 的 `registry` 设置应该放在这里。全局配置（`npm config get globalconfig`）是 `<release>/etc/npmrc`，属于各自的版本。

## 更新 npm

`npm install -g npm@latest` 会替换正在使用的那个版本里的 npm，并且只替换这一个。24.21.0 自带 npm 11.19.0，在它上面执行 `npm install -g npm@10` 之后，`npm -v` 是 10.9.9，而其他版本的 npm 都不变。`vfox search` 列出的仍然是该版本自带的 npm。

## Yarn、pnpm 与 Corepack

- 24 及更早的 Node.js 版本自带 Corepack。`corepack enable` 会把 `yarn`、`yarnpkg`、`pnpm` 和 `pnpx` 加到该版本的 `bin` 目录里，所以它们只对这个版本存在。`corepack disable` 会把它们删掉。
- Node.js 25 及以后的版本不自带 Corepack（在 25.9.0 和 26.12.0 上检查过，而 24.21.0、22.23.3 和 20.20.2 都有）。需要先用 `npm install -g corepack` 安装它，或者直接安装包管理器本身，例如 `npm install -g pnpm`。
- pnpm 也可以安装 Node.js，而 pnpm 放到 vfox 前面的 `node` 会优先于 vfox 的。见 [pnpm.md](pnpm.md)。

## 文件在哪里

| 内容 | 位置 |
| --- | --- |
| 版本本身 | `~/.vfox/cache/nodejs/v-<version>/nodejs-<version>/` |
| `node`、`npm`、`npx` 和全局命令 | 其中的 `bin/`（Windows 上就是安装目录本身） |
| 全局包 | 其中的 `lib/node_modules/`（Windows 上是 `node_modules/`） |
| 全局正在使用的版本 | `~/.vfox/sdks/nodejs`，指向该版本的链接 |
| npm 缓存和用户配置 | `~/.npm` 和 `~/.npmrc` |

想让编辑器或构建工具跟随你的全局选择，可以让它指向 `~/.vfox/sdks/nodejs/bin/node`。要固定某个版本，就用第一行里的路径。项目和会话作用域的情况见 [troubleshooting.md](troubleshooting.md#nodejs-在哪里)。
