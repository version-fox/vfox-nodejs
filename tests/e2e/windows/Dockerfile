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

# One Dockerfile for both Windows images, so the slow part (base pull plus
# tool installs) runs once per host:
#
#   tools   stock servercore plus pwsh, Git for Windows and the pinned Go
#   runner  compose target (compose.amd64.yaml / compose.arm64.yaml) that
#           runs `go test` against the host daemon
#   e2e     the per-combo target image, built by e2e_test.go
#
# compose builds `runner` first; the suite then builds the final stage from
# the same context and build args, so `tools` is a cache hit and only the
# plugin COPY layers are new. The Go in `tools` is also what builds
# vfox@main inside each combo (GO_VERSION must match goWindowsVersion in
# setup.go, which the suite asserts).
ARG BASE_IMAGE=mcr.microsoft.com/windows/servercore:ltsc2025-KB5122871-amd64
FROM ${BASE_IMAGE} AS tools

SHELL ["powershell", "-NoProfile", "-Command"]

ARG GO_VERSION=1.27.1
COPY tests/e2e/windows/bootstrap-tools.ps1 C:\bootstrap-tools.ps1
RUN powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bootstrap-tools.ps1'

FROM tools AS runner

# Short module/build caches, kept out of the slot profiles; C:\m is also
# the compose module-cache volume.
RUN New-Item -ItemType Directory -Force -Path 'C:\m', 'C:\b' | Out-Null
ENV GOMODCACHE=C:\m
ENV GOCACHE=C:\b

FROM tools AS e2e

WORKDIR C:\e2e

COPY metadata.lua C:\e2e\metadata.lua
COPY hooks C:\e2e\hooks
COPY lib C:\e2e\lib

# Long-lived container: the Go test (e2e_test.go) drives every phase through
# pwsh exec calls, so the main process just idles here.
ENTRYPOINT ["C:/Program Files/PowerShell/7/pwsh.exe", "-NoProfile", "-Command"]
CMD ["while ($true) { Start-Sleep 3600 }"]
