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

--- Parse the legacy file found by vfox to determine the version of the tool.
--- Useful to extract version numbers from files like JavaScript's package.json or Golangs go.mod.
local http = require("http")
local json = require("json")
local util = require("util")

--- Discover LTS codenames from the version index instead of the hardcoded
--- table below. Only used under the `latest_available` strategy, which is
--- network-bound anyway; `specified` and `latest_installed` must keep
--- working offline. Returns nil when the index cannot be fetched, and the
--- caller falls back to the hardcoded table.
--- @return table|nil { by_codename: map, newest: string|nil }
local function discover_lts()
    local resp, err = http.get({
        url = util.getBaseUrl() .. util.VersionSourceUrl,
    })
    if err ~= nil or resp == nil or resp.status_code ~= 200 then
        return nil
    end
    local ok, body = pcall(json.decode, resp.body)
    if not ok or type(body) ~= "table" then
        return nil
    end
    local found = {}
    local newest = nil
    for _, v in ipairs(body) do
        if type(v) == "table" and v.lts and v.version then
            local name = string.lower(tostring(v.lts))
            local ver = string.gsub(tostring(v.version), "^v", "")
            if found[name] == nil or util.compare_versions({ version = ver }, { version = found[name] }) then
                found[name] = ver
            end
            if newest == nil or util.compare_versions({ version = ver }, { version = newest }) then
                newest = ver
            end
        end
    end
    return { by_codename = found, newest = newest }
end

function PLUGIN:ParseLegacyFile(ctx)
    local filepath = ctx.filepath
    local file = io.open(filepath, "r")
    if file == nil then
        return {}
    end
    local content = file:read("*a") or ""
    file:close()
    content = content:gsub("%s+", "")
    if content == "" then
        return {}
    end
    function resolve_legacy_version(strategy, query)
        local list = {}

        if strategy == "latest_installed" then
            list = ctx.getInstalledVersions()
        elseif strategy == "latest_available" then
            for _, av in pairs(self:Available({})) do
                table.insert(list, av.version)
            end
        else
            -- Just return the original query
            return query
        end

        local resolved = ""
        for _, item in pairs(list) do
            if item:match("^" .. query) then
                resolved = item
                break
            end
        end

        if resolved ~= "" then
            return resolved
        elseif strategy ~= "latest_available" then
            -- If no version is installed, fallback to latest_available
            return resolve_legacy_version("latest_available", query)
        else
            -- Give up and pretty the query itself
            return query
        end
    end
    local query = resolve_version(content, ctx.strategy)

    query = resolve_legacy_version(ctx.strategy, query)

    return {
        version = query,
    }
end

function resolve_version(query, strategy)
    query = string.lower(query:gsub("v", ""))

    if query:match("^lts-") then
        query = query:gsub("-", "/")
    end

    local lts_name = query:match("^lts/(.+)$")
    local is_bare_lts = query == "lts" or query == "lts/*"
    if (lts_name ~= nil or is_bare_lts) and strategy == "latest_available" then
        local discovered = discover_lts()
        if discovered ~= nil then
            if is_bare_lts and discovered.newest ~= nil then
                return discovered.newest
            end
            if lts_name ~= nil and discovered.by_codename[lts_name] ~= nil then
                return discovered.by_codename[lts_name]
            end
        end
    end

    -- Offline fallback below: the hardcoded table keeps `specified` and
    -- `latest_installed` working without network. It also covers
    -- `latest_available` when discovery finds no match.
    -- https://nodejs.org/zh-cn/about/previous-releases
    local nodejs_codenames = {
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
    }

    for codename, version_number in pairs(nodejs_codenames) do
        if query == "lts/" .. codename then
            query = tostring(version_number)
            break
        end
    end

    if query == "lts" or query == "lts/*" then
        -- Find the latest LTS version (highest version number)
        local latest_version = 0
        for codename, version_number in pairs(nodejs_codenames) do
            if version_number > latest_version then
                latest_version = version_number
            end
        end
        query = tostring(latest_version)
    end

    return query
end
