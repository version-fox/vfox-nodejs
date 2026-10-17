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

$ErrorActionPreference = 'Stop'

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

if (-not $env:GO_VERSION) { throw 'FAIL GO_VERSION is not set (Dockerfile ARG)' }

$IsArm64 = $env:PROCESSOR_ARCHITECTURE -eq 'ARM64'
$pwshArch = if ($IsArm64) { 'arm64' } else { 'x64' }
$goArch = if ($IsArm64) { 'arm64' } else { 'amd64' }
$gitAsset = if ($IsArm64) { 'Git-2.55.0.5-arm64.exe' } else { 'Git-2.55.0.5-64-bit.exe' }

# pwsh and Go ship as zips and are unpacked with tar.exe: msiexec inside a
# container is the slow path (minutes per MSI on the hosted runners), while
# the zips are the same payload the official golang / powershell Windows
# images unpack. Git keeps its installer, so Git Bash stays a stock Git for
# Windows install; it runs while the zips are unpacked.
$pwshArchive = "$env:TEMP\pwsh.zip"
$pwshUrl = "https://github.com/PowerShell/PowerShell/releases/download/v7.6.6/PowerShell-7.6.6-win-$pwshArch.zip"
$goArchive = "$env:TEMP\go.zip"
$goUrl = "https://go.dev/dl/go$($env:GO_VERSION).windows-$goArch.zip"
$gitInstaller = "$env:TEMP\git-installer.exe"
$gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.55.0.windows.5/$gitAsset"

$pwshHome = 'C:\Program Files\PowerShell\7'
$goHome = 'C:\Program Files\Go'

Invoke-Native {
    & curl.exe -fsSL --retry 3 --retry-delay 5 --retry-all-errors --parallel `
        -o $pwshArchive $pwshUrl -o $goArchive $goUrl -o $gitInstaller $gitUrl
} 'the tool downloads'

$gitSetup = Start-Process $gitInstaller -PassThru -ArgumentList '/VERYSILENT', '/NORESTART', '/SP-', '/SUPPRESSMSGBOXES'
# Touch the handle now, or ExitCode stays empty once the process is gone.
$null = $gitSetup.Handle

New-Item -ItemType Directory -Force -Path $pwshHome | Out-Null
Invoke-Native { & tar.exe -xf $pwshArchive -C $pwshHome } 'the PowerShell unpack'
# The Go zip has a single top-level go\ directory.
Invoke-Native { & tar.exe -xf $goArchive -C 'C:\Program Files' } 'the Go unpack'
Remove-Item $pwshArchive, $goArchive

$gitSetup.WaitForExit()
if ($gitSetup.ExitCode -ne 0) { throw "FAIL the Git installer exited with code $($gitSetup.ExitCode)" }
Remove-Item $gitInstaller

if (-not (Test-Path "$pwshHome\pwsh.exe")) { throw 'FAIL pwsh.exe is missing after the PowerShell unpack' }
if (-not (Test-Path "$goHome\bin\go.exe")) { throw 'FAIL go.exe is missing after the Go unpack' }
if (-not (Test-Path 'C:\Program Files\Git\cmd\git.exe')) { throw 'FAIL git.exe is missing after the Git installer' }

# The zips do not touch PATH (the MSIs did). Append after the Git installer
# finished, since it rewrites the machine PATH itself.
$machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
[Environment]::SetEnvironmentVariable('Path', "$machinePath;$pwshHome;$goHome\bin", 'Machine')

Invoke-Native { & "$pwshHome\pwsh.exe" -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' } 'pwsh'
Invoke-Native { & "$goHome\bin\go.exe" version } 'go version'
Invoke-Native { & 'C:\Program Files\Git\cmd\git.exe' config --system core.longpaths true } 'enable system-wide git long paths'
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -Value 1 -PropertyType DWORD -Force | Out-Null
