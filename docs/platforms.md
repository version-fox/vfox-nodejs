# Platform support

The plugin picks the package for the operating system and the CPU architecture
of the vfox binary (`RUNTIME.osType` and `RUNTIME.archType`, Go's `GOOS` and
`GOARCH`) and, on Linux, for the C library. The file it asks for is named

```text
node-v<version>-<os>-<arch><extension>
```

`<os>` is `linux`, `darwin` or `win`. `<arch>` is `x64`, `x86`, `armv7l`,
`arm64`, `ppc64le` or `s390x`: `amd64` becomes `x64`, `386` becomes `x86`, `arm`
becomes `armv7l` and every other name is passed through as vfox reports it.
`<extension>` is `.zip` on Windows and `.tar.gz` everywhere else. On musl Linux
`-musl` follows the architecture, see [musl.md](musl.md).

The plugin reads the `SHASUMS256.txt` in the release's directory. When that
file does not list the package, the install stops before anything is
downloaded:

```text
Node.js package node-v19.8.1-win-arm64.zip is not listed in https://nodejs.org/dist/v19.8.1/SHASUMS256.txt
```

## Releases per platform

The table was taken from nodejs.org on 2026-10-21, from the `SHASUMS256.txt` of
each of the 872 releases in `index.json`. "Releases" is the first and the last
release that has a package under the plugin's file name, and the gaps are
releases in between for which Node.js published none. How to take it again is
in [development.md](development.md#refreshing-the-platform-table).

| vfox reports | Package | Releases |
| --- | --- | --- |
| Linux amd64 | `linux-x64.tar.gz` | 0.8.6 and later, except 0.9.0, 0.11.4 and 0.11.6 |
| Linux arm64 | `linux-arm64.tar.gz` | 4.0.0 and later |
| Linux ppc64le | `linux-ppc64le.tar.gz` | 4.3.2 and later, except 5.0.0 to 5.6.0 |
| Linux s390x | `linux-s390x.tar.gz` | 6.6.0 and later |
| Linux 386 | `linux-x86.tar.gz` | 0.8.6 to 9.11.2, except 0.9.0, 0.11.4 and 0.11.6 |
| Linux arm | `linux-armv7l.tar.gz` | 4.0.0 to 23.11.1, except 8.1.1. Unreleased: release 0.5.2 asks for `linux-arm`, which Node.js never published, so every install fails |
| Linux amd64, musl | `linux-x64-musl.tar.gz` | see [musl.md](musl.md#which-releases-have-a-musl-build) |
| Linux arm64, musl | `linux-arm64-musl.tar.gz` | see [musl.md](musl.md#which-releases-have-a-musl-build) |
| macOS amd64 | `darwin-x64.tar.gz` | 0.8.6 and later, except 0.9.0, 0.11.4 and 0.11.6 |
| macOS arm64 | `darwin-arm64.tar.gz` | 16.0.0 and later. Earlier releases install the amd64 package, see [macOS](#macos) |
| Windows amd64 | `win-x64.zip` | 4.5.0 and later, except 5.0.0 to 5.12.0 and 6.0.0 to 6.2.0 |
| Windows 386 | `win-x86.zip` | 4.5.0 to 22.23.3, except 5.0.0 to 5.12.0, 6.0.0 to 6.2.0 and 18.0.0 to 18.2.0 |
| Windows arm64 | `win-arm64.zip` | 19.9.0 and later |

From 19.9.0 on, every release has a package for each row that has no upper
limit. The 32-bit rows stop early: after 22.23.3 on Windows, after 23.11.1 on
Linux arm and after 9.11.2 on Linux x86, so a 32-bit vfox cannot install a
current release.

`vfox search nodejs` lists all 872 releases whatever the platform is, because
the index does not say which platforms a release has. `vfox install
nodejs@19.8.1` on Windows arm64 therefore starts fine and ends with the message
above, see [troubleshooting.md](troubleshooting.md#messages-from-the-plugin).

## Not supported

- **ARMv6, and 32-bit ARM from 24 on.** vfox ships an `armv7` binary that
  reports `arm`, and the plugin takes the `linux-armv7l` package for it, which
  Node.js published up to 23.11.1. From 24 on there is none, and the install
  ends with `Node.js package node-v26.12.0-linux-armv7l.tar.gz is not listed in
  ...`. The ARMv6 package (`linux-armv6l`, 4.0.0 to 11.15.0 on nodejs.org) is
  never chosen. Unreleased: release 0.5.2 asks for `linux-arm`, which Node.js
  never published, so every install on 32-bit ARM fails with `Node.js package
  node-v20.19.5-linux-arm.tar.gz is not listed in ...`.
- **Linux riscv64 and loong64.** nodejs.org has no packages for them. The
  [Unofficial Builds](https://github.com/nodejs/unofficial-builds) site has
  riscv64 (17.7.1 to 26.0.0) and loong64 (18.18.0 and later), but the plugin
  uses that site for musl only.

## Linux

The plugin takes the glibc package, or the musl one when it detects musl, see
[musl.md](musl.md#detection-and-override). Which glibc and kernel a release
needs is Node.js's business, see its
[supported platforms](https://github.com/nodejs/node/blob/main/BUILDING.md).
System libraries are the user's responsibility, and the plugin installs none of
them. Two to know about:

- The glibc packages of Node.js 25 and later link `libatomic.so.1`, which stock
  Debian and Ubuntu images do not ship. `node` then fails with `error while
  loading shared libraries: libatomic.so.1`. Install it with
  `sudo apt install --assume-yes libatomic1`. The releases of 24 and earlier do
  not link it (checked on 25.9.0 and 26.12.0 against 24.21.0 and 20.20.2), see
  [nodejs/node#60790](https://github.com/nodejs/node/issues/60790).
- The musl packages need `libstdc++`, see [musl.md](musl.md#requirements).

Inside WSL vfox is a Linux binary, so the Linux packages are used.

## macOS

The packages are `darwin-x64.tar.gz` and `darwin-arm64.tar.gz`. Node.js
published no arm64 package before 16.0.0, so on Apple silicon the plugin takes
the amd64 one for those releases and says so:

```text
Note: Node.js versions below 16 do not support Apple Silicon (arm64), using x64 architecture with Rosetta 2
```

Rosetta 2 has to be installed for them to run (`softwareupdate
--install-rosetta`). 16.0.0 and later install natively.

There is no macOS job in the e2e suite, see [below](#what-ci-covers). The hook
tests check the package name for `darwin/arm64`.

## Windows

The package is a zip. `node.exe`, `npm.cmd` and `npx.cmd` end up directly in the
install directory, so the plugin puts that directory itself on `PATH`. There is
no `bin` directory as on Linux and macOS.

- A home directory with a space in it (`C:\Users\John Doe`) needs vfox 1.0.13
  or later ([vfox#712](https://github.com/version-fox/vfox/pull/712)). The e2e
  suite runs every combination against such a home.
- In Git Bash `node`, `npm.cmd` and the extensionless `npm` run once the shell
  hook is active ([vfox#293](https://github.com/version-fox/vfox/issues/293)).
- `VFOX_NODEJS_MIRROR` is read from the environment of the process that runs
  vfox. In PowerShell set it with `$env:VFOX_NODEJS_MIRROR = '...'` for the
  session, see [mirror.md](mirror.md#setting-it).

## vfox's own platforms

vfox 1.0.13 ships binaries for Linux x86_64, aarch64, armv7, i386 and loong64,
macOS x86_64 and aarch64, and Windows x86_64, aarch64 and i386. The plugin
takes whatever name the binary reports, so a vfox that you build for Linux
ppc64le or s390x installs the ppc64le or s390x packages.

## What CI covers

The container e2e suite, see [e2e.md](e2e.md), installs a pinned release, a
pinned LTS release and `nodejs@latest` on:

| Platform | Runner |
| --- | --- |
| Linux glibc, amd64 | `ubuntu-latest` |
| Linux glibc, arm64 | `ubuntu-26.04-arm` |
| Linux musl (Alpine), amd64 and arm64 | the same two runners |
| Windows containers, amd64 and arm64 | `windows-latest`, `windows-11-arm` |
| Ubuntu 24.04 on WSL | `windows-2025` |

macOS, 32-bit systems, ppc64le and s390x are not covered. The hook tests
(`tests/hooks_test.lua`) run offline and check the package name for `windows`
on amd64, 386 and arm64, `linux` on amd64 and arm, musl on amd64 and arm64, and
`darwin` on arm64.
