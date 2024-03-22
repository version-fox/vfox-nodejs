local http = require("http")
local nodejsUtils = require("nodejs_utils")
--- Returns some pre-installed information, such as version number, download address, local files, etc.
--- If checksum is provided, vfox will automatically check it for you.
--- @param ctx table
--- @field ctx.version string User-input version
--- @return table Version information
function PLUGIN:PreInstall(ctx)
    local version = ctx.version

    if version == "latest" then
        local lists = self:Available({})
        version = lists[1].version
    end

    if not nodejsUtils.is_semver_simple(version) then
        local lists = self:Available({})
        local shorthands = nodejsUtils.calculate_shorthand(lists)
        version = shorthands[version]
    end

    if (version == nil) then
        error("version not found for provided version " .. version)
    end

    local arch_type = RUNTIME.archType
    local ext = ".tar.gz"
    local osType = RUNTIME.osType
    if RUNTIME.archType == "amd64" then
        arch_type = "x64"
    end
    if RUNTIME.osType == "windows" then
        ext = ".zip"
        osType = "win"
    end
    local filename = nodejsUtils.FileName:format(version, osType, arch_type, ext)
    local baseUrl = nodejsUtils.NodeBaseUrl:format(version)

    local resp, err = http.get({
        url = baseUrl .. "SHASUMS256.txt"
    })
    if err ~= nil or resp.status_code ~= 200 then
        error("get checksum failed")
    end
    local checksum = nodejsUtils.get_checksum(resp.body, filename)
    return {
        version = version,
        url = baseUrl .. filename,
        sha256 = checksum,
    }
end