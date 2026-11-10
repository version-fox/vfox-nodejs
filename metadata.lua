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

--- !!! DO NOT EDIT OR RENAME !!!
PLUGIN = {}

--- !!! MUST BE SET !!!
--- Plugin name
PLUGIN.name = "nodejs"
--- Plugin version
PLUGIN.version = "0.5.6"
--- Plugin repository
PLUGIN.homepage = "https://github.com/version-fox/vfox-nodejs"
--- Plugin license
PLUGIN.license = "Apache 2.0"
--- Plugin description
PLUGIN.description = "Node.js runtime environment."

--- !!! OPTIONAL !!!
--- minimum compatible vfox version
PLUGIN.minRuntimeVersion = "0.3.0"
--- Some things that need user to be attention!
PLUGIN.notes = {}

--- List legacy configuration filenames for determining the specified version of the tool.
--- such as ".node-version", ".nvmrc", etc.
PLUGIN.legacyFilenames = {
    ".node-version",
    ".nvmrc",
}

--- Hints for a command of this SDK shadowed by another executable in PATH.
--- vfox 1.1.0 and later prints these with its own shadowing warning; older
--- vfox ignores this field and the plugin prints its own Note from PreUse.
--- See https://github.com/version-fox/vfox/blob/main/docs/plugins/create/howto.md#shadowhints
PLUGIN.shadowHints = {
    {
        match = "pnpm",
        message = "pnpm installed its own node. Run `pnpm remove -g node` so vfox's node runs.",
        url = "https://github.com/version-fox/vfox-nodejs/blob/main/docs/pnpm.md",
    },
    {
        match = "mise",
        message = "mise installed its own node. Run `mise unuse -g node` and `mise uninstall --all node` so vfox's node runs.",
        url = "https://github.com/version-fox/vfox-nodejs/blob/main/docs/managers.md#mise",
    },
    {
        match = "asdf",
        message = "asdf installed its own node. Run `asdf uninstall nodejs <version>` and drop it from `.tool-versions` so vfox's node runs.",
        url = "https://github.com/version-fox/vfox-nodejs/blob/main/docs/managers.md#asdf",
    },
    {
        match = "nvm",
        message = "nvm installed its own node. Run `nvm deactivate` in this shell so vfox's node runs.",
        url = "https://github.com/version-fox/vfox-nodejs/blob/main/docs/managers.md#nvm",
    },
    {
        match = "homebrew",
        message = "Homebrew installed its own node. Run `brew unlink node` (or `brew uninstall node`) so vfox's node runs.",
        url = "https://github.com/version-fox/vfox-nodejs/blob/main/docs/managers.md#homebrew",
    },
    {
        match = "nodejs",
        message = "A Node.js installed outside vfox (winget or the official installer) comes before vfox in PATH. Run `winget uninstall -e --id OpenJS.NodeJS` so vfox's node runs.",
        url = "https://github.com/version-fox/vfox-nodejs/blob/main/docs/managers.md#winget-and-the-official-installer",
    },
}
