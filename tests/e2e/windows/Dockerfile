# escape=`
# Copyright 2026 Han Li and contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Per-combo image for the Windows container E2E suite, built by e2e_test.go.
# pwsh, Git for Windows and vfox@main are not baked in: run.ps1 fetches them
# on the host and the suite bind-mounts them read-only at C:\tools, because
# committing an image layer with their tens of thousands of files takes
# minutes on the hosted runners. This image only points PATH at the mount
# and adds the plugin files.
ARG BASE_IMAGE=mcr.microsoft.com/windows/servercore:ltsc2025-KB5122871-amd64
FROM ${BASE_IMAGE}

SHELL ["powershell", "-NoProfile", "-Command"]

# NB: no double quotes or backticks inside the command. The classic builder
# wraps it in powershell -Command "..." through cmd.exe, where both break
# parsing. Single quotes only.
RUN [Environment]::SetEnvironmentVariable('Path', [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';C:\tools\pwsh;C:\tools\git\cmd', 'Machine'); `
    New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -Value 1 -PropertyType DWORD -Force | Out-Null

WORKDIR C:\e2e

COPY metadata.lua C:\e2e\metadata.lua
COPY hooks C:\e2e\hooks
COPY lib C:\e2e\lib

# Long-lived container: the Go test (e2e_test.go) drives every phase through
# pwsh exec calls, so the main process just idles here.
ENTRYPOINT ["C:/tools/pwsh/pwsh.exe", "-NoProfile", "-Command"]
CMD ["while ($true) { Start-Sleep 3600 }"]
