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

function UTIL.getBaseUrl()
    local mirror = os.getenv("VFOX_NODEJS_MIRROR")
    if mirror == "" or mirror == nil then
        return "https://nodejs.org/dist"
    end
    -- Strip trailing slash to avoid double slashes in URL paths
    return mirror:gsub("/$", "")
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

--- Name of the system package providing libstdc++.so.6, picked by probing
--- the distribution (Alpine, OpenWrt).
function UTIL.libstdcxx_hint()
    if UTIL.file_exists("/etc/alpine-release") or UTIL.file_exists("/sbin/apk") or UTIL.file_exists("/usr/bin/apk") then
        return "the libstdc++ system package"
    end
    if
        UTIL.file_exists("/etc/openwrt_release")
        or UTIL.file_exists("/bin/opkg")
        or UTIL.file_exists("/usr/bin/opkg")
    then
        return "the libstdcpp system package"
    end
    return "the libstdc++ system package (libstdcpp on OpenWrt)"
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
