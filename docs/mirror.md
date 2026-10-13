# Mirror

The Node.js packages and the version index (`index.json`, `SHASUMS256.txt`)
are downloaded from `https://nodejs.org/dist` by default. Set
`VFOX_NODEJS_MIRROR` to use another mirror:

```bash
export VFOX_NODEJS_MIRROR="https://npmmirror.com/mirrors/node"
vfox install nodejs@22.23.3
```

Point it at the root that mirrors `nodejs.org/dist`; the plugin appends its
paths (`/index.json`, `/v<version>/...`) to that base URL. Trailing slashes
are handled, so both `https://nodejs.org/dist` and `https://nodejs.org/dist/`
work.
