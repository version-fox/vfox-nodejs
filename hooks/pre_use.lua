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

local util = require("util")
--- When user invoke `use` command, this function will be called to get the
--- valid version information.
--- @param ctx table Context information
function PLUGIN:PreUse(ctx)
    --- user input version
    local version = ctx.version

    local shorthands = util.calculate_shorthand(ctx.installedSdks)

    if not util.is_semver_simple(version) then
        version = shorthands[version]
    end

    -- vfox reports the switch even when another `node` keeps winning PATH
    -- lookup, so say so here instead of leaving `node --version` to
    -- contradict it.
    local shadowing = util.shadowing_node()
    if version ~= nil and shadowing ~= nil then
        print(
            "Note: "
                .. shadowing
                .. " comes before vfox in PATH, so `node` will not run nodejs@"
                .. version
                .. ". See "
                .. util.PnpmDocUrl
        )
    end

    --- return the version information
    return {
        version = version,
    }
end
