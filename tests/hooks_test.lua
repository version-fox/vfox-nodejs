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

package.path = "./lib/?.lua;" .. package.path
local state = { failed = 0, passed = 0 }
package.preload.http = function()
    return {
        get = function(args)
            state.requests = state.requests + 1
            return state.response, state.request_error
        end,
    }
end
package.preload.json = function()
    return {
        decode = function()
            return state.decoded
        end,
    }
end
PLUGIN = {}
dofile("hooks/available.lua")
dofile("hooks/pre_install.lua")
local function test(name, fn)
    state.response, state.request_error, state.decoded, state.requests = nil, nil, nil, 0
    available_result = nil
    local ok, err = pcall(fn)
    if ok then
        state.passed = state.passed + 1
    else
        state.failed = state.failed + 1
        print("FAIL " .. name .. ": " .. tostring(err))
    end
end
local function expect_error(fn, message)
    local ok, err = pcall(fn)
    assert(not ok, "expected error")
    assert(tostring(err):find(message, 1, true), tostring(err))
end
for _, failure in ipairs({ "timeout", "HTTP 503" }) do
    test("search failure and recovery " .. failure, function()
        if failure == "timeout" then
            state.request_error = "timeout"
        else
            state.response = { status_code = 503 }
        end
        expect_error(function()
            PLUGIN:Available({})
        end, failure)
        state.request_error = nil
        state.response = { status_code = 200, body = "index" }
        state.decoded = { { version = "v20.16.0", npm = "10.8.1", lts = "Iron" } }
        assert(PLUGIN:Available({})[1].version == "20.16.0")
        assert(state.requests == 2, "failed response was cached")
    end)
end
local cases = {
    { "windows", "amd64", "win-x64.zip" },
    { "windows", "386", "win-x86.zip" },
    { "windows", "arm64", "win-arm64.zip" },
    { "linux", "amd64", "linux-x64.tar.gz" },
    { "darwin", "arm64", "darwin-arm64.tar.gz" },
}
for _, case in ipairs(cases) do
    test("package " .. case[1] .. "/" .. case[2], function()
        RUNTIME = { osType = case[1], archType = case[2] }
        local filename = "node-v20.16.0-" .. case[3]
        local hash = string.rep("a", 64)
        state.response = { status_code = 200, body = hash .. "  " .. filename .. "\n" }
        local result = PLUGIN:PreInstall({ version = "20.16.0" })
        assert(result.url:sub(-#filename) == filename, result.url)
        assert(result.sha256 == hash, "checksum missing")
    end)
end
test("missing architecture", function()
    RUNTIME = { osType = "windows" }
    expect_error(function()
        PLUGIN:PreInstall({ version = "20.16.0" })
    end, "architecture")
    assert(state.requests == 0)
end)
test("missing package", function()
    RUNTIME = { osType = "windows", archType = "arm64" }
    state.response = { status_code = 200, body = string.rep("a", 64) .. "  node-v20.16.0-win-x64.zip\n" }
    expect_error(function()
        PLUGIN:PreInstall({ version = "20.16.0" })
    end, "node-v20.16.0-win-arm64.zip")
end)
-- ParseLegacyFile: the legacy file record drives version selection through
-- resolve_version (codenames) and resolve_legacy_version (strategies).
dofile("hooks/parse_legacy_file.lua")
local function write_legacy(content)
    local path = os.tmpname()
    local file = io.open(path, "w")
    if file == nil then
        error("cannot write " .. path)
    end
    file:write(content)
    file:close()
    return path
end
-- Installed versions come from vfox as a plain 0-argument callback stored in
-- the context table; a method-style call would pass the table and must fail.
local function installed_versions(...)
    assert(select("#", ...) == 0, "getInstalledVersions must be called as a plain function")
    return { "26.11.1", "22.23.3" }
end
test("legacy exact version in .nvmrc", function()
    local path = write_legacy("22.23.3\n")
    local result = PLUGIN:ParseLegacyFile({
        filepath = path,
        filename = ".nvmrc",
        strategy = "specified",
    })
    os.remove(path)
    assert(result.version == "22.23.3", tostring(result.version))
end)
test("legacy lts codename maps to its major", function()
    local path = write_legacy("lts/jod")
    local result = PLUGIN:ParseLegacyFile({
        filepath = path,
        filename = ".node-version",
        strategy = "specified",
    })
    os.remove(path)
    assert(result.version == "22", tostring(result.version))
end)
test("legacy latest_installed resolves against installed versions", function()
    local path = write_legacy("22\n")
    local result = PLUGIN:ParseLegacyFile({
        filepath = path,
        filename = ".nvmrc",
        strategy = "latest_installed",
        getInstalledVersions = installed_versions,
    })
    os.remove(path)
    assert(result.version == "22.23.3", tostring(result.version))
end)
test("legacy latest_available resolves against the index", function()
    state.response = { status_code = 200, body = "index" }
    state.decoded = { { version = "v26.11.1" }, { version = "v22.23.3" } }
    local path = write_legacy("22\n")
    local result = PLUGIN:ParseLegacyFile({
        filepath = path,
        filename = ".nvmrc",
        strategy = "latest_available",
        getInstalledVersions = installed_versions,
    })
    os.remove(path)
    assert(result.version == "22.23.3", tostring(result.version))
end)
print(state.passed .. " passed, " .. state.failed .. " failed")
assert(state.failed == 0)
