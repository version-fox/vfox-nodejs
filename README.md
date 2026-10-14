# vfox-nodejs

Node.js plugin for [vfox](https://vfox.dev/).

## Install

After installing [vfox](https://github.com/version-fox/vfox), install the plugin by running:

```bash
vfox add nodejs
```

### Example: Ubuntu 26.04

```bash
vfox add nodejs
vfox install nodejs@26.11.1
sudo apt install --assume-yes libatomic1
vfox use --global nodejs@26.11.1
```

Note: the `libatomic1` step works around an upstream Node.js packaging bug
([nodejs/node#60790](https://github.com/nodejs/node/issues/60790), still
open): Node 25+ links `libatomic.so.1`, which stock Debian/Ubuntu images do
not ship. System libraries are the user's responsibility; the plugin does
not install them.

### Example: Alpine / musl

```bash
vfox add nodejs
vfox install nodejs@26.11.1
vfox use --global nodejs@26.11.1
```

You can verify this using the following command:

```bash
node -v
```

musl details (OpenWrt, tarball matrix, mirror fallback): see [docs/musl.md](docs/musl.md).

## Mirror

See [docs/mirror.md](docs/mirror.md) for details.

## FAQ

### Install from source

See [docs/source-build.md](docs/source-build.md) for details.

### LTS

See [docs/lts.md](docs/lts.md) for details.

### Testing

See [docs/e2e.md](docs/e2e.md) for details.

## Releasing this plugin

Maintainers can publish from **Actions → Plugin → Run workflow** on the default
branch by entering a stable plugin version without the `v` prefix. The shared
workflow updates `metadata.lua`, creates the version commit and tag, and publishes
the ZIP and manifest in this repository. No local tag or extra release token is
needed. Pull requests run checks only; PR titles no longer trigger publication.

Existing version-tag pushes are supported when `PLUGIN.version` already matches
the tag. If publication fails, re-run the original failed job to resume it.

The workflow follows the shared `@v1` release-tool version. Updating the tool does
not release this plugin. See the [shared workflow documentation](https://github.com/version-fox/plugin-manifest-action)
for the package contract and first-rollout requirements.
