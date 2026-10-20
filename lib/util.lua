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
