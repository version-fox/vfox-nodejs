<#
 Copyright 2026 Han Li and contributors

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
#>

# Host-side runner for the Windows container E2E suite (see docs/e2e.md):
#
#   pwsh -NoProfile -File tests/e2e/windows/run.ps1
#
# $env:E2E_RUN narrows the -test.run pattern (default TestE2E), e.g.
# 'TestE2E/latest-default'; the other knobs are the env vars in docs/e2e.md.
#
# The host needs only Docker in Windows-container mode: curl.exe and tar.exe
# ship with Windows. Everything else is fetched into a per-arch cache
# ($env:E2E_CACHE_DIR, default %LOCALAPPDATA%\vfox-nodejs-e2e\<arch>) and
# never installed or put on the user PATH, so it cannot conflict with a
# vfox-managed toolchain:
#
#   tools\pwsh       PowerShell, unpacked from its zip
#   tools\git        PortableGit (Git for Windows, incl. Git Bash)
#   tools\go         the pinned Go, which compiles the suite and vfox@main
#   tools\vfox-main  vfox.exe built from main for this run
#
# tools\ is bind-mounted read-only at C:\tools into every combo container,
# so the image only adds the plugin files. Unpacking the tools inside an
# image layer instead costs minutes of layer commit on the hosted runners.
# The base image pull (the slowest step) runs in the background while the
# tools are fetched and the suite and vfox@main are compiled.

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

# Local copy of the native-command guard. Fails unless the command exits 0.
function Invoke-Native {
    param(
        [Parameter(Mandatory)] [scriptblock] $Cmd,
        [Parameter(Mandatory)] [string] $What,
        [int[]] $Ok = 0
    )
    $prev = $PSNativeCommandUseErrorActionPreference
    $PSNativeCommandUseErrorActionPreference = $false
    & $Cmd
    $code = $LASTEXITCODE
    $PSNativeCommandUseErrorActionPreference = $prev
    if ($null -eq $code) { throw "FAIL $What did not run" }
    if ($code -notin $Ok) { throw "FAIL $What exited with code $code" }
}

$PwshVersion = '7.6.6'
$GitVersion = '2.55.0.5'
$GitTag = 'v2.55.0.windows.5'
$GoVersion = '1.27.1'

$IsArm64 = $env:PROCESSOR_ARCHITECTURE -eq 'ARM64'
$arch = if ($IsArm64) { 'arm64' } else { 'amd64' }
$pwshArch = if ($IsArm64) { 'arm64' } else { 'x64' }
$gitArch = if ($IsArm64) { 'arm64' } else { '64-bit' }
$baseImage = "mcr.microsoft.com/windows/servercore:ltsc2025-KB5122871-$arch"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$cacheRoot = if ($env:E2E_CACHE_DIR) { $env:E2E_CACHE_DIR } else { Join-Path $env:LOCALAPPDATA "vfox-nodejs-e2e\$arch" }
$toolsRoot = Join-Path $cacheRoot 'tools'
$downloads = Join-Path $cacheRoot 'downloads'
New-Item -ItemType Directory -Force -Path $toolsRoot, $downloads | Out-Null

Write-Output "Pulling $baseImage in the background ..."
$pull = Start-Process docker -ArgumentList 'pull', '--quiet', $baseImage -NoNewWindow -PassThru
# Touch the handle now, or ExitCode stays empty once the process is gone.
$null = $pull.Handle

# Each tool lives in tools\<name> with a .version marker; a missing or stale
# marker refetches it.
$tools = @(
    @{ Name = 'pwsh'; Version = $PwshVersion; File = 'pwsh.zip'
        Url = "https://github.com/PowerShell/PowerShell/releases/download/v$PwshVersion/PowerShell-$PwshVersion-win-$pwshArch.zip" }
    @{ Name = 'git'; Version = $GitVersion; File = 'PortableGit.7z.exe'
        Url = "https://github.com/git-for-windows/git/releases/download/$GitTag/PortableGit-$GitVersion-$gitArch.7z.exe" }
    @{ Name = 'go'; Version = $GoVersion; File = 'go.zip'
        Url = "https://go.dev/dl/go$GoVersion.windows-$arch.zip" }
)
$stale = @($tools | Where-Object {
        $marker = Join-Path $toolsRoot "$($_.Name)\.version"
        -not ((Test-Path $marker) -and ((Get-Content $marker -Raw).Trim() -eq $_.Version))
    })
if ($stale.Count -gt 0) {
    $curlArgs = @('-fsSL', '--retry', '3', '--retry-delay', '5', '--retry-all-errors', '--parallel')
    foreach ($tool in $stale) { $curlArgs += @('-o', (Join-Path $downloads $tool.File), $tool.Url) }
    Invoke-Native { & curl.exe @curlArgs } 'the tool downloads'
    foreach ($tool in $stale) {
        $dir = Join-Path $toolsRoot $tool.Name
        $archive = Join-Path $downloads $tool.File
        if (Test-Path $dir) { Remove-Item -Recurse -Force $dir }
        switch ($tool.Name) {
            'pwsh' {
                New-Item -ItemType Directory -Force -Path $dir | Out-Null
                Invoke-Native { & tar.exe -xf $archive -C $dir } 'the PowerShell unpack'
            }
            'go' {
                # The Go zip has a single top-level go\ directory.
                Invoke-Native { & tar.exe -xf $archive -C $toolsRoot } 'the Go unpack'
            }
            'git' {
                $sfx = Start-Process $archive -ArgumentList '-y', "-o`"$dir`"" -Wait -PassThru
                if ($sfx.ExitCode -ne 0) { throw "FAIL the PortableGit unpack exited with code $($sfx.ExitCode)" }
                # The mount is read-only in the containers, so the first-run
                # setup must finish here (the script deletes itself when done).
                $postInstall = Join-Path $dir 'post-install.bat'
                if (Test-Path $postInstall) {
                    Start-Process (Join-Path $dir 'git-bash.exe') -WorkingDirectory $dir -Wait `
                        -ArgumentList '--no-needs-console', '--hide', '--no-cd', '--command=post-install.bat'
                    $deadline = (Get-Date).AddMinutes(2)
                    while ((Test-Path $postInstall) -and ((Get-Date) -lt $deadline)) { Start-Sleep -Seconds 1 }
                    if (Test-Path $postInstall) { throw 'FAIL the PortableGit post-install did not finish' }
                }
                Invoke-Native { & (Join-Path $dir 'cmd\git.exe') config --system core.longpaths true } 'enable system-wide git long paths'
            }
        }
        Remove-Item $archive
        Set-Content -Path (Join-Path $dir '.version') -Value $tool.Version
        Write-Output "PASS fetched $($tool.Name) $($tool.Version)"
    }
}
else {
    Write-Output "PASS tools cached at $toolsRoot"
}

$git = Join-Path $toolsRoot 'git\cmd\git.exe'
$go = Join-Path $toolsRoot 'go\bin\go.exe'
# Process-scoped only: the cached Go and its caches never touch the user env.
$env:GOTOOLCHAIN = 'local'
$env:CGO_ENABLED = '0'
$env:GOPATH = Join-Path $cacheRoot 'gopath'
$env:GOMODCACHE = Join-Path $cacheRoot 'gomod'
$env:GOCACHE = Join-Path $cacheRoot 'gocache'
Remove-Item Env:GOROOT -ErrorAction SilentlyContinue

# vfox@main is built here, once, instead of inside every main combo.
$vfoxMain = Join-Path $toolsRoot 'vfox-main'
if (Test-Path $vfoxMain) { Remove-Item -Recurse -Force $vfoxMain }
if (-not $env:VFOX_VERSION -or ($env:VFOX_VERSION -split '\s+') -contains 'main') {
    $src = Join-Path $cacheRoot 'vfox-src'
    if (Test-Path $src) { Remove-Item -Recurse -Force $src }
    Invoke-Native { & $git clone --quiet --depth 1 https://github.com/version-fox/vfox $src } 'the vfox clone'
    Invoke-Native { & $go -C $src build -trimpath -o (Join-Path $vfoxMain 'vfox.exe') . } 'the vfox@main build'
    $commit = (& $git -C $src rev-parse --short HEAD).Trim()
    Write-Output "PASS built vfox@main ($commit) with Go $GoVersion ($arch)"
}

$testBin = Join-Path $cacheRoot 'windows.test.exe'
Push-Location (Join-Path $repoRoot 'tests\e2e')
try {
    Invoke-Native { & $go test -c -o $testBin ./windows } 'the suite build'
}
finally {
    Pop-Location
}

$pull.WaitForExit()
if ($pull.ExitCode -ne 0) { throw "FAIL docker pull $baseImage exited with code $($pull.ExitCode)" }
Write-Output "PASS pulled $baseImage"

$env:E2E_TOOLS_DIR = $toolsRoot
$env:E2E_BASE_IMAGE = $baseImage
$runPattern = if ($env:E2E_RUN) { $env:E2E_RUN } else { 'TestE2E' }
# go test runs a test binary from its package directory; do the same.
Push-Location $PSScriptRoot
try {
    # Quoted: PowerShell splits a bare -test.v into -test and .v.
    Invoke-Native { & $testBin '-test.v' '-test.timeout=55m' "-test.run=$runPattern" } 'the Windows E2E suite'
}
finally {
    Pop-Location
}
