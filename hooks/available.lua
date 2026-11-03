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

local json = require("json")
local http = require("http")
local util = require("util")

-- Cached Available result; reset by the tests between cases.
available_result = nil

--- Return all available versions provided by this plugin
--- @param ctx table Empty table used as context, for future extension
--- @return table Descriptions of available versions and accompanying tool descriptions
function PLUGIN:Available(ctx)
    if available_result then
        return available_result
    end
    local resp, err = http.get({
        url = util.getBaseUrl() .. util.VersionSourceUrl,
    })
    if err ~= nil then
        error("Failed to fetch Node.js versions: " .. tostring(err))
    end
    if resp.status_code ~= 200 then
        error("Failed to fetch Node.js versions: HTTP " .. tostring(resp.status_code))
    end
    local body = json.decode(resp.body)
    -- The index names the LTS lines. Keep what it says for ParseLegacyFile, which
    -- runs at every prompt and must not fetch it. See docs/lts.md.
    util.remember_lts(body)
    local result = {}

    for _, v in ipairs(body) do
        local version = string.gsub(v.version, "^v", "")
        -- List only x.y.z releases, the form PreInstall takes as it is. nodejs.org
        -- has listed a pre-release, 27.0.0-alpha.0.0.0, since 2026-10-29: it sorts
        -- first, so it became `latest`, and PreInstall cannot install it.
        if util.is_semver_simple(version) then
            table.insert(result, {
                version = version,
                note = v.lts and "LTS" or "",
                addition = {
                    {
                        name = "npm",
                        version = v.npm,
                    },
                },
            })
        end
    end
    table.sort(result, util.compare_versions)
    available_result = result
    return result
end
