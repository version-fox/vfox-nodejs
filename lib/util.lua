-- Copyright 2026 Han Li and contributors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local UTIL = {}

UTIL.NodeBaseUrl = "/v%s/"
UTIL.FileName = "node-v%s-%s-%s%s"
UTIL.VersionSourceUrl = "/index.json"
UTIL.UnofficialBaseUrl = "https://unofficial-builds.nodejs.org/download/release"
UTIL.ReadmeUrl = "https://github.com/version-fox/vfox-nodejs/blob/main/README.md"
UTIL.PnpmDocUrl = "https://github.com/version-fox/vfox-nodejs/blob/main/docs/pnpm.md"

function UTIL.getBaseUrl()
    local mirror = os.getenv("VFOX_NODEJS_MIRROR")
    if mirror == "" or mirror == nil then
        return "https://nodejs.org/dist"
    end
    -- Strip trailing slashes to avoid double slashes in URL paths. The
    -- parentheses keep gsub's second result (the count) out of the return.
    return (mirror:gsub("/+$", ""))
end

--- Headers that vfox sends with the download of the package. Without them vfox
--- identifies itself with the User-Agent of Go's HTTP client,
--- `Go-http-client/1.1`, and Huawei Cloud, TUNA, USTC and BFSU answer that with
--- an error page, or with nothing, in place of the package: vfox saves the
--- answer and the install ends in `checksum error`. The requests of the plugin
--- itself carry the User-Agent that vfox builds for it, `vfox/<vfox version>
--- vfox-nodejs/<plugin version>`, which all the mirrors of docs/mirror.md
--- serve, so the download sends the same.
--- @return table<string, string>
function UTIL.download_headers()
    local agent = "vfox-" .. ((PLUGIN ~= nil and PLUGIN.name) or "nodejs")
    if PLUGIN ~= nil and PLUGIN.version ~= nil then
        agent = agent .. "/" .. PLUGIN.version
    end
    if RUNTIME ~= nil and RUNTIME.version ~= nil and RUNTIME.version ~= "" then
        agent = "vfox/" .. RUNTIME.version .. " " .. agent
    end
    return { ["User-Agent"] = agent }
end

function UTIL.file_exists(path)
    local f = io.open(path, "rb")
    if f then
        f:close()
        return true
    end
    return false
end

--- Detect musl libc on Linux (Alpine, OpenWrt/ImmortalWrt, ...).
--- Order: explicit $VFOX_NODEJS_LIBC override, future RUNTIME.envType,
--- then well-known linker/marker files. musl wins when both linkers exist
--- (e.g. gcompat shims on Alpine). Non-Linux is never musl.
--- See https://github.com/version-fox/vfox-nodejs/issues/29
function UTIL.is_musl()
    local override = os.getenv("VFOX_NODEJS_LIBC")
    if override == "musl" then
        return true
    end
    if override == "gnu" or override == "glibc" then
        return false
    end
    if RUNTIME ~= nil and RUNTIME.envType ~= nil then
        return RUNTIME.envType == "musl"
    end
    if RUNTIME ~= nil and RUNTIME.osType ~= nil and RUNTIME.osType ~= "linux" then
        return false
    end
    if UTIL.file_exists("/etc/alpine-release") then
        return true
    end
    local musl_paths = {
        "/lib/ld-musl-x86_64.so.1",
        "/usr/lib/ld-musl-x86_64.so.1",
        "/lib64/ld-musl-x86_64.so.1",
        "/lib/ld-musl-aarch64.so.1",
        "/usr/lib/ld-musl-aarch64.so.1",
        "/lib64/ld-musl-aarch64.so.1",
        "/lib/ld-musl-armhf.so.1",
        "/usr/lib/ld-musl-armhf.so.1",
        "/lib/ld-musl-x86.so.1",
        "/usr/lib/ld-musl-x86.so.1",
    }
    for _, p in ipairs(musl_paths) do
        if UTIL.file_exists(p) then
            return true
        end
    end
    return false
end

--- Whether libstdc++.so.6 is visible at a well-known location.
--- Node.js musl tarballs fail with `Error relocating ... symbol not found`
--- when it is missing.
function UTIL.has_libstdcxx()
    local lib_paths = {
        "/usr/lib/libstdc++.so.6",
        "/lib/libstdc++.so.6",
        "/usr/lib64/libstdc++.so.6",
        "/lib64/libstdc++.so.6",
        "/usr/lib/x86_64-linux-gnu/libstdc++.so.6",
        "/lib/x86_64-linux-gnu/libstdc++.so.6",
        "/usr/lib/aarch64-linux-gnu/libstdc++.so.6",
        "/lib/aarch64-linux-gnu/libstdc++.so.6",
        "/usr/lib/arm-linux-gnueabihf/libstdc++.so.6",
        "/lib/arm-linux-gnueabihf/libstdc++.so.6",
    }
    for _, p in ipairs(lib_paths) do
        if UTIL.file_exists(p) then
            return true
        end
    end
    return false
end

--- System packages that provide the shared libraries the Node.js musl builds
--- link, by their Alpine (apk) and OpenWrt (opkg) names. libatomic is linked
--- by the musl builds of 26.8.0 and later, the others by every one.
UTIL.MuslLibraries = {
    ["libstdc++.so.6"] = { apk = "libstdc++", opkg = "libstdcpp" },
    ["libatomic.so.1"] = { apk = "libatomic", opkg = "libatomic" },
    ["libgcc_s.so.1"] = { apk = "libgcc", opkg = "libgcc" },
}

--- "apk" on Alpine, "opkg" on OpenWrt and ImmortalWrt, nil on anything else,
--- picked by probing the distribution.
--- @return string|nil
function UTIL.package_manager()
    if UTIL.file_exists("/etc/alpine-release") or UTIL.file_exists("/sbin/apk") or UTIL.file_exists("/usr/bin/apk") then
        return "apk"
    end
    if
        UTIL.file_exists("/etc/openwrt_release")
        or UTIL.file_exists("/bin/opkg")
        or UTIL.file_exists("/usr/bin/opkg")
    then
        return "opkg"
    end
    return nil
end

--- Phrase naming the system package that provides a shared library, such as
--- "the libatomic system package". Falls back to the library itself.
--- @param soname string e.g. "libatomic.so.1"
--- @return string
function UTIL.library_package_hint(soname)
    local package = UTIL.MuslLibraries[soname]
    if package == nil then
        return "the " .. soname .. " shared library"
    end
    local manager = UTIL.package_manager()
    if manager == "apk" or (manager == nil and package.apk == package.opkg) then
        return "the " .. package.apk .. " system package"
    end
    if manager == "opkg" then
        return "the " .. package.opkg .. " system package"
    end
    return "the " .. package.apk .. " system package (" .. package.opkg .. " on OpenWrt)"
end

--- Command that installs the package providing a shared library, nil when the
--- distribution or the library is not known.
--- @param soname string e.g. "libatomic.so.1"
--- @return string|nil
function UTIL.install_command(soname)
    local package = UTIL.MuslLibraries[soname]
    local manager = UTIL.package_manager()
    if package == nil or manager == nil then
        return nil
    end
    if manager == "apk" then
        return "apk add " .. package.apk
    end
    return "opkg install " .. package.opkg
end

--- Quote a string as one word for a POSIX shell.
--- @param text string
--- @return string
function UTIL.shell_quote(text)
    return "'" .. text:gsub("'", "'\\''") .. "'"
end

--- Run a shell command and capture what it prints, stderr included.
--- @param command string
--- @return string|nil output nil when no command can be run here
--- @return number|nil status the exit status, when the runtime reports one
function UTIL.capture(command)
    if type(io.popen) ~= "function" then
        return nil, nil
    end
    local started, handle = pcall(io.popen, command .. " 2>&1")
    if not started or not handle then
        return nil, nil
    end
    local output = handle:read("*a") or ""
    -- vfox's Lua returns the exit status here, standard Lua `true` or nil.
    --- @type boolean|number|nil
    local closed = handle:close()
    if closed == true then
        return output, 0
    end
    if type(closed) == "number" then
        return output, closed
    end
    return output, nil
end

--- A Unicode code point as UTF-8.
--- @param code number
--- @return string
local function utf8_char(code)
    if code < 0x80 then
        return string.char(code)
    elseif code < 0x800 then
        return string.char(0xC0 + math.floor(code / 0x40), 0x80 + code % 0x40)
    elseif code < 0x10000 then
        return string.char(0xE0 + math.floor(code / 0x1000), 0x80 + math.floor(code / 0x40) % 0x40, 0x80 + code % 0x40)
    end
    return string.char(
        0xF0 + math.floor(code / 0x40000),
        0x80 + math.floor(code / 0x1000) % 0x40,
        0x80 + math.floor(code / 0x40) % 0x40,
        0x80 + code % 0x40
    )
end

--- The text of a version file as UTF-8 without a byte order mark. Windows
--- PowerShell 5.1 writes UTF-16 with a mark for `>`, `>>` and `Out-File`, and
--- UTF-8 with a mark for `-Encoding UTF8`. Read as they are, the mark and the
--- zero bytes of UTF-16 become part of the text, and no release matches it.
--- Text that starts with no mark is returned as it is.
--- @param content string the bytes of the file
--- @return string
function UTIL.decode_text(content)
    if content:sub(1, 3) == "\239\187\191" then
        return content:sub(4)
    end
    local first, second = content:byte(1, 2)
    local little_endian
    if first == 0xFF and second == 0xFE then
        little_endian = true
    elseif first == 0xFE and second == 0xFF then
        little_endian = false
    else
        return content
    end
    --- The 16-bit unit at a position, nil when only one byte is left.
    local function unit_at(position)
        local low, high = content:byte(position, position + 1)
        if high == nil then
            return nil
        end
        if little_endian then
            return low + high * 256
        end
        return low * 256 + high
    end
    local chars = {}
    local position = 3
    while position < #content do
        -- Two bytes are there, so the replacement character is never used.
        local unit = unit_at(position) or 0xFFFD
        position = position + 2
        if unit >= 0xD800 and unit <= 0xDBFF then
            -- A high surrogate needs a low one after it, else it is an error.
            local low = unit_at(position)
            if low ~= nil and low >= 0xDC00 and low <= 0xDFFF then
                unit = 0x10000 + (unit - 0xD800) * 0x400 + (low - 0xDC00)
                position = position + 2
            else
                unit = 0xFFFD
            end
        elseif unit >= 0xDC00 and unit <= 0xDFFF then
            unit = 0xFFFD
        end
        table.insert(chars, utf8_char(unit))
    end
    return table.concat(chars)
end

--- The LTS lines that the plugin knows without having seen the index. Node.js
--- names each line when it enters long-term support. This is the cold-start
--- fallback of ParseLegacyFile: what the plugin learns from the index (see
--- UTIL.remember_lts) goes before it, so the next line needs no entry here.
UTIL.LtsLines = {
    argon = 4,
    boron = 6,
    carbon = 8,
    dubnium = 10,
    erbium = 12,
    fermium = 14,
    gallium = 16,
    hydrogen = 18,
    iron = 20,
    jod = 22,
    krypton = 24,
    lithium = 26,
}

--- How long what the plugin learned counts as fresh when an install looks at it.
UTIL.LtsCacheMaxAge = 24 * 60 * 60

--- The directory of this plugin. vfox puts the plugin's `hooks/?.lua` and
--- `lib/?.lua` into `package.path`, so it is where `lib/util.lua` is found.
--- @return string|nil dir nil when package.path does not tell
--- @return string|nil separator the one that package.path uses
function UTIL.plugin_dir()
    for template in string.gmatch(package.path or "", "[^;]+") do
        local candidate = (template:gsub("%?", "util"))
        local dir = candidate:match("^(.*)[/\\]lib[/\\]util%.lua$")
        if dir ~= nil and UTIL.file_exists(candidate) then
            local separator = "/"
            if candidate:find("\\", 1, true) ~= nil then
                separator = "\\"
            end
            return dir, separator
        end
    end
    return nil, nil
end

--- The file in which the plugin keeps what it learned about LTS lines, next to
--- the `.available.cache` that vfox keeps there for the result of Available.
--- @return string|nil
function UTIL.lts_cache_path()
    local dir, separator = UTIL.plugin_dir()
    if dir == nil then
        return nil
    end
    return dir .. separator .. ".lts-cache"
end

--- What the version index says about LTS lines: the major of each named line,
--- and the newest major that is LTS at all. A release whose `lts` is `true`
--- (an LTS line without a name) counts for the newest only.
--- @param index any the decoded index.json: a list of releases
--- @return table { lines = { [codename] = major }, newest = major|nil }
function UTIL.lts_summary(index)
    local lines = {}
    local newest = nil
    if type(index) ~= "table" then
        return { lines = lines }
    end
    for _, release in ipairs(index) do
        if type(release) == "table" and release.version ~= nil then
            local lts = release.lts
            local name = nil
            if type(lts) == "string" and lts:match("^[%w%-]+$") ~= nil then
                name = lts:lower()
            end
            local major = tonumber(tostring(release.version):match("^v?(%d+)%."))
            if major ~= nil and (name ~= nil or lts == true) then
                if newest == nil or major > newest then
                    newest = major
                end
                if name ~= nil and (lines[name] == nil or major > lines[name]) then
                    lines[name] = major
                end
            end
        end
    end
    return { lines = lines, newest = newest }
end

--- Write what the plugin learned. The file is plain text, one fact per line:
--- `updated <time>`, `newest <major>` and `line <codename> <major>`.
--- Best effort: a directory that cannot be written is no error. The new file
--- is written beside the old one and renamed over it, so a reader never sees half.
--- @param summary table from UTIL.lts_summary
--- @return boolean written
function UTIL.write_lts_cache(summary)
    local path = UTIL.lts_cache_path()
    if path == nil or (summary.newest == nil and next(summary.lines) == nil) then
        return false
    end
    local names = {}
    for name in pairs(summary.lines) do
        table.insert(names, name)
    end
    table.sort(names)
    local text =
        { "# What vfox-nodejs learned from index.json about LTS lines. Safe to delete.", "updated " .. os.time() }
    if summary.newest ~= nil then
        table.insert(text, "newest " .. summary.newest)
    end
    for _, name in ipairs(names) do
        table.insert(text, "line " .. name .. " " .. summary.lines[name])
    end
    local temporary = path .. ".tmp"
    local file = io.open(temporary, "w")
    if file == nil then
        return false
    end
    local wrote = pcall(file.write, file, table.concat(text, "\n") .. "\n")
    file:close()
    if not wrote or not os.rename(temporary, path) then
        pcall(os.remove, temporary)
        return false
    end
    return true
end

--- Learn from an index that the plugin has fetched anyway. Never fails.
--- @param index any the decoded index.json
function UTIL.remember_lts(index)
    pcall(function()
        UTIL.write_lts_cache(UTIL.lts_summary(index))
    end)
end

--- What the plugin learned, nil when there is no file to read.
--- @return table|nil { lines = { [codename] = major }, newest = major|nil, updated = time }
function UTIL.read_lts_cache()
    local path = UTIL.lts_cache_path()
    if path == nil then
        return nil
    end
    local file = io.open(path, "r")
    if file == nil then
        return nil
    end
    local text = file:read("*a") or ""
    file:close()
    local learned = { lines = {}, updated = 0 }
    -- A file this size is not ours. Read nothing of it.
    if #text > 65536 then
        return learned
    end
    for line in string.gmatch(text, "[^\r\n]+") do
        local updated = line:match("^updated (%d+)$")
        local newest = line:match("^newest (%d+)$")
        local name, major = line:match("^line ([%w%-]+) (%d+)$")
        if updated ~= nil then
            learned.updated = tonumber(updated)
        elseif newest ~= nil then
            learned.newest = tonumber(newest)
        elseif name ~= nil then
            learned.lines[name] = tonumber(major)
        end
    end
    return learned
end

--- The LTS lines the plugin knows: what it learned, over the built-in table.
--- @return table lines { [codename] = major }
--- @return number newest the highest major of an LTS line, 0 when none is known
function UTIL.known_lts_lines()
    local lines = {}
    local newest = 0
    for name, major in pairs(UTIL.LtsLines) do
        lines[name] = major
        newest = math.max(newest, major)
    end
    local learned = UTIL.read_lts_cache()
    if learned ~= nil then
        for name, major in pairs(learned.lines) do
            lines[name] = major
            newest = math.max(newest, major)
        end
        newest = math.max(newest, learned.newest or 0)
    end
    return lines, newest
end

--- Learn about LTS lines at an install, which is when a new line is about to
--- matter, unless that happened less than a day ago or the file could not be
--- written anyway. An exact release such as `26.13.0` is installed without
--- Available, so nothing else would refresh the file then. Available fetches the
--- index and remembers it; a failure is ignored.
--- @param plugin table PLUGIN
function UTIL.refresh_lts_cache(plugin)
    local learned = UTIL.read_lts_cache()
    if learned ~= nil and learned.updated > 0 then
        local age = os.time() - learned.updated
        if age >= 0 and age < UTIL.LtsCacheMaxAge then
            return
        end
    end
    local path = UTIL.lts_cache_path()
    if path == nil then
        return
    end
    local probe = io.open(path .. ".tmp", "w")
    if probe == nil then
        return
    end
    probe:close()
    pcall(os.remove, path .. ".tmp")
    pcall(plugin.Available, plugin, {})
end

--- Whether the running vfox understands PLUGIN.shadowHints (v1.1.0 and later).
--- Older vfox ignores the metadata field, so PreUse keeps printing its own
--- Note there. Unknown or empty RUNTIME.version counts as old.
--- See https://github.com/version-fox/vfox/issues/737
--- @return boolean
function UTIL.supports_shadow_hints()
    if RUNTIME == nil or RUNTIME.version == nil or RUNTIME.version == "" then
        return false
    end
    local cleaned = tostring(RUNTIME.version):gsub("^v", ""):match("^[^%-%+]+")
    if cleaned == nil then
        return false
    end
    local parts = {}
    for part in string.gmatch(cleaned .. ".", "([^.]*)%.") do
        -- Drop an empty segment such as the trailing one of "1.1."; anything
        -- else must be a number, otherwise the version is unreadable.
        if part == "" then
            return false
        end
        if not part:match("^%d+$") then
            return false
        end
        table.insert(parts, tonumber(part))
    end
    local want = { 1, 1, 0 }
    for i = 1, math.max(#parts, #want) do
        local got = parts[i] or 0
        local need = want[i] or 0
        if got > need then
            return true
        end
        if got < need then
            return false
        end
    end
    return true
end

--- Home directory of the user vfox runs as, nil when it cannot be told.
--- @return string|nil
function UTIL.home_dir()
    local windows = RUNTIME ~= nil and RUNTIME.osType == "windows"
    if windows then
        local profile = os.getenv("USERPROFILE")
        if profile ~= nil and profile ~= "" then
            return profile
        end
        local drive, folder = os.getenv("HOMEDRIVE"), os.getenv("HOMEPATH")
        if drive ~= nil and drive ~= "" and folder ~= nil and folder ~= "" then
            return drive .. folder
        end
        return nil
    end
    local home = os.getenv("HOME")
    if home == nil or home == "" then
        return nil
    end
    return home
end

--- Entry names of a directory, without `.` and `..`. A directory that cannot
--- be read gives nothing, so a manager that is not installed simply
--- contributes no candidates.
--- @param dir string|nil
--- @return string[]
function UTIL.list_dir(dir)
    if dir == nil or dir == "" then
        return {}
    end
    local windows = RUNTIME ~= nil and RUNTIME.osType == "windows"
    local command
    if windows then
        command = 'dir /b "' .. dir:gsub('"', '""') .. '"'
    else
        command = "ls -1 " .. UTIL.shell_quote(dir)
    end
    local output, status = UTIL.capture(command)
    if output == nil or (status ~= nil and status ~= 0) then
        return {}
    end
    local names = {}
    for line in string.gmatch(output, "[^\r\n]+") do
        local name = line:gsub("%s+$", "")
        if name ~= "" and name ~= "." and name ~= ".." then
            table.insert(names, name)
        end
    end
    return names
end

--- Parent directories whose subdirectories are one installed Node.js each,
--- with the manager each belongs to. Shim directories are never listed: a
--- shim selects its version per directory, so linking one selects nothing
--- stable, and pnpm's shim ships no npm at all.
--- @return table[] { dir: string, source: string }
function UTIL.detect_roots()
    local windows = RUNTIME ~= nil and RUNTIME.osType == "windows"
    local roots = {}
    local function add(dir, source)
        if dir ~= nil and dir ~= "" then
            table.insert(roots, { dir = dir, source = source })
        end
    end
    if windows then
        local localappdata = os.getenv("LOCALAPPDATA")
        if localappdata ~= nil and localappdata ~= "" then
            add(localappdata .. "\\mise\\installs\\node", "mise")
        end
        local appdata = os.getenv("APPDATA")
        if appdata ~= nil and appdata ~= "" then
            add(appdata .. "\\nvm", "nvm")
        end
        local nvm_home = os.getenv("NVM_HOME")
        if nvm_home ~= nil and nvm_home ~= "" then
            add(nvm_home, "nvm")
        end
    else
        local home = UTIL.home_dir()
        if home ~= nil then
            add(home .. "/.nvm/versions/node", "nvm")
            local mise_data = os.getenv("MISE_DATA_DIR")
            if mise_data ~= nil and mise_data ~= "" then
                add(mise_data .. "/installs/node", "mise")
            else
                add(home .. "/.local/share/mise/installs/node", "mise")
            end
            local asdf_data = os.getenv("ASDF_DATA_DIR")
            if asdf_data ~= nil and asdf_data ~= "" then
                add(asdf_data .. "/installs/nodejs", "asdf")
            else
                add(home .. "/.asdf/installs/nodejs", "asdf")
            end
        end
        add("/opt/homebrew/Cellar/node", "homebrew")
        add("/usr/local/Cellar/node", "homebrew")
        add("/home/linuxbrew/.linuxbrew/Cellar/node", "homebrew")
    end
    return roots
end

--- Run `<node> --version` and read the release it prints, nil when it is not
--- a working `node` of one release.
--- @param node string path of the executable
--- @return string|nil version like "22.14.0"
local function node_release(node)
    local windows = RUNTIME ~= nil and RUNTIME.osType == "windows"
    local command
    if windows then
        command = '"' .. node:gsub('"', '""') .. '" --version'
    else
        command = UTIL.shell_quote(node) .. " --version"
    end
    local output = UTIL.capture(command)
    if output == nil then
        return nil
    end
    local version = tostring(output):match("v(%d+%.%d+%.%d+)")
    if version ~= nil and UTIL.is_semver_simple(version) then
        return version
    end
    return nil
end

--- Node.js installs on this machine that vfox did not install, one entry per
--- release: `{ version, path, note }`. `path` is the directory EnvKeys
--- expects (holding `bin/` on Linux and macOS, `node.exe` on Windows) and
--- `version` is the plain release number the binary reports, so
--- `vfox use 22` keeps working and vfox skips what is installed already.
--- Shims, pnpm's global runtime and copies without a versioned home (such as
--- a manual `/usr/local/bin/node`) are not reported; link those by hand.
--- The winget directory reports its version by running it.
--- See https://github.com/version-fox/vfox/issues/737
--- @return table[]
function UTIL.detect_nodejs()
    local windows = RUNTIME ~= nil and RUNTIME.osType == "windows"
    local found = {}
    local seen = {}
    local function consider(install_dir, source)
        local path, node
        if windows then
            if UTIL.file_exists(install_dir .. "\\node.exe") then
                path, node = install_dir, install_dir .. "\\node.exe"
            elseif UTIL.file_exists(install_dir .. "\\bin\\node.exe") then
                path, node = install_dir .. "\\bin", install_dir .. "\\bin\\node.exe"
            else
                return
            end
        else
            if not UTIL.file_exists(install_dir .. "/bin/node") then
                return
            end
            path, node = install_dir, install_dir .. "/bin/node"
        end
        local version = node_release(node)
        if version == nil or seen[version] then
            return
        end
        seen[version] = true
        table.insert(found, { version = version, path = path, note = source })
    end
    for _, root in ipairs(UTIL.detect_roots()) do
        local sep = windows and "\\" or "/"
        for _, name in ipairs(UTIL.list_dir(root.dir)) do
            consider(root.dir .. sep .. name, root.source)
        end
    end
    if windows then
        local program_files = os.getenv("ProgramFiles")
        if program_files == nil or program_files == "" then
            program_files = "C:\\Program Files"
        end
        consider(program_files .. "\\nodejs", "winget")
    end
    return found
end

--- Whether a PATH entry belongs to vfox: like vfox's own check, one of its
--- segments is `.vfox` (or the legacy `.version-fox`).
local function is_vfox_path(dir)
    for segment in string.gmatch(dir, "[^/\\]+") do
        if segment == ".vfox" or segment == ".version-fox" then
            return true
        end
    end
    return false
end

--- First `node` that `vfox env` keeps ahead of the SDK paths. vfox leaves
--- PATH entries before its first own path in front, as user-injected (so an
--- activated virtualenv keeps priority); a `node` there, such as the one
--- `pnpm runtime set node -g` writes to `$PNPM_HOME/bin`, shadows the
--- version `vfox use` selects. With no vfox path on PATH yet, vfox puts its
--- paths first and nothing shadows them.
--- Legacy path for vfox before 1.1.0: that vfox has no PLUGIN.shadowHints,
--- so PreUse prints the Note itself. vfox 1.1.0 and later warns itself and
--- appends the plugin's shadowHints, and PreUse stays quiet.
--- See https://github.com/version-fox/vfox-nodejs/blob/main/docs/pnpm.md
--- @return string|nil path of the shadowing executable
function UTIL.shadowing_node()
    local path = os.getenv("PATH")
    if path == nil or path == "" then
        return nil
    end
    local windows = RUNTIME ~= nil and RUNTIME.osType == "windows"
    local separator = windows and ";" or ":"
    local names = windows and { "\\node.exe", "\\node.cmd" } or { "/node" }
    local ahead = {}
    for dir in string.gmatch(path, "[^" .. separator .. "]+") do
        if is_vfox_path(dir) then
            for _, candidate_dir in ipairs(ahead) do
                for _, name in ipairs(names) do
                    local candidate = (candidate_dir:gsub("[/\\]+$", "")) .. name
                    if UTIL.file_exists(candidate) then
                        return candidate
                    end
                end
            end
            return nil
        end
        table.insert(ahead, dir)
    end
    return nil
end

function UTIL.compare_versions(v1o, v2o)
    local v1 = v1o.version
    local v2 = v2o.version
    local v1_parts = {}
    for part in string.gmatch(v1, "[^.]+") do
        table.insert(v1_parts, tonumber(part))
    end

    local v2_parts = {}
    for part in string.gmatch(v2, "[^.]+") do
        table.insert(v2_parts, tonumber(part))
    end

    for i = 1, math.max(#v1_parts, #v2_parts) do
        local v1_part = v1_parts[i] or 0
        local v2_part = v2_parts[i] or 0
        if v1_part > v2_part then
            return true
        elseif v1_part < v2_part then
            return false
        end
    end

    return false
end

--- The numbers of a release such as "22.23.3". nil unless every part is a
--- number.
--- @param version string
--- @return number[]|nil
function UTIL.version_parts(version)
    if type(version) ~= "string" then
        return nil
    end
    local parts = {}
    for part in string.gmatch(version .. ".", "([^.]*)%.") do
        if not part:match("^%d+$") then
            return nil
        end
        table.insert(parts, tonumber(part))
    end
    return parts
end

--- What a version file asks for, as the numbers a release has to start with:
--- "22" is { 22 }, "22.23" is { 22, 23 }, and "22.x", "22.x.x" and "22.*" are
--- { 22 }. nil for anything else, such as "lts/jod", "node", ">=20" or "x".
--- @param query string
--- @return number[]|nil
function UTIL.version_prefix(query)
    if type(query) ~= "string" then
        return nil
    end
    local prefix = {}
    local wildcard = false
    for part in string.gmatch(query .. ".", "([^.]*)%.") do
        if part == "x" or part == "X" or part == "*" then
            wildcard = true
        elseif wildcard or not part:match("^%d+$") then
            return nil
        else
            table.insert(prefix, tonumber(part))
        end
    end
    if #prefix == 0 then
        return nil
    end
    return prefix
end

--- Whether a release starts with the numbers of a prefix, part by part: "22.23.3"
--- starts with { 22 } and { 22, 23 }, not with { 22, 2 }.
--- @param version string
--- @param prefix number[]
--- @return boolean
function UTIL.version_starts_with(version, prefix)
    local parts = UTIL.version_parts(version)
    if parts == nil or #parts < #prefix then
        return false
    end
    for i, number in ipairs(prefix) do
        if parts[i] ~= number then
            return false
        end
    end
    return true
end

--- The newest release that starts with the prefix, compared as numbers. vfox
--- lists installed releases as text, so "22.9.0" comes before "22.23.3" there.
--- @param versions table|nil releases as text, in any order
--- @param prefix number[]
--- @return string|nil
function UTIL.newest_matching(versions, prefix)
    local newest = nil
    for _, version in pairs(versions or {}) do
        if
            UTIL.version_starts_with(version, prefix)
            and (newest == nil or UTIL.compare_versions({ version = version }, { version = newest }))
        then
            newest = version
        end
    end
    return newest
end

function UTIL.get_checksum(file_content, file_name)
    for line in string.gmatch(file_content, "([^\n]*)\n?") do
        local checksum, name = string.match(line, "(%w+)%s+(%S+)")
        if name == file_name then
            return checksum
        end
    end
    return nil
end

function UTIL.is_semver_simple(str)
    -- match pattern: three digits, separated by dot
    local pattern = "^%d+%.%d+%.%d+$"
    return str:match(pattern) ~= nil
end

function UTIL.extract_semver(semver)
    local pattern = "^(%d+)%.(%d+)%.[%d.]+$"
    local major, minor = semver:match(pattern)
    return major, minor
end

function UTIL.calculate_shorthand(list)
    local versions_shorthand = {}
    for _, v in pairs(list) do
        local version = v.version
        local major, minor = UTIL.extract_semver(version)

        if major then
            if not versions_shorthand[major] then
                versions_shorthand[major] = version
            else
                if UTIL.compare_versions({ version = version }, { version = versions_shorthand[major] }) then
                    versions_shorthand[major] = version
                end
            end

            if minor then
                local major_minor = major .. "." .. minor
                if not versions_shorthand[major_minor] then
                    versions_shorthand[major_minor] = version
                else
                    if UTIL.compare_versions({ version = version }, { version = versions_shorthand[major_minor] }) then
                        versions_shorthand[major_minor] = version
                    end
                end
            end
        end
    end

    return versions_shorthand
end

return UTIL
