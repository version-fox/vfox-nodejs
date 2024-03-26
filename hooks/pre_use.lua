local nodejsUtils = require("nodejs_utils")
--- When user invoke `use` command, this function will be called to get the
--- valid version information.
--- @param ctx table Context information
function PLUGIN:PreUse(ctx)
    --- user input version
    local version = ctx.version

    local shorthands = nodejsUtils.calculate_shorthand(ctx.installedSdks)

    if not nodejsUtils.is_semver_simple(version) then
        version = shorthands[version]
    end

    --- return the version information
    return {
        version = version,
    }
end