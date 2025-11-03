-- hooks/backend_list_versions.lua
-- Lists available versions for a tool in this backend
-- Documentation: https://mise.jdx.dev/backend-plugin-development.html#backendlistversions

function PLUGIN:BackendListVersions(ctx)
    local tool = ctx.tool

    -- Validate tool name
    if not tool or tool == "" then
        error("Tool name cannot be empty")
    end

    -- Only support "ruby" as the tool name
    if tool ~= "ruby" then
        error("mise-rv backend only supports 'ruby' as the tool name. Use: rv:ruby@version")
    end

    -- Get available Ruby versions from rv
    local cmd = require("cmd")
    local json = require("json")

    -- Execute rv ruby list with JSON output
    local result, err = cmd.exec("rv ruby list --format json")

    if err then
        error("Failed to execute rv command. Is rv installed? Error: " .. err)
    end

    -- Parse JSON response
    local success, data = pcall(json.decode, result)
    if not success then
        error("Failed to parse rv output: " .. tostring(data))
    end

    -- Extract and deduplicate versions
    -- rv returns entries for each platform/arch combo, we just want unique version strings
    local versions_set = {}

    for _, entry in ipairs(data) do
        if entry.version then
            -- Strip "ruby-" prefix (e.g., "ruby-3.3.9" -> "3.3.9")
            local version = entry.version:gsub("^ruby%-", "")
            versions_set[version] = true
        end
    end

    -- Convert set to array
    local versions = {}
    for version, _ in pairs(versions_set) do
        table.insert(versions, version)
    end

    if #versions == 0 then
        error("No Ruby versions found from rv")
    end

    return { versions = versions }
end
