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
PLUGIN.version = "0.5.1"
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
