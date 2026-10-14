# Mirror

The Node.js packages and the version index (`index.json`, `SHASUMS256.txt`)
are downloaded from `https://nodejs.org/dist` by default. Set
`VFOX_NODEJS_MIRROR` to use another mirror:

```bash
export VFOX_NODEJS_MIRROR="https://npmmirror.com/mirrors/node"
vfox install nodejs@26.11.1
```

Point it at the root that mirrors `nodejs.org/dist`; the plugin appends its
paths (`/index.json`, `/v<version>/...`) to that base URL. Trailing slashes
are handled, so both `https://nodejs.org/dist` and `https://nodejs.org/dist/`
work.

## musl and unofficial builds

`VFOX_NODEJS_MIRROR` only covers `nodejs.org/dist`. It does **not** apply to
`https://unofficial-builds.nodejs.org/download/release`, which the plugin
uses as a fallback on musl Linux (see [musl](musl.md)):

- Linux musl x64 on a recent release (`26.8+`, `24.20+`, `22.23.3+`): the
  official `*-musl` tarball is used, so the mirror applies normally (as long
  as the mirror carries it).
- Linux musl arm64 (all releases), or musl x64 on an older release: the
  official index has no such file, so the plugin downloads from
  `unofficial-builds.nodejs.org` directly, ignoring the mirror.

A mirror that cannot even serve `SHASUMS256.txt` still fails the install
instead of falling back (this is covered by the bogus-mirror negative probes
in [e2e](e2e.md)); only a missing musl filename falls through to unofficial.
