# mise-rv Backend Plugin Design

**Date**: 2025-11-03
**Status**: Approved

## Overview

The mise-rv backend plugin manages Ruby versions using the rv tool as the underlying installation mechanism. Users will reference Ruby installations as `rv:ruby@3.3.9`.

## Key Design Decisions

- **Tool name**: `ruby` (usage: `rv:ruby@3.3.9`)
- **Installation**: Uses mise's directory structure with rv's `--install-dir` flag
- **Version discovery**: Calls `rv ruby list --format json` to get available versions
- **Environment**: Sets PATH + GEM_HOME/GEM_PATH for proper gem isolation
- **Dependency**: rv itself is installed via `ubi:spinel-coop/rv` in mise.toml

## Data Flow

1. **Version Listing**: `mise ls-remote rv:ruby` → BackendListVersions calls `rv ruby list --format json`, parses and returns versions
2. **Installation**: `mise install rv:ruby@3.3.9` → BackendInstall calls `rv ruby install 3.3.9 --install-dir {path}`
3. **Execution**: User runs Ruby → BackendExecEnv sets PATH to `{install_path}/bin` and GEM_HOME/GEM_PATH

## Dependencies

The plugin requires rv to be installed. Added to `mise.toml`:
```toml
[tools]
"ubi:spinel-coop/rv" = "latest"
```

This ensures rv is available during development and when the plugin executes.

## Implementation Details

### BackendListVersions

**Purpose**: Return a list of available Ruby versions that can be installed.

**Strategy**:
1. Execute `rv ruby list --format json`
2. Parse JSON response using the `json` module
3. Extract and normalize version strings (strip "ruby-" prefix)
4. Deduplicate versions (JSON contains entries for each architecture/OS combo)
5. Return array of versions

**Error Handling**:
- rv command fails → "rv is not installed or not in PATH"
- JSON parsing fails → "Failed to parse rv output"
- No versions found → "No Ruby versions available"

**Pseudocode**:
```lua
function PLUGIN:BackendListVersions(ctx)
    local result = cmd.exec("rv ruby list --format json")
    local data = json.decode(result)

    local versions_set = {}
    for _, entry in ipairs(data) do
        local version = entry.version:gsub("^ruby%-", "")
        versions_set[version] = true
    end

    local versions = {}
    for version, _ in pairs(versions_set) do
        table.insert(versions, version)
    end

    return {versions = versions}
end
```

### BackendInstall

**Purpose**: Install a specific Ruby version to mise's installation directory.

**Strategy**:
1. Validate inputs (tool, version, install_path)
2. Create installation directory with `mkdir -p`
3. Execute `rv ruby install {version} --install-dir {install_path}`
4. Let rv handle errors (non-zero exit will propagate)

**Key Command**:
```bash
rv ruby install 3.3.9 --install-dir /path/to/mise/installs/rv/ruby/3.3.9
```

**Error Handling**:
- Empty tool/version/path → Descriptive error message
- Installation failure → rv's error output propagates
- Platform incompatibility → rv handles and errors appropriately

**Pseudocode**:
```lua
function PLUGIN:BackendInstall(ctx)
    local tool = ctx.tool
    local version = ctx.version
    local install_path = ctx.install_path

    if not tool or tool == "" then
        error("Tool name cannot be empty")
    end

    cmd.exec("mkdir -p " .. install_path)

    local install_cmd = "rv ruby install " .. version .. " --install-dir " .. install_path
    cmd.exec(install_cmd)

    return {}
end
```

### BackendExecEnv

**Purpose**: Set up environment variables so Ruby and gems work correctly.

**Strategy**:
1. Set PATH to `{install_path}/bin`
2. Parse version to determine gem path (e.g., 3.3.9 → 3.3.0)
3. Set GEM_HOME and GEM_PATH to `{install_path}/lib/ruby/gems/{major}.{minor}.0`

**Version Parsing**:
- Version `3.3.9` → gem path uses `3.3.0`
- Version `3.4.7` → gem path uses `3.4.0`

**Pseudocode**:
```lua
function PLUGIN:BackendExecEnv(ctx)
    local install_path = ctx.install_path
    local version = ctx.version
    local file = require("file")

    local bin_path = file.join_path(install_path, "bin")

    local major, minor = version:match("^(%d+)%.(%d+)")
    local gem_version = major .. "." .. minor .. ".0"
    local gem_path = file.join_path(install_path, "lib", "ruby", "gems", gem_version)

    return {
        env_vars = {
            {key = "PATH", value = bin_path},
            {key = "GEM_HOME", value = gem_path},
            {key = "GEM_PATH", value = gem_path}
        }
    }
end
```

## Configuration Updates

### metadata.lua

```lua
PLUGIN = {
    name = "rv",
    version = "1.0.0",
    description = "A mise backend plugin for managing Ruby versions using rv",
    author = "spinel-coop",
    homepage = "https://github.com/spinel-coop/mise-rv",
    license = "MIT",
    notes = {
        "Requires rv to be installed (automatically handled via ubi backend)"
    }
}
```

### mise.toml

Add rv dependency:
```toml
[tools]
"ubi:spinel-coop/rv" = "latest"
```

### mise-tasks/test

Update test tool and commands:
```bash
TEST_TOOL="ruby"
TEST_VERSION="3.3.9"

echo "Testing version listing for ${TEST_TOOL}..."
if mise ls-remote rv:${TEST_TOOL}; then
    echo "✓ Version listing works"

    echo "Testing installation..."
    if mise install rv:${TEST_TOOL}@${TEST_VERSION}; then
        echo "✓ Installation works"

        if mise exec rv:${TEST_TOOL}@${TEST_VERSION} -- ruby --version; then
            echo "✓ Ruby execution works"
        fi
    fi
fi
```

## Testing Plan

1. Link plugin: `mise plugin link --force rv .`
2. List versions: `mise ls-remote rv:ruby`
3. Install Ruby: `mise install rv:ruby@3.3.9`
4. Execute Ruby: `mise exec rv:ruby@3.3.9 -- ruby --version`
5. Test gems: `mise exec rv:ruby@3.3.9 -- gem env`
6. Run full test suite: `mise run test`
7. Run CI checks: `mise run ci`

## Future Enhancements

- Support for other Ruby implementations (JRuby, TruffleRuby) if rv adds them
- Caching of version lists to reduce API calls
- Better error messages with troubleshooting hints
