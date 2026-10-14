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

local http = require("http")
local util = require("util")
--- @class PreInstallContext
--- @field version string User-input version

--- Returns some pre-installed information, such as version number, download address, local files, etc.
--- If checksum is provided, vfox will automatically check it for you.
--- @param ctx PreInstallContext
--- @return table Version information
function PLUGIN:PreInstall(ctx)
    local version = ctx.version

    if version == "latest" then
        local lists = self:Available({})
        version = lists[1].version
    end

    if not util.is_semver_simple(version) then
        local lists = self:Available({})
        local shorthands = util.calculate_shorthand(lists)
        version = shorthands[version]
    end

    if version == nil then
        error("version not found for provided version " .. (ctx.version or "null"))
    end

    local arch_type = RUNTIME.archType
    if arch_type == nil or arch_type == "" then
        error("Cannot determine Node.js package architecture from RUNTIME.archType")
    end
    local ext = ".tar.gz"
    local osType = RUNTIME.osType
    if RUNTIME.archType == "amd64" then
        arch_type = "x64"
    elseif RUNTIME.archType == "386" then
        arch_type = "x86"
    end
    if RUNTIME.osType == "windows" then
        ext = ".zip"
        osType = "win"
    end
    -- add logic for Apple Silicon
    if RUNTIME.osType == "darwin" then
        local major, _ = util.extract_semver(version)
        if major and tonumber(major) < 16 then
            arch_type = "x64"
            print(
                "Note: Node.js versions below 16 do not support Apple Silicon (arm64), using x64 architecture with Rosetta 2"
            )
        end
    end

    local filename = nil
    local baseUrl = util.getBaseUrl() .. util.NodeBaseUrl:format(version)
    local is_musl = false
    local musl_note = nil
    if RUNTIME.osType == "linux" then
        is_musl = util.is_musl()
        if is_musl then
            if arch_type == "x64" then
                arch_type = "x64-musl"
            elseif arch_type == "arm64" then
                arch_type = "arm64-musl"
            else
                error(
                    "Node.js musl builds are only available for x64 and arm64, got "
                        .. tostring(arch_type)
                        .. ". See "
                        .. util.ReadmeUrl
                )
            end
            filename = util.FileName:format(version, osType, arch_type, ext)
            musl_note = "musl libc detected, installed " .. filename .. ". See " .. util.ReadmeUrl
            print("Note: " .. musl_note)
        end
    end
    if filename == nil then
        filename = util.FileName:format(version, osType, arch_type, ext)
    end

    local resp, err = http.get({
        url = baseUrl .. "SHASUMS256.txt",
    })
    if err ~= nil or resp.status_code ~= 200 then
        error("get checksum failed")
    end
    local checksum = util.get_checksum(resp.body, filename)
    if checksum ~= nil then
        local result = {
            version = version,
            url = baseUrl .. filename,
            sha256 = checksum,
        }
        if musl_note ~= nil then
            result.note = musl_note
        end
        return result
    end

    -- musl fallback to unofficial builds: official nodejs.org/dist only ships
    -- linux-x64-musl for recent releases and never ships linux-arm64-musl,
    -- while unofficial-builds covers both (including older releases).
    -- A SHASUMS fetch failure still errors (bogus mirrors must stay rejected);
    -- only a missing filename falls through here.
    -- See https://github.com/version-fox/vfox-nodejs/issues/29
    if is_musl then
        local unofficialBase = util.UnofficialBaseUrl .. util.NodeBaseUrl:format(version)
        local uresp, uerr = http.get({
            url = unofficialBase .. "SHASUMS256.txt",
        })
        if uerr == nil and uresp.status_code == 200 then
            local uchecksum = util.get_checksum(uresp.body, filename)
            if uchecksum ~= nil then
                print("Note: " .. filename .. " is not listed in " .. baseUrl .. ", using unofficial musl build")
                return {
                    version = version,
                    url = unofficialBase .. filename,
                    sha256 = uchecksum,
                    note = musl_note,
                }
            end
        end
    end
    error("Node.js package " .. filename .. " is not listed in " .. baseUrl .. "SHASUMS256.txt")
end
