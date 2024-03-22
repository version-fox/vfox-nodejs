NODEJS_UTILS={}

NODEJS_UTILS.NodeBaseUrl = "https://nodejs.org/dist/v%s/"
NODEJS_UTILS.FileName = "node-v%s-%s-%s%s"
NODEJS_UTILS.npmDownloadUrl = "https://github.com/npm/cli/archive/v%s.%s"
NODEJS_UTILS.VersionSourceUrl = "https://nodejs.org/dist/index.json"

function NODEJS_UTILS.compare_versions(v1o, v2o)
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


function NODEJS_UTILS.get_checksum(file_content, file_name)
    for line in string.gmatch(file_content, '([^\n]*)\n?') do
        local checksum, name = string.match(line, '(%w+)%s+(%S+)')
        if name == file_name then
            return checksum
        end
    end
    return nil
end

function NODEJS_UTILS.is_semver_simple(str)
    -- match pattern: three digits, separated by dot
    local pattern = "^%d+%.%d+%.%d+$"
    return str:match(pattern) ~= nil
end


function NODEJS_UTILS.extract_semver(semver)
    local pattern = "^(%d+)%.(%d+)%.[%d.]+$"
    local major, minor = semver:match(pattern)
    return major, minor
end


function NODEJS_UTILS.calculate_shorthand(list)
    local versions_shorthand = {}
    for _, v in ipairs(list) do
        local version = v.version
        local major, minor = extract_semver(version)

        if major then
            if not versions_shorthand[major] then
                versions_shorthand[major] = version
            else
                if compare_versions({version = version}, {version = versions_shorthand[major]}) then
                    versions_shorthand[major] = version
                end
            end

            if minor then
                local major_minor = major .. "." .. minor
                if not versions_shorthand[major_minor] then
                    versions_shorthand[major_minor] = version
                else
                    if compare_versions({version = version}, {version = versions_shorthand[major_minor]}) then
                        versions_shorthand[major_minor] = version
                    end
                end
            end
        end
    end

    return versions_shorthand
end