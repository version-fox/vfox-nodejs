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

--- Message for a shared library that the musl build needs and the system
--- lacks, with the command that installs it where the distribution is known.
--- @param soname string e.g. "libatomic.so.1"
--- @return string
local function missing_library(soname)
    local message = "Node.js (musl build) requires "
        .. util.library_package_hint(soname)
        .. ", which was not found on this system."
    local command = util.install_command(soname)
    if command ~= nil then
        message = message .. " Install it with `" .. command .. "` and reinstall."
    else
        message = message .. " Install it and reinstall."
    end
    return message .. " See " .. util.ReadmeUrl
end

--- Where vfox unpacked the release.
--- @param ctx table
--- @return string|nil
local function install_path(ctx)
    for _, info in pairs(ctx.sdkInfo or {}) do
        if type(info) == "table" and type(info.path) == "string" then
            return info.path
        end
    end
    return nil
end

--- Fail fast when the musl Node.js binary cannot run: it needs libstdc++ and,
--- from 26.8.0 on, libatomic, which musl distributions do not install by
--- default. Without this check the install looks successful and only
--- `node --version` fails later with `Error loading shared library ...` or
--- `Error relocating ... symbol not found`.
--- See https://github.com/version-fox/vfox-nodejs/issues/29
--- @param ctx table Context information
function PLUGIN:PostInstall(ctx)
    if RUNTIME.osType ~= "linux" then
        return
    end
    if not util.is_musl() then
        return
    end
    if not util.has_libstdcxx() then
        error(missing_library("libstdc++.so.6"))
    end

    -- The dynamic loader names whatever else is missing, so run the binary
    -- once instead of keeping a list of libraries and where they live. When
    -- nothing can be run here, or node fails for another reason, the install
    -- is left alone.
    local path = install_path(ctx)
    if path == nil or not util.file_exists(path .. "/bin/node") then
        return
    end
    local output, status = util.capture(util.shell_quote(path .. "/bin/node") .. " --version")
    if output == nil or status == 0 then
        return
    end
    local soname = output:match("Error loading shared library ([^:%s]+):")
    if soname ~= nil then
        error(missing_library(soname))
    end
    local relocation = output:match("Error relocating [^\n]+")
    if relocation ~= nil then
        error("Node.js (musl build) cannot run on this system: " .. relocation .. ". See " .. util.ReadmeUrl)
    end
end
