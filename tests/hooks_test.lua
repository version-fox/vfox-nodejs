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
            if state.responder ~= nil then
                return state.responder(args)
            end
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
    state.response, state.request_error, state.decoded, state.requests, state.responder = nil, nil, nil, 0, nil
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
    { "linux", "arm", "linux-armv7l.tar.gz" },
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
-- musl libc (Alpine, OpenWrt/ImmortalWrt): the plugin must select the
-- *-musl tarball instead of the glibc one.
-- See https://github.com/version-fox/vfox-nodejs/issues/29
local util = require("util")
test("is_musl honors RUNTIME.envType", function()
    RUNTIME = { osType = "linux", archType = "amd64", envType = "musl" }
    assert(util.is_musl() == true)
    RUNTIME = { osType = "linux", archType = "amd64", envType = "gnu" }
    assert(util.is_musl() == false)
    RUNTIME = { osType = "windows", archType = "amd64" }
    assert(util.is_musl() == false)
end)
test("package linux/amd64 musl (official)", function()
    RUNTIME = { osType = "linux", archType = "amd64", envType = "musl" }
    local filename = "node-v22.23.3-linux-x64-musl.tar.gz"
    local hash = string.rep("b", 64)
    state.response = { status_code = 200, body = hash .. "  " .. filename .. "\n" }
    local result = PLUGIN:PreInstall({ version = "22.23.3" })
    assert(result.url:sub(-#filename) == filename, result.url)
    assert(result.sha256 == hash, "checksum missing")
    assert(result.note ~= nil and result.note:find("README.md", 1, true), tostring(result.note))
end)
test("package linux/arm64 musl falls back to unofficial", function()
    RUNTIME = { osType = "linux", archType = "arm64", envType = "musl" }
    local filename = "node-v22.22.0-linux-arm64-musl.tar.gz"
    local official_hash = string.rep("c", 64)
    local unofficial_hash = string.rep("d", 64)
    state.responder = function(args)
        if args.url:find("unofficial-builds.nodejs.org", 1, true) then
            return { status_code = 200, body = unofficial_hash .. "  " .. filename .. "\n" }
        end
        return { status_code = 200, body = official_hash .. "  node-v22.22.0-linux-x64.tar.gz\n" }
    end
    local result = PLUGIN:PreInstall({ version = "22.22.0" })
    assert(result.url:sub(-#filename) == filename, result.url)
    assert(result.url:find("unofficial-builds.nodejs.org", 1, true), result.url)
    assert(result.sha256 == unofficial_hash, "unofficial checksum missing")
end)
test("musl unsupported architecture", function()
    RUNTIME = { osType = "linux", archType = "386", envType = "musl" }
    expect_error(function()
        PLUGIN:PreInstall({ version = "22.23.3" })
    end, "musl")
    assert(state.requests == 0)
end)
test("musl on 32-bit ARM names the armv7l package", function()
    RUNTIME = { osType = "linux", archType = "arm", envType = "musl" }
    expect_error(function()
        PLUGIN:PreInstall({ version = "22.23.3" })
    end, "got armv7l")
    assert(state.requests == 0)
end)
-- PostInstall guards the musl libstdc++ runtime Dependency.
dofile("hooks/post_install.lua")
test("post_install skips non-musl systems", function()
    RUNTIME = { osType = "windows", archType = "amd64" }
    PLUGIN:PostInstall({})
    RUNTIME = { osType = "linux", archType = "amd64", envType = "gnu" }
    PLUGIN:PostInstall({})
end)
test("post_install passes when libstdc++ is present", function()
    RUNTIME = { osType = "linux", archType = "amd64", envType = "musl" }
    assert(util.has_libstdcxx() == true, "test host must provide libstdc++")
    PLUGIN:PostInstall({})
end)
test("post_install fails without libstdc++", function()
    RUNTIME = { osType = "linux", archType = "amd64", envType = "musl" }
    local saved = util.file_exists
    util.file_exists = function()
        return false
    end
    expect_error(function()
        PLUGIN:PostInstall({})
    end, "libstdc++")
    util.file_exists = saved
end)
-- PostInstall also runs the unpacked node once: the dynamic loader names any
-- library that is missing, such as libatomic for the musl builds of 26.8.0+.
local function with_util(stubs, fn)
    local saved = {}
    for name, value in pairs(stubs) do
        saved[name] = util[name]
        util[name] = value
    end
    local ok, err = pcall(fn)
    for name, value in pairs(saved) do
        util[name] = value
    end
    assert(ok, err)
end
local musl_node = "/vfox/cache/nodejs/v-26.12.0/nodejs-26.12.0/bin/node"
local loader_error = "Error loading shared library libatomic.so.1: No such file or directory (needed by "
    .. musl_node
    .. ")\nError relocating "
    .. musl_node
    .. ": __atomic_compare_exchange: symbol not found\n"
--- The error PostInstall raises for a node that prints `output` and exits with `status`, nil when it passes.
local function post_install_error(output, status, opts)
    opts = opts or {}
    RUNTIME = { osType = "linux", archType = "amd64", envType = "musl" }
    local install = { sdkInfo = { [opts.sdk or "nodejs"] = { path = "/vfox/cache/nodejs/v-26.12.0/nodejs-26.12.0" } } }
    -- A table field: gopher-lua loses a `local x = nil` that a closure assigns.
    local result = {}
    with_util({
        has_libstdcxx = function()
            return true
        end,
        file_exists = function(path)
            return path == musl_node or (opts.alpine and path == "/etc/alpine-release")
        end,
        capture = function(command)
            state.command = command
            return output, status
        end,
    }, function()
        local ok, err = pcall(function()
            PLUGIN:PostInstall(install)
        end)
        if not ok then
            result.message = tostring(err)
        end
    end)
    return result.message
end
test("post_install names the library the loader cannot find", function()
    local message = post_install_error(loader_error, 127, { alpine = true })
    assert(message ~= nil, "expected an error")
    assert(message:find("the libatomic system package", 1, true), message)
    assert(message:find("`apk add libatomic`", 1, true), message)
    assert(message:find("README.md", 1, true), message)
    assert(state.command == "'" .. musl_node .. "' --version", tostring(state.command))
end)
test("post_install without a known package manager still names the library", function()
    local message = post_install_error(loader_error, 127)
    assert(message ~= nil and message:find("libatomic", 1, true), tostring(message))
    assert(not message:find("apk add", 1, true), message)
end)
test("post_install finds the release under the name of an alias", function()
    local message = post_install_error(loader_error, 127, { sdk = "nodejs-dev" })
    assert(message ~= nil and message:find("libatomic", 1, true), tostring(message))
end)
test("post_install names a library it has no package for", function()
    local message = post_install_error("Error loading shared library libfoo.so.2: No such file or directory\n", 127)
    assert(message ~= nil and message:find("the libfoo.so.2 shared library", 1, true), tostring(message))
end)
test("post_install reports a symbol the libraries lack", function()
    local message = post_install_error("Error relocating /x/bin/node: _ZNSt3foo: symbol not found\n", 127)
    assert(message ~= nil and message:find("cannot run", 1, true), tostring(message))
    assert(message:find("_ZNSt3foo: symbol not found", 1, true), message)
end)
test("post_install passes when node runs", function()
    assert(post_install_error("v26.12.0\n", 0) == nil)
end)
test("post_install leaves the install alone when nothing can be run", function()
    assert(post_install_error(nil, nil) == nil)
end)
test("post_install leaves the install alone when node fails for another reason", function()
    assert(post_install_error("Segmentation fault\n", 139) == nil)
end)
test("post_install does not run node outside musl", function()
    RUNTIME = { osType = "linux", archType = "amd64", envType = "gnu" }
    with_util({
        capture = function()
            error("node must not be run")
        end,
    }, function()
        PLUGIN:PostInstall({ sdkInfo = { nodejs = { path = "/vfox/nodejs" } } })
    end)
end)
test("missing package", function()
    RUNTIME = { osType = "windows", archType = "arm64" }
    state.response = { status_code = 200, body = string.rep("a", 64) .. "  node-v20.16.0-win-x64.zip\n" }
    expect_error(function()
        PLUGIN:PreInstall({ version = "20.16.0" })
    end, "node-v20.16.0-win-arm64.zip")
end)
test("a failed checksum request says why", function()
    RUNTIME = { osType = "linux", archType = "amd64" }
    state.request_error =
        'Get "https://nodejs.org/dist/v20.16.0/SHASUMS256.txt": x509: certificate signed by unknown authority'
    expect_error(function()
        PLUGIN:PreInstall({ version = "20.16.0" })
    end, "get checksum failed: Get")
    state.request_error = nil
    state.response = { status_code = 404 }
    local ok, err = pcall(function()
        PLUGIN:PreInstall({ version = "20.99.0" })
    end)
    assert(not ok, "expected an error")
    assert(tostring(err):find("get checksum failed: HTTP 404 from https://", 1, true), tostring(err))
    assert(tostring(err):find("/v20.99.0/SHASUMS256.txt", 1, true), tostring(err))
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
test("legacy lts krypton maps to its major", function()
    local path = write_legacy("lts/krypton")
    local result = PLUGIN:ParseLegacyFile({
        filepath = path,
        filename = ".node-version",
        strategy = "specified",
    })
    os.remove(path)
    assert(result.version == "24", tostring(result.version))
end)
test("legacy lts unknown codename resolves dynamically under latest_available", function()
    state.response = { status_code = 200, body = "index" }
    state.decoded = {
        { version = "v30.0.0", npm = "11.0.0", lts = "Future" },
        { version = "v24.21.0", npm = "11.19.0", lts = "Krypton" },
    }
    local path = write_legacy("lts/future")
    local result = PLUGIN:ParseLegacyFile({
        filepath = path,
        filename = ".nvmrc",
        strategy = "latest_available",
        getInstalledVersions = installed_versions,
    })
    os.remove(path)
    assert(result.version == "30.0.0", tostring(result.version))
end)
test("legacy bare lts resolves to newest LTS dynamically under latest_available", function()
    state.response = { status_code = 200, body = "index" }
    state.decoded = {
        { version = "v22.23.3", npm = "10.9.9", lts = "Jod" },
        { version = "v24.21.0", npm = "11.19.0", lts = "Krypton" },
    }
    local path = write_legacy("lts")
    local result = PLUGIN:ParseLegacyFile({
        filepath = path,
        filename = ".nvmrc",
        strategy = "latest_available",
        getInstalledVersions = installed_versions,
    })
    os.remove(path)
    assert(result.version == "24.21.0", tostring(result.version))
end)
test("legacy lts without match falls back to the query itself", function()
    state.response = { status_code = 200, body = "index" }
    state.decoded = { { version = "v26.11.1", npm = "11.20.0", lts = false } }
    local path = write_legacy("lts/unknown")
    local result = PLUGIN:ParseLegacyFile({
        filepath = path,
        filename = ".nvmrc",
        strategy = "latest_available",
        getInstalledVersions = installed_versions,
    })
    os.remove(path)
    assert(result.version == "lts/unknown", tostring(result.version))
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
-- Version files name a release by its numbers, not by its text.
local function installed_list(list)
    return function(...)
        assert(select("#", ...) == 0, "getInstalledVersions must be called as a plain function")
        return list
    end
end
local function legacy_version(content, strategy, installed)
    local path = write_legacy(content)
    local ok, result = pcall(function()
        return PLUGIN:ParseLegacyFile({
            filepath = path,
            filename = ".nvmrc",
            strategy = strategy,
            getInstalledVersions = installed_list(installed or {}),
        })
    end)
    os.remove(path)
    assert(ok, result)
    return result.version
end
test("legacy latest_installed takes the newest release by number", function()
    -- vfox lists installed releases as text, descending: 22.9.0 comes before 22.23.3.
    local installed = { "26.12.0", "22.9.0", "22.3.0", "22.23.3", "20.20.2" }
    assert(legacy_version("22", "latest_installed", installed) == "22.23.3")
    assert(legacy_version("22.3", "latest_installed", installed) == "22.3.0")
    assert(legacy_version("lts/jod", "latest_installed", installed) == "22.23.3")
    assert(state.requests == 0, "installed releases answer without the index")
end)
test("legacy prefixes are matched by numbers, part by part", function()
    state.response = { status_code = 200, body = "index" }
    state.decoded = { { version = "v22.23.3" }, { version = "v22.2.1" } }
    -- 22.2 is not the start of 22.23.3. Nothing installed matches, so the index answers.
    assert(legacy_version("22.2", "latest_installed", { "22.23.3" }) == "22.2.1")
    assert(legacy_version("22.2", "latest_installed", { "22.23.3", "22.2.1" }) == "22.2.1")
    assert(legacy_version("22.23", "latest_installed", { "22.23.3", "22.2.1" }) == "22.23.3")
end)
test("legacy wildcards stand for the rest of a release number", function()
    local installed = { "22.9.0", "22.23.3" }
    for _, text in ipairs({ "22.x", "22.X", "22.x.x", "22.*", "v22.x" }) do
        assert(legacy_version(text, "latest_installed", installed) == "22.23.3", text)
    end
end)
test("legacy text that is not a release number is left alone", function()
    local texts = { "node", "stable", "iron", "lts/-1", "lts/(", ">=20", "^22.0.0", "~22.23", "22.x.1", "22..3", "x" }
    for _, text in ipairs(texts) do
        assert(legacy_version(text, "latest_installed", { "22.23.3" }) == text, text)
    end
    assert(legacy_version("node", "latest_available") == "node")
    assert(state.requests == 0, "text that is no release number needs no index")
end)
test("legacy only drops a leading v", function()
    assert(legacy_version("V22.23.3", "specified") == "22.23.3")
    assert(legacy_version("v22", "latest_installed", { "22.23.3" }) == "22.23.3")
    -- A codename with a v inside keeps it.
    state.response = { status_code = 200, body = "index" }
    state.decoded = {
        { version = "v30.1.0", npm = "11.0.0", lts = "Vanadium" },
        { version = "v30.0.0", npm = "11.0.0", lts = "Vanadium" },
    }
    assert(legacy_version("lts/vanadium", "latest_available") == "30.1.0")
end)
test("legacy latest_available takes the newest matching release", function()
    state.response = { status_code = 200, body = "index" }
    state.decoded = {
        { version = "v22.9.0" },
        { version = "v22.23.3" },
        { version = "v22.3.0" },
        { version = "v20.20.2" },
    }
    assert(legacy_version("22", "latest_available") == "22.23.3")
    assert(legacy_version("22.3", "latest_available") == "22.3.0")
    assert(legacy_version("22.x", "latest_available") == "22.23.3")
    assert(legacy_version("18", "latest_available") == "18")
end)
-- PreUse notes a `node` that vfox keeps ahead of its own paths, such as the
-- one `pnpm runtime set node -g` writes to $PNPM_HOME/bin.
dofile("hooks/pre_use.lua")
local function with_path(path, existing, fn)
    local saved_getenv, saved_exists, saved_print = os.getenv, util.file_exists, print
    local printed = {}
    os.getenv = function(key)
        if key == "PATH" then
            return path
        end
        return saved_getenv(key)
    end
    util.file_exists = function(p)
        return existing[p] == true
    end
    print = function(line)
        table.insert(printed, line)
    end
    local ok, err = pcall(fn)
    os.getenv, util.file_exists, print = saved_getenv, saved_exists, saved_print
    assert(ok, err)
    return printed
end
local installed = { ["24.21.0"] = { version = "24.21.0" }, ["22.23.3"] = { version = "22.23.3" } }
test("pre_use notes a node ahead of vfox", function()
    RUNTIME = { osType = "linux", archType = "amd64" }
    local printed = with_path("/home/u/.local/share/pnpm/bin:/home/u/.vfox/sdks/nodejs/bin:/usr/bin", {
        ["/home/u/.local/share/pnpm/bin/node"] = true,
        ["/home/u/.vfox/sdks/nodejs/bin/node"] = true,
    }, function()
        assert(PLUGIN:PreUse({ version = "24", installedSdks = installed }).version == "24.21.0")
    end)
    assert(#printed == 1, "expected one note")
    assert(printed[1]:find("/home/u/.local/share/pnpm/bin/node", 1, true), printed[1])
    assert(printed[1]:find("nodejs@24.21.0", 1, true), printed[1])
    assert(printed[1]:find("docs/pnpm.md", 1, true), printed[1])
end)
test("pre_use stays quiet when vfox comes first", function()
    RUNTIME = { osType = "linux", archType = "amd64" }
    local printed = with_path("/home/u/.vfox/sdks/nodejs/bin:/home/u/.local/share/pnpm/bin", {
        ["/home/u/.local/share/pnpm/bin/node"] = true,
    }, function()
        assert(PLUGIN:PreUse({ version = "22.23.3", installedSdks = installed }).version == "22.23.3")
    end)
    assert(#printed == 0, tostring(printed[1]))
end)
test("shadowing_node follows vfox's PATH split", function()
    RUNTIME = { osType = "linux", archType = "amd64" }
    local existing = { ["/opt/node/bin/node"] = true }
    with_path("/opt/node/bin/:/home/u/.version-fox/temp/1/nodejs/bin", existing, function()
        assert(util.shadowing_node() == "/opt/node/bin/node", tostring(util.shadowing_node()))
    end)
    -- Behind another SDK's vfox path the entry ranks below every vfox path.
    with_path("/home/u/.vfox/sdks/java/bin:/opt/node/bin:/home/u/.vfox/sdks/nodejs/bin", existing, function()
        assert(util.shadowing_node() == nil)
    end)
    -- No vfox path yet: vfox will put its paths first.
    with_path("/opt/node/bin:/usr/bin", existing, function()
        assert(util.shadowing_node() == nil)
    end)
end)
test("shadowing_node on windows", function()
    RUNTIME = { osType = "windows", archType = "amd64" }
    local pnpm = "C:\\Users\\u\\AppData\\Local\\pnpm\\bin"
    with_path(pnpm .. ";C:\\Users\\u\\.vfox\\sdks\\nodejs;C:\\Windows", {
        [pnpm .. "\\node.exe"] = true,
    }, function()
        assert(util.shadowing_node() == pnpm .. "\\node.exe", tostring(util.shadowing_node()))
    end)
end)
-- lib/util.lua helpers.
test("version_prefix reads what a version file asks for", function()
    local accepted = {
        ["22"] = { 22 },
        ["22.23"] = { 22, 23 },
        ["22.23.3"] = { 22, 23, 3 },
        ["22.x"] = { 22 },
        ["22.X"] = { 22 },
        ["22.x.x"] = { 22 },
        ["22.23.*"] = { 22, 23 },
    }
    for text, want in pairs(accepted) do
        local got = util.version_prefix(text)
        assert(got ~= nil and #got == #want, text)
        for i, number in ipairs(want) do
            assert(got[i] == number, text)
        end
    end
    for _, text in ipairs({ "", "x", "*", "node", "lts/jod", ">=20", "22.x.1", "22..3", "22.", ".22", "22.2a", "v22" }) do
        assert(util.version_prefix(text) == nil, "should not read " .. text)
    end
end)
test("newest_matching compares numbers", function()
    local versions = { "22.9.0", "22.3.0", "22.23.3", "20.20.2", "x.y.z" }
    assert(util.newest_matching(versions, { 22 }) == "22.23.3")
    assert(util.newest_matching(versions, { 22, 3 }) == "22.3.0")
    assert(util.newest_matching(versions, { 22, 2 }) == nil)
    assert(util.newest_matching(versions, { 18 }) == nil)
    assert(util.newest_matching(nil, { 22 }) == nil)
end)
test("getBaseUrl drops trailing slashes", function()
    local saved = os.getenv
    local mirror = nil
    os.getenv = function(key)
        if key == "VFOX_NODEJS_MIRROR" then
            return mirror
        end
        return saved(key)
    end
    local ok, err = pcall(function()
        assert(util.getBaseUrl() == "https://nodejs.org/dist")
        mirror = ""
        assert(util.getBaseUrl() == "https://nodejs.org/dist")
        mirror = "https://npmmirror.com/mirrors/node"
        assert(util.getBaseUrl() == "https://npmmirror.com/mirrors/node")
        mirror = "https://npmmirror.com/mirrors/node/"
        assert(util.getBaseUrl() == "https://npmmirror.com/mirrors/node")
        mirror = "https://npmmirror.com/mirrors/node//"
        assert(util.getBaseUrl() == "https://npmmirror.com/mirrors/node")
        assert(select("#", util.getBaseUrl()) == 1, "the count of gsub must not leak out")
    end)
    os.getenv = saved
    assert(ok, err)
end)
test("capture runs a command and returns what it printed", function()
    local output, status = util.capture("echo hi")
    assert(output == "hi\n", tostring(output))
    assert(status == 0 or status == nil, tostring(status))
end)
test("shell_quote quotes one word", function()
    assert(util.shell_quote("a b") == "'a b'")
    assert(util.shell_quote("it's") == "'it'\\''s'")
end)
test("library hints follow the distribution", function()
    local function on(existing, fn)
        with_util({
            file_exists = function(path)
                return existing[path] == true
            end,
        }, fn)
    end
    on({ ["/etc/alpine-release"] = true }, function()
        assert(util.package_manager() == "apk")
        assert(util.library_package_hint("libstdc++.so.6") == "the libstdc++ system package")
        assert(util.install_command("libatomic.so.1") == "apk add libatomic")
    end)
    on({ ["/etc/openwrt_release"] = true }, function()
        assert(util.package_manager() == "opkg")
        assert(util.library_package_hint("libstdc++.so.6") == "the libstdcpp system package")
        assert(util.install_command("libstdc++.so.6") == "opkg install libstdcpp")
    end)
    on({}, function()
        assert(util.package_manager() == nil)
        assert(util.library_package_hint("libstdc++.so.6") == "the libstdc++ system package (libstdcpp on OpenWrt)")
        assert(util.library_package_hint("libatomic.so.1") == "the libatomic system package")
        assert(util.library_package_hint("libfoo.so.2") == "the libfoo.so.2 shared library")
        assert(util.install_command("libatomic.so.1") == nil)
    end)
end)
print(state.passed .. " passed, " .. state.failed .. " failed")
assert(state.failed == 0)
