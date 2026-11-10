# Scenarios

[中文](zh-CN/scenarios.md) | [English](scenarios.md)

This plugin gives vfox what [nvm-sh/nvm](https://github.com/nvm-sh/nvm) gives a
POSIX shell: several Node.js releases side by side, one of them chosen for a
shell, for a project or as the default, and `.nvmrc` files read. nvm-sh/nvm is a
set of shell functions. Its README names sh, dash, ksh, zsh and bash on Unix,
macOS and WSL, adds Git Bash and Cygwin for some cases, and points other Windows
users to other tools. PowerShell is not in that list. vfox is a program with a
hook for each shell, so the same work runs in Windows PowerShell 5.1, which
ships with Windows 10 and 11, as well as in PowerShell 7, bash, zsh and fish.

Each case below says what you want, what to type and what you see. The outputs
are from 2026-11-03 on Linux x64, with vfox 1.0.13 and the code that became
release 0.5.6, except the table in
[Several projects in one shell](#several-projects-in-one-shell), which was
replayed with vfox 1.1.0 and release 0.5.6 on 2026-11-10. The home
directory is shown as `/home/me`. The PowerShell
lines were run in PowerShell 7.6.9 on Linux, except those that exist only on
Windows: `Set-ExecutionPolicy` and the user-level
`[Environment]::SetEnvironmentVariable`. Windows PowerShell 5.1 itself is not
part of the test suite ([platforms.md](platforms.md#what-ci-covers)), so a case
marks what rests on the documentation of PowerShell or on vfox's source, not on
a run there.

## Coming from nvm

| nvm-sh/nvm | vfox | Notes |
| --- | --- | --- |
| `nvm install 22` | `vfox install nodejs@22` | The newest 22.x, checked against its SHA-256 sum. See [versions.md](versions.md) |
| `nvm install node` | `vfox install nodejs@latest` | The newest release of any line, LTS or not. See [versions.md](versions.md#installing) |
| `nvm install --lts`, `nvm install 'lts/*'` | `vfox install nodejs@26` | There is no `lts` name, name the line. 26 is the newest LTS line on 2026-11-03, and `vfox search nodejs \| grep -m1 '(LTS)'` shows the newest LTS release. See [lts.md](lts.md) |
| `nvm use 22` | `vfox use nodejs@22` | This shell only. `22` is the newest installed 22.x |
| `nvm alias default 22` | `vfox use --global nodejs@22` | Every new shell |
| `nvm ls` | `vfox list nodejs` | |
| `nvm ls-remote` | `vfox search nodejs` | Every release, with its npm |
| `nvm current` | `vfox current nodejs` | |
| `nvm exec 22.23.4 node app.js`, `nvm run 22.23.4 app.js` | `vfox exec nodejs@22.23.4 -- node app.js` | The whole release number. See [below](#run-a-command-on-a-given-release) |
| `nvm uninstall 22.23.4` | `vfox uninstall nodejs@22.23.4` | The whole release number |
| `nvm install-latest-npm` | `npm install -g npm@latest` | In the release in use only. See [npm.md](npm.md#updating-npm) |
| `nvm install --reinstall-packages-from=20 22` | nothing | Global packages belong to a release. See [npm.md](npm.md#global-packages-belong-to-a-release) |
| `.nvmrc` | `.nvmrc`, `.node-version`, `.vfox.toml` | See [nvmrc.md](nvmrc.md) |
| `NVM_NODEJS_ORG_MIRROR` | `VFOX_NODEJS_MIRROR` | See [mirror.md](mirror.md) |

Four things differ from what nvm taught you:

- `vfox use` changes the environment of your shell, which only vfox's hook can
  do (`eval "$(vfox activate bash)"`, or the profile line in
  [Windows PowerShell 5.1](#windows-powershell-51)). Without it `vfox use` stops
  on Linux and macOS with `vfox requires hook support. Please ensure vfox is
  properly initialized with 'vfox activate'`. `vfox install` and `vfox exec`
  need no hook.
- There is no `nvm use` without an argument and no `nvm install` that reads
  `.nvmrc`. vfox reads `.nvmrc` and `.node-version` itself, selects among the
  installed releases and installs nothing. When it reads them is the point of
  [Several projects in one shell](#several-projects-in-one-shell).
- There are no aliases. `lts`, `node` and `stable` are not names for `vfox
  install` or `vfox use`. Only `.nvmrc` files understand `lts/*` and
  `lts/<codename>`, and what they select depends on a setting, see
  [nvmrc.md](nvmrc.md#the-strategy-decides).
- Global packages stay with their release, and vfox does not copy them to the
  next one.

## Windows PowerShell 5.1

You have a Windows PC with `powershell.exe`, which is Windows PowerShell 5.1,
and the README of the project says `nvm use 22`. `nvm` is not a command there.
Once vfox is installed (its
[quick start](https://vfox.dev/guides/quick-start.html) lists Scoop, winget and
an installer), four steps give you the same workflow.

1. **Let PowerShell run your profile.** On a Windows client where nobody has set
   an execution policy, Windows PowerShell 5.1 uses `Restricted`, which also
   stops `$PROFILE`
   ([about_Execution_Policies](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_execution_policies)),
   and the profile is where the hook goes. The `CurrentUser` scope needs no
   administrator:

   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
   ```

   A policy from Group Policy overrides this. `Get-ExecutionPolicy -List` shows
   it as `MachinePolicy` or `UserPolicy`.

2. **Hook vfox into PowerShell.** This is the line from vfox's quick start:

   ```powershell
   if (-not (Test-Path -Path $PROFILE)) { New-Item -Type File -Path $PROFILE -Force }; Add-Content -Path $PROFILE -Value 'Invoke-Expression "$(vfox activate pwsh)"'
   ```

   Windows PowerShell 5.1 and PowerShell 7 read different profile files, so run
   it in each one you use. The hook that `vfox activate pwsh` prints (vfox
   1.0.13) is plain PowerShell: it wraps the `prompt` function and sets
   environment variables such as `$env:PATH`, and nothing in it needs
   PowerShell 7.

3. **Open a new window** and install Node.js:

   ```powershell
   vfox add nodejs
   vfox install nodejs@24
   vfox use --global nodejs@24
   node -v
   ```

4. **Use it** the way the table above says. Spell out the scope of `vfox use`:
   `--global`, `--project` or `--session` (`-g`, `-p`, `-s`).

What is different on Windows:

- `vfox use --global` also writes the link of the global release to your user
  `Path` (`HKEY_CURRENT_USER\Environment`) and tells the running programs about
  it, and prints `Applied global environment variables to Windows registry.`
  (vfox 1.0.13, from its source). Programs that start afterwards, such as
  cmd.exe or an editor opened from the Start menu, find the same `node` without
  running a hook. Terminals and programs that were open before keep the `Path`
  they started with.
- Everything stays per user. The releases are in `%USERPROFILE%\.vfox`, vfox
  links them with junctions, which need no administrator, and the `Path` it
  changes is your own (also from vfox's source).
- vfox's documentation lists a bare `vfox use` as global on Windows and session
  elsewhere. In a shell without the hook there is no session, and vfox says so
  instead of stopping as it does on Linux:

  ```text
  Warning: The current shell lacks hook support. Switching to global scope automatically.
  ```

  If `vfox use --session` prints this, the profile did not run: the execution
  policy of step 1, or the hook line is in the profile of the other PowerShell.
- Only the first `node` in `PATH` runs. One from the installer of nodejs.org,
  from winget or Scoop, or from another version manager can sit in front of
  vfox's. `vfox use` then warns about it: on vfox 1.1.0 and later vfox warns
  itself with the plugin's hint, on older vfox the plugin prints a note that
  names it and says that it comes before vfox in `PATH`, see [pnpm.md](pnpm.md)
  and [managers.md](managers.md). Uninstall the other one, or link it with
  `vfox link --detect nodejs`.
- A `.nvmrc` that Windows PowerShell 5.1 writes with `>` is UTF-16, which the
  plugin reads, see [below](#writing-the-file-from-windows-powershell-51).

## The same Node.js for the whole team

Two files can say which release a project wants. Pick by who is on the team.

**Everyone uses vfox: `.vfox.toml`.** `vfox use --project nodejs@22.23.4` writes
it, and `--project` is also how you change it:

```toml
[tools]
nodejs = "22.23.4"
```

When the repository has a `.gitignore`, vfox adds `.vfox/` to it and says
`Added '.vfox/' to .gitignore`. Without one, `git status` lists `.vfox/` and
`.vfox.toml`, and you ignore `.vfox/` yourself. Commit `.vfox.toml`. A new
teammate installs what it names:

```text
$ vfox install --all -y
Install the following plugins and SDKs:
SDK:
  nodejs@22.23.4
 [1/1] SDK: nodejs@22.23.4 installing...
 [1/1] Installation completed.
Green indicates successful installation, while red indicates installation failure.
SDK:
  nodejs@22.23.4
$ vfox install --all -y
All plugins and SDKs are already installed
```

(The spinner frames are left out. Without `-y`, vfox asks first, and a script
stops with `Use the -y flag to automatically confirm installation in
non-interactive environments`.)

**Part of the team uses nvm-sh/nvm: `.nvmrc`.** Keep the file they have.
`.node-version` works the same way. With vfox's default setting a full release
number (`22.23.4`) is what selects something, and `22` or `lts/*` need
`latest_installed`, see [nvmrc.md](nvmrc.md#the-strategy-decides). vfox does not
install what the file names, so install it once:

```bash
vfox install "nodejs@$(tr -d '[:space:]' < .nvmrc)"
```

```powershell
vfox install "nodejs@$((Get-Content .nvmrc -TotalCount 1).Trim())"
```

`v22.23.4` works, as vfox drops the `v`, and so does `22`, which installs the
newest 22.x. `lts/*` and the other `.nvmrc` names do not: the install ends with
`version not found for provided version lts/*`.

The `.nvmrc` is applied at every prompt in the project directory, so a `cd` into
it switches, and leaving it for one with no config at all switches back on
vfox 1.1.0 and later (on older vfox it does not switch back), see
[Several projects in one shell](#several-projects-in-one-shell). If the
repository should not get a vfox file, `vfox use --project` still gives you a
`.vfox.toml` for yourself, which switches in both directions. Put `.vfox.toml`
and `.vfox/` in `.git/info/exclude`, and run `vfox config gitignore.enable
false` (for all projects) so that vfox does not add `.vfox/` to the
`.gitignore` that the repository tracks.

### Writing the file from Windows PowerShell 5.1

Windows PowerShell 5.1 writes UTF-16 for `>`, `>>` and `Out-File`, UTF-8 with a
byte order mark for `-Encoding UTF8`, and the ANSI code page for `Set-Content`
without `-Encoding`, which is plain text for a release number
([about_Character_Encoding](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_character_encoding)).
The plugin decodes UTF-16 and drops the mark before it reads the text. The table
gives the first bytes of each file and what a directory holding it selected,
with 22.23.4 installed and the default strategy:

| The file starts with | Written by Windows PowerShell 5.1 with | Selected |
| --- | --- | --- |
| `32 32 2e 32 33 2e 34 0d 0a` | `Set-Content .nvmrc 22.23.4 -Encoding ascii`, or `Set-Content .nvmrc 22.23.4` | 22.23.4 |
| `ef bb bf 32 32 2e ...` | `Set-Content .nvmrc 22.23.4 -Encoding UTF8` | 22.23.4 |
| `ff fe 32 00 32 00 2e 00 ...` | `'22.23.4' > .nvmrc`, `'22.23.4' \| Out-File .nvmrc` | 22.23.4 |

The bytes were written on Linux and tried there. What Windows PowerShell writes
is from Microsoft's documentation. PowerShell 7 writes UTF-8 without a mark for
all of these, which the plugin reads as plain text. This one works everywhere:

```powershell
Set-Content -Path .nvmrc -Value '22.23.4' -Encoding ascii
```

## Several projects in one shell

A legacy API on Node.js 18, a web application on 24, and everything else on the
global 26. In a hooked shell, `cd` between them. This is what `node -v` printed
at each step of one shell, with 18.20.8, 24.22.2 and 26.13.0 installed and
26.13.0 as the global release, on vfox 1.1.0 (bash 5.3):

| Step | `node -v` |
| --- | --- |
| The shell starts in a directory with no config at all | v26.13.0 |
| `cd` into a directory with a `.nvmrc` that names 18.20.8 | v18.20.8 |
| `cd` into a directory with a `.node-version` that names 24.22.2 | v24.22.2 |
| `cd` into a directory with no config at all | v26.13.0 |
| `cd` into a directory with a `.vfox.toml` that names 18.20.8 | v18.20.8 |
| `cd` into a directory with a `.vfox.toml` that names 24.22.2 | v24.22.2 |
| `cd` into a directory with no config at all | v26.13.0 |

- **`.vfox.toml`** switches on every `cd`, and back to the global release when
  you leave for a directory with no config.
- **`.nvmrc` and `.node-version`** are read at every prompt in their directory
  on vfox 1.1.0 and later. A `cd` from one such directory into another
  switches, editing the file takes effect at the next prompt, and leaving for
  a directory with no config at all switches back to the global release. On
  vfox before 1.1.0 the file only applies when a shell starts in its
  directory.
- **Leaving** a directory with such a file for one with no config at all on
  vfox before 1.1.0 does not switch back: the shell keeps the release it had.
  Upgrade vfox to 1.1.0 or later.

Why is in [nvmrc.md](nvmrc.md#when-the-file-is-read): vfox keeps the result of
its first calculation for the shell, and only vfox 1.1.0 and later tracks
version files. So:

- For projects that you move between in one shell on vfox before 1.1.0,
  `.vfox.toml` is the one that works in both directions: `vfox use --project
  nodejs@18.20.8` in each of them. On vfox 1.1.0 and later a `.nvmrc` works in
  both directions too.
- A `.nvmrc` is enough where a shell starts in the directory: the terminal of
  your editor, a new tab in the same folder, a script. The Windows e2e suite of
  this repository starts a new shell for each directory, so a `cd` in a running
  Windows shell is not part of it.

## Another release in this window only

You want to run the tests on 26 and leave everything else as it is:

```powershell
vfox use --session nodejs@26
node -v                      # v26.13.0
vfox current nodejs          # -> v26.13.0
```

The choice takes effect at the next prompt, which is right after the command.
Close the window and it is gone, and a new window has the global release again.
Nothing is written in the project. In a directory whose `.vfox.toml` names
`nodejs`, that file wins over `--session`, and a `.nvmrc` wins over a plain
`vfox use`, see [nvmrc.md](nvmrc.md#using-it).

## Run a command on a given release

`vfox exec` runs one command with a release you name. It changes no scope,
writes no file in the project and needs no hook. That makes it the tool for a
shell without the hook, such as a Dockerfile, a CI job or a scheduled task,
which vfox's own [FAQ](https://vfox.dev/guides/faq.html) recommends.

```bash
vfox exec nodejs@22.23.4 -- node -v           # v22.23.4
vfox exec nodejs@22.23.4 -- npm test
for v in 20.20.2 22.23.4 24.22.2; do vfox exec "nodejs@$v" -- node -v; done
```

```powershell
foreach ($v in '20.20.2', '22.23.4', '24.22.2') { vfox exec "nodejs@$v" -- node -v }
```

The three releases printed `v20.20.2`, `v22.23.4` and `v24.22.2`, in bash and in
PowerShell 7. What to know:

- **Give the whole release number.** `vfox exec` does not read `22` the way
  `vfox use` does, and fails:

  ```text
  $ vfox exec nodejs@22 -- node -v
  SDK nodejs@22 not found, installing...
  nodejs@22.23.4 is already installed
  failed to get runtime package for nodejs@22: open /home/me/.vfox/cache/nodejs/v-22: no such file or directory
  ```

- **A release that is not installed is installed first**, with the same check of
  its SHA-256 sum, and then runs the command. A typo gets the same treatment and
  ends where an install does: `nodejs@22.99.0` answers `get checksum failed:
  HTTP 404 from https://nodejs.org/dist/v22.99.0/SHASUMS256.txt`.
- **The exit status of the command is vfox's.** `vfox exec nodejs@22.23.4 --
  node -e "process.exit(3)"` prints `exit status 3` and exits with 3, so a loop
  or a CI step fails when a test fails.
- **No release means the configured one.** `vfox exec nodejs -- node -v` uses
  what the project, the session and the global scope say.
- **On Windows, name the program the way it is on disk**, `node.exe` or
  `npm.cmd`. `vfox exec` looks for the name you give in the directory of the
  release. This is from vfox's source and was not run on Windows.

## Follow a line or pin a release

Node.js ships fixes as new releases of a line, 24.22.1 and then 24.22.2. A
project either stays on a release or follows its line.

- **Pin.** A full release in `.vfox.toml` or `.nvmrc`. Everyone runs the same
  Node.js until someone changes the file. To move on: `vfox install nodejs@24`
  installs the newest 24.x (`nodejs@24.22.2 is already installed` when you have
  it), and `vfox use --project nodejs@24` writes the release it chose into
  `.vfox.toml`, `nodejs = "24.22.2"`.
- **Follow.** `24` in a `.nvmrc`, with `vfox config legacyVersionFile.strategy
  latest_installed`. A new 24.x is picked up on every machine that installs it,
  and machines can differ for a while. See
  [nvmrc.md](nvmrc.md#the-strategy-decides).

Global packages do not move to the new release. List them before you switch,
and install them again afterwards. Each release has its own:

```text
$ npm ls -g --depth=0
/home/me/.vfox/cache/nodejs/v-22.23.4/nodejs-22.23.4/lib
├── corepack@0.36.0
├── npm@10.9.9
└── semver@7.8.6
$ vfox exec nodejs@24.22.2 -- npm ls -g --depth=0
/home/me/.vfox/cache/nodejs/v-24.22.2/nodejs-24.22.2/lib
├── corepack@0.36.0
└── npm@11.19.1
```

`vfox uninstall nodejs@24.22.1` removes the old release with its global
packages. On Linux a release takes 157 to 225 MB, from 18.20.8 to 26.13.0. See
[versions.md](versions.md#installed-names) for the names `uninstall` takes.

## Behind a firewall or a corporate proxy

Node.js archives and npm packages come from two places, and each has its own
setting:

```bash
export VFOX_NODEJS_MIRROR="https://npmmirror.com/mirrors/node"
npm config set registry https://registry.npmmirror.com
```

```powershell
[Environment]::SetEnvironmentVariable("VFOX_NODEJS_MIRROR", "https://npmmirror.com/mirrors/node", "User")
npm config set registry https://registry.npmmirror.com
```

The first line of PowerShell sets the variable for your user, for the terminals
that you open afterwards. A mirror that your company serves works the same way
if it has the layout of `nodejs.org/dist`. A proxy is set with `vfox config
proxy.enable true` and `vfox config proxy.url <address>`. Both are explained in
[mirror.md](mirror.md) and [troubleshooting.md](troubleshooting.md#network).

A mirror can be behind its own `index.json`. On 2026-11-03 npmmirror listed
26.13.0 and had no `SHASUMS256.txt` for it, so `nodejs@26` failed there while
`nodejs@24` worked:

```text
get checksum failed: HTTP 404 from https://npmmirror.com/mirrors/node/v26.13.0/SHASUMS256.txt
```

Install the release before it (`nodejs@26.12.1`), or try again later.

## Editors and IDEs

- To follow your global choice, point the editor or the build tool at
  `~/.vfox/sdks/nodejs/bin/node`, on Windows at
  `%USERPROFILE%\.vfox\sdks\nodejs\node.exe`. For a fixed release use the path
  of the release, `~/.vfox/cache/nodejs/v-22.23.4/nodejs-22.23.4/bin/node`. See
  [npm.md](npm.md#where-the-files-are).
- An editor that you start from the Start menu runs no hook. On Windows it still
  finds the global `node` through the `Path` that `vfox use --global` wrote, see
  [Windows PowerShell 5.1](#windows-powershell-51). The terminal inside the
  editor runs your profile, so the hook, a `.vfox.toml` and the `.nvmrc` of the
  folder it opens in apply there.
- For a task that has to run on one release, use `vfox exec`. In
  `.vscode/tasks.json` that is `"command": "vfox"` with `"args": ["x",
  "nodejs@22.23.4", "--", "node", "${file}"]`.
