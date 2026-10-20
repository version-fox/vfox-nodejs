# npm and global packages

[中文](zh-CN/npm.md) | [English](npm.md)

Every release comes with the npm that Node.js ships it with. `vfox search nodejs`
lists that version after the release, and `npm -v` prints it once the release is
in use:

```bash
vfox install nodejs@24.21.0
vfox use --global nodejs@24.21.0
npm -v                            # 11.19.0
```

## Global packages belong to a release

npm installs `-g` packages next to the Node.js that runs it. With vfox that is
the directory of the installed release, so each release has its own global
packages and its own commands. They are in the `bin` directory that is on `PATH`
while the release is in use:

```text
$ vfox use --global nodejs@24.21.0
$ npm install -g semver
$ npm root -g
/home/me/.vfox/cache/nodejs/v-24.21.0/nodejs-24.21.0/lib/node_modules
$ command -v semver
/home/me/.vfox/sdks/nodejs/bin/semver
$ vfox use --global nodejs@22.23.3
$ command -v semver
$                                  # nothing: 22.23.3 has no semver
```

- After switching to another release, install what you need again. vfox does
  not copy global packages from one release to the next.
- The directory is yours, so `npm install -g` needs no `sudo`. Do not use `sudo`
  with it.
- `vfox uninstall nodejs@24.21.0` removes the release with its global
  packages.
- Settings are shared in part. The user config (`~/.npmrc`) and the cache
  (`~/.npm`) are common to all releases, which is where an npm `registry` setting
  belongs. The global config (`npm config get globalconfig`) is
  `<release>/etc/npmrc` and belongs to the release.

## Updating npm

`npm install -g npm@latest` replaces npm in the release you are using, and in
that one only. On 24.21.0, which comes with npm 11.19.0, `npm install -g npm@10`
leaves `npm -v` at 10.9.9, while every other release keeps its npm. `vfox search`
keeps listing the npm that the release came with.

## Yarn, pnpm and Corepack

- Node.js up to 24 comes with Corepack. `corepack enable` adds `yarn`,
  `yarnpkg`, `pnpm` and `pnpx` to the `bin` directory of the release, so they
  exist for that release only. `corepack disable` removes them.
- Node.js 25 and later does not ship Corepack (checked on 25.9.0 and 26.12.0,
  while 24.21.0, 22.23.3 and 20.20.2 have it). Install it first with `npm
  install -g corepack`, or install the package manager itself, for example `npm
  install -g pnpm`.
- pnpm can install Node.js too, and a `node` that pnpm puts in front of vfox's
  wins over it. See [pnpm.md](pnpm.md).

## Where the files are

| What | Where |
| --- | --- |
| The release | `~/.vfox/cache/nodejs/v-<version>/nodejs-<version>/` |
| `node`, `npm`, `npx` and global commands | `bin/` in it (the install directory itself on Windows) |
| Global packages | `lib/node_modules/` in it (`node_modules/` on Windows) |
| What is in use globally | `~/.vfox/sdks/nodejs`, a link to the release |
| npm cache and user config | `~/.npm` and `~/.npmrc` |

An editor or a build tool that should follow your global choice can point at
`~/.vfox/sdks/nodejs/bin/node`. For a fixed release, use the path in the first
row. See [troubleshooting.md](troubleshooting.md#where-nodejs-is) for the
project and session scopes.
