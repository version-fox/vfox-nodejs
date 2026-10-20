# pnpm

[中文](pnpm.md) | [English](../pnpm.md)

pnpm 作为包管理器使用（比如通过 `npm install -g pnpm` 安装）时，可以和这个插件并存。冲突出在 pnpm 也去安装 Node.js 的时候：`pnpm runtime set node <version> -g`（或者已弃用的 `pnpm env use --global <version>`）会在 `$PNPM_HOME/bin` 里放进第二个 `node`。真正运行的只有 `PATH` 里排在最前面的那个 `node`，而 pnpm 写入的 Shell 配置恰好让它排在最前，所以不管 `vfox use` 选了什么，运行的都是 pnpm 的。

以下现象是在 Ubuntu 的 bash 里，用 pnpm 12.14.0 和 vfox 1.0.12 观察到的。

## 现象

- `vfox use nodejs@24.21.0` 打印 `Now using nodejs@24.21.0`，`vfox current nodejs` 也与之一致，但 `node --version` 打印的却是 pnpm 管理的版本。全局、会话和项目作用域都受影响。
- `type -a node` 把 `$PNPM_HOME/bin/node` 列在 vfox 的路径之前。
- 在带有 `.nvmrc` 或 `.node-version` 的目录里，`node` 运行的是 pnpm 首次使用时下载的那份副本，即使 vfox 已经装了这个版本。
- `npm install -g <pkg>` 显示成功，但找不到装好的命令。pnpm 的运行时不带 npm，所以 vfox 的 `npm` 跑在 pnpm 的 `node` 上，装进了 `$PNPM_HOME` 下 pnpm 那份 Node.js 里。

## 原因

1. 在 `$PNPM_HOME/bin` 进入 `PATH` 之前，`pnpm runtime set node -g` 拒绝执行（`ERR_PNPM_GLOBAL_BIN_DIR_NOT_IN_PATH`）。它建议的修复办法 `pnpm setup`，会在 Shell 的 rc 文件末尾，也就是 `eval "$(vfox activate bash)"` 的下面，加一段把 `$PNPM_HOME/bin` 放到 `PATH` 最前面的配置。
2. 每次出现提示符时，`vfox env` 都会把 `PATH` 里排在它自己的第一个路径之前的条目，保留在所有 SDK 路径的前面，这样已经激活的 Python 虚拟环境才能保持优先。`$PNPM_HOME/bin` 正是这样一个条目。
3. 那个 `node` 是 pnpm 的 shim：它运行 pnpm 的全局 Node.js，或者当前项目通过 `devEngines.runtime`、`engines.runtime`、`.node-version` 或 `.nvmrc` 固定的版本（见[项目感知的全局 bin](https://pnpm.io/global-packages#project-aware-global-bins)）。pnpm 的 `globalShims` 设置和 `PNPM_SHIM_BYPASS=1` 只能关掉按项目查找；`node` 运行的仍然是 pnpm 的全局 Node.js，而不是 vfox 的。

不管是哪个工具放的，只要有 `node` 排在 vfox 前面，`vfox use nodejs@<version>` 就会打印一条提示：

```text
Note: /home/user/.local/share/pnpm/bin/node comes before vfox in PATH, so `node` will not run nodejs@24.21.0. See https://github.com/version-fox/vfox-nodejs/blob/main/docs/pnpm.md
```

## 让 vfox 继续管理 `node`

卸掉 pnpm 全局安装的 Node.js。pnpm 照常可用，因为 `pnpm setup` 已经把它复制到了 `$PNPM_HOME`：

```sh
pnpm remove -g node
```

把 vfox 的挂载语句挪到 rc 文件里 pnpm 那段配置的下面是不够的：除非 `$PNPM_HOME/bin` 已经排在最前，pnpm 的配置每次都会把它再放回最前面，所以嵌套的 Shell 里 pnpm 的 `node` 又会回到前面。

用 `devEngines.runtime` 固定了运行时的项目，脚本里仍然用固定的那个：`pnpm install` 之后，`pnpm run` 和 `pnpm exec` 使用 `node_modules/.bin` 里固定的 Node.js，而直接敲的 `node` 跟随 vfox。

想让 pnpm 来管理 Node.js 的话，就不要在同一个 Shell 里用 vfox 选 `nodejs`。
