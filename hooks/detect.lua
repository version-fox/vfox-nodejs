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

local util = require("util")
--- Find the Node.js installs on this machine that vfox did not install, so
--- that `vfox link --detect nodejs` can link them: the nvm, mise, asdf and
--- Homebrew Cellar directories with a working `node` in them, and the winget
--- directory on Windows. Each entry carries the plain release number the
--- binary reports, and vfox skips what is installed or linked already.
--- Shims report nothing stable and are skipped.
--- @param ctx table Context information (unused)
function PLUGIN:Detect(ctx)
    return util.detect_nodejs()
end
