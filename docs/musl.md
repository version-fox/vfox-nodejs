# musl libc support (Alpine, OpenWrt/ImmortalWrt)

Node.js official Linux tarballs link glibc (`ld-linux-*`). On musl systems
there is no glibc loader, so the stock download fails with `not found` /
`Error loading shared library ld-linux-aarch64.so.1`.
See [issue #29](https://github.com/version-fox/vfox-nodejs/issues/29).

This plugin detects musl and installs a musl tarball instead.

## Requirements

The musl builds link `libstdc++`, which musl distributions normally install
automatically alongside the rest of the system toolchain, so there is
usually nothing extra to do. If `node --version` ever fails with
`Error relocating ... symbol not found`, the system is missing its
`libstdc++` (`libstdcpp` on OpenWrt) runtime. The plugin's `PostInstall`
hook detects this case and fails the install with a pointer at the README
instead of leaving the cryptic relocation error.

## Which tarball is installed

| Host | Tarball | Source |
| ---- | ------- | ------ |
| Linux glibc, x64/arm64 | `node-v<V>-linux-x64.tar.gz` etc. | `nodejs.org/dist` |
| Linux musl, x64 | `node-v<V>-linux-x64-musl.tar.gz` | official index when present, else unofficial |
| Linux musl, arm64 | `node-v<V>-linux-arm64-musl.tar.gz` | `unofficial-builds.nodejs.org` (official never ships it) |

Notes:

- Official `nodejs.org/dist` only carries `linux-x64-musl` for recent
  releases (roughly `26.8+`, `24.20+`, `22.23.3+`) and never carries
  `linux-arm64-musl`. Older releases and all `arm64-musl` installs fall back
  to `https://unofficial-builds.nodejs.org/download/release` automatically.
- Mirror behavior on musl (when the mirror applies, when unofficial is
  used): see [mirror](mirror.md).
- musl builds exist only for `x64` and `arm64`. Other Linux architectures
  (e.g. `x86`) error out with a pointer to the README.
- After install the plugin returns a note pointing at the README so the
  `libstdc++` requirement is visible in normal `vfox install` output.

## Detection and override

Detection order in `lib/util.lua`:

1. `$VFOX_NODEJS_LIBC`: `musl` forces musl, `gnu`/`glibc` forces glibc.
   Useful on exotic userlands and in tests.
2. `RUNTIME.envType` when a future vfox core provides it (`musl`/`gnu`).
3. File probes readable from Lua: `/etc/alpine-release`,
   `/lib`/`/usr/lib`/`/lib64` `ld-musl-*.so.1`. musl wins when both linkers
   exist (e.g. `gcompat` shims). Non-Linux is never musl.

```sh
# Force musl selection (debugging only)
VFOX_NODEJS_LIBC=musl vfox install nodejs@26.11.1
```
