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

--- Fail fast when the musl Node.js binary cannot run: it needs libstdc++,
--- which musl distributions do not install by default. Without this check
--- the install looks successful and only `node --version` fails later with
--- `Error relocating ... symbol not found`.
--- See https://github.com/version-fox/vfox-nodejs/issues/29
--- @param ctx table Context information
function PLUGIN:PostInstall(ctx)
    if RUNTIME.osType ~= "linux" then
        return
    end
    if not util.is_musl() then
        return
    end
    if util.has_libstdcxx() then
        return
    end
    error(
        "Node.js (musl build) requires "
            .. util.libstdcxx_hint()
            .. ", which was not found on this system. It is normally installed automatically;"
            .. " install it and reinstall. See "
            .. util.ReadmeUrl
    )
end
