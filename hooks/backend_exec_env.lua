-- hooks/backend_exec_env.lua
-- Sets up environment variables for a tool
-- Documentation: https://mise.jdx.dev/backend-plugin-development.html#backendexecenv

function PLUGIN:BackendExecEnv(ctx)
    local install_path = ctx.install_path
    local tool = ctx.tool
    local version = ctx.version

    -- Validate inputs
    if not install_path or install_path == "" then
        error("Install path cannot be empty")
    end
    if not version or version == "" then
        error("Version cannot be empty")
    end

    -- rv installs Ruby into a ruby-{version} subdirectory
    local file = require("file")
    local ruby_root = file.join_path(install_path, "ruby-" .. version)
    local bin_path = file.join_path(ruby_root, "bin")

    local env_vars = {
        -- Add tool's bin directory to PATH
        { key = "PATH", value = bin_path },
    }

    -- Set up GEM_HOME and GEM_PATH for proper gem isolation
    -- Ruby gem path uses major.minor.0 format (e.g., 3.3.9 -> 3.3.0)
    local major, minor = version:match("^(%d+)%.(%d+)")

    if major and minor then
        local gem_version = major .. "." .. minor .. ".0"
        local gem_path = file.join_path(ruby_root, "lib", "ruby", "gems", gem_version)

        table.insert(env_vars, {
            key = "GEM_HOME",
            value = gem_path,
        })

        table.insert(env_vars, {
            key = "GEM_PATH",
            value = gem_path,
        })
    end

    return {
        env_vars = env_vars,
    }
end
