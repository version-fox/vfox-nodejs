// Copyright 2026 Han Li and contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package windows

import (
	"context"
	"fmt"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
	tc "github.com/testcontainers/testcontainers-go"

	"github.com/version-fox/vfox-nodejs/tests/e2e/common"
)

// Node.js defaults live in the common package; only the Windows-specific
// toolchain pin stays here.
const (
	// toolsMount is where every combo container sees the host tools dir
	// that run.ps1 prepares (pwsh, git, go, vfox-main), read-only.
	toolsMount = `C:\tools`

	// spacedVfoxHome is the default vfox home of a Windows account whose
	// name contains a space, the layout reported in
	// https://github.com/version-fox/vfox-flutter/issues/33 . Every combo
	// runs against it: vfox handles such paths since 1.0.13
	// (https://github.com/version-fox/vfox/pull/712), so the latest release
	// and main both carry the fix.
	spacedVfoxHome = `C:\Users\John Doe\.vfox`
)

// pwshQuote renders a single-quoted PowerShell string literal.
func pwshQuote(s string) string {
	return "'" + strings.ReplaceAll(s, "'", "''") + "'"
}

// releasesIndex returns the mirror's Node.js version index
// (the plugin's Available endpoint).
func releasesIndex(mirror string) string {
	return strings.TrimSuffix(mirror, "/") + "/index.json"
}

// checkMirrorReachable fails fast when the mirror does not serve the version
// index. The default mirror is not probed: it is nodejs.org/dist itself.
func checkMirrorReachable(ctx context.Context, t *testing.T, ctr tc.Container, mirror string) {
	t.Helper()
	if mirror == "default" {
		return
	}
	index := releasesIndex(mirror)
	execRetry(ctx, t, ctr, "mirror "+index,
		fmt.Sprintf("curl.exe -fsSL --max-time 20 -o NUL %s", pwshQuote(index)))
	t.Logf("PASS mirror %s serves the version index", mirror)
}

// withEnv returns box.vars plus extra entries, without mutating the shared
// backing array.
func withEnv(box slotBox, extra ...string) []string {
	out := make([]string, 0, len(box.vars)+len(extra))
	out = append(out, box.vars...)
	return append(out, extra...)
}

// slotBox carries the per-combo isolated profile locations plus the exec env
// overrides that apply them (each exec starts a fresh process, so the
// $env: assignments cannot persist and must ride along).
type slotBox struct {
	slot     string
	slotRoot string
	tmp      string
	workDir  string
	vfoxExe  string
	pluginZw string
	vars     []string
}

// setupSlotEnv isolates the combo: USERPROFILE/TEMP/TMP point under
// vfox-e2e-runs\<slot>, while VFOX_HOME is spacedVfoxHome. Every combo runs
// in its own container, so that shared home never mixes vfox state.
func setupSlotEnv(ctx context.Context, t *testing.T, ctr tc.Container, slot string) slotBox {
	t.Helper()
	userProfile := strings.TrimSpace(execOK(ctx, t, ctr, "$env:USERPROFILE"))
	containerPath := strings.TrimSpace(execOK(ctx, t, ctr, "$env:PATH"))
	procArch := strings.TrimSpace(execOK(ctx, t, ctr, "$env:PROCESSOR_ARCHITECTURE"))

	box := slotBox{slot: slot}
	box.slotRoot = userProfile + `\vfox-e2e-runs\` + slot
	box.tmp = box.slotRoot + `\tmp`
	box.workDir = box.tmp + `\vfox-nodejs-e2e`
	box.vfoxExe = box.workDir + `\vfox.exe`
	box.pluginZw = box.workDir + `\nodejs.zip`
	box.vars = []string{
		"USERPROFILE=" + box.slotRoot,
		"VFOX_HOME=" + spacedVfoxHome,
		"TEMP=" + box.tmp,
		"TMP=" + box.tmp,
		"PATH=" + box.workDir + ";" + containerPath,
	}

	execOK(ctx, t, ctr, fmt.Sprintf(
		"New-Item -ItemType Directory -Force -Path %s | Out-Null; "+
			"New-Item -ItemType Directory -Force -Path %s | Out-Null; "+
			"New-Item -ItemType Directory -Force -Path %s | Out-Null",
		pwshQuote(box.tmp), pwshQuote(box.workDir), pwshQuote(spacedVfoxHome)))
	t.Logf("PASS slot %s isolated at %s (vfox home %s, arch %s)", slot, box.slotRoot, spacedVfoxHome, procArch)
	return box
}

// procArchOfContainer reports $env:PROCESSOR_ARCHITECTURE (AMD64/ARM64/x86).
func procArchOfContainer(ctx context.Context, t *testing.T, ctr tc.Container) string {
	t.Helper()
	return strings.TrimSpace(execOK(ctx, t, ctr, "$env:PROCESSOR_ARCHITECTURE"))
}

// curlRetry flags shared by every curl.exe download.
const curlRetry = "--retry 3 --retry-delay 5 --retry-all-errors"

// installVfoxRelease resolves the latest vfox tag, downloads the windows
// zip, extracts it, and stages vfox.exe into the work dir.
func installVfoxRelease(ctx context.Context, t *testing.T, ctr tc.Container, box slotBox, procArch string) {
	t.Helper()
	effective := strings.TrimSpace(execOK(ctx, t, ctr,
		`curl.exe `+curlRetry+` -fsSLI -o NUL -w '%{url_effective}' https://github.com/version-fox/vfox/releases/latest`,
		box.vars...))
	parts := strings.Split(effective, "/tag/")
	tag := strings.TrimSpace(parts[len(parts)-1])
	if tag == "" {
		t.Fatalf("could not resolve the latest vfox tag from %q", effective)
	}
	vfoxArch := "x86_64"
	if procArch == "ARM64" {
		vfoxArch = "aarch64"
	}
	zipPath := box.workDir + `\vfox.zip`
	url := fmt.Sprintf("https://github.com/version-fox/vfox/releases/download/%s/vfox_%s_windows_%s.zip",
		tag, strings.TrimPrefix(tag, "v"), vfoxArch)
	execOK(ctx, t, ctr, fmt.Sprintf(
		"curl.exe %s -fsSL -o %s %s",
		curlRetry, pwshQuote(zipPath), pwshQuote(url)), box.vars...)
	execOK(ctx, t, ctr, fmt.Sprintf(
		"tar -xf %s -C %s; Remove-Item %s; "+
			"Copy-Item -Path (Get-ChildItem -Path %s -Recurse -Filter 'vfox.exe') -Destination %s",
		pwshQuote(zipPath), pwshQuote(box.workDir), pwshQuote(zipPath),
		pwshQuote(box.workDir), pwshQuote(box.vfoxExe)), box.vars...)
	t.Logf("PASS installed vfox %s (%s)", tag, vfoxArch)
}

// installVfoxMain stages the vfox.exe that run.ps1 built from main on the
// host (once per run, with the pinned Go) from the read-only tools mount.
func installVfoxMain(ctx context.Context, t *testing.T, ctr tc.Container, box slotBox) {
	t.Helper()
	built := toolsMount + `\vfox-main\vfox.exe`
	execOK(ctx, t, ctr, fmt.Sprintf(
		"if (-not (Test-Path %s)) { throw 'FAIL no vfox@main build in the tools mount (run the suite via run.ps1)' }; "+
			"Copy-Item -Path %s -Destination %s",
		pwshQuote(built), pwshQuote(built), pwshQuote(box.vfoxExe)), box.vars...)
	t.Logf("PASS staged vfox built from main: %s", strings.TrimSpace(execOK(ctx, t, ctr, "vfox --version", box.vars...)))
}

// setupVfox installs vfox (release, or builds main) and registers the local
// nodejs plugin.
func setupVfox(ctx context.Context, t *testing.T, ctr tc.Container, box slotBox, vfoxVersion string) {
	t.Helper()
	if vfoxVersion == "main" {
		installVfoxMain(ctx, t, ctr, box)
	} else {
		installVfoxRelease(ctx, t, ctr, box, procArchOfContainer(ctx, t, ctr))
	}
	execOK(ctx, t, ctr, fmt.Sprintf(
		"tar -a -cf %s -C 'C:\\e2e' metadata.lua hooks lib",
		pwshQuote(box.pluginZw)), box.vars...)
	execOK(ctx, t, ctr,
		fmt.Sprintf("vfox add nodejs --source %s", pwshQuote(box.pluginZw)), box.vars...)
}

// fetchActivation captures `vfox activate pwsh` once per container; the
// output is prepended to later scripts via activated()/activatedEnv(), since
// each exec starts a fresh process and the $env: assignments cannot persist.
func fetchActivation(ctx context.Context, t *testing.T, ctr tc.Container, box slotBox) string {
	t.Helper()
	out := execOK(ctx, t, ctr, "vfox activate pwsh", box.vars...)
	if strings.TrimSpace(out) == "" {
		t.Fatal("vfox activate pwsh produced no output")
	}
	return out
}

// activated prepends captured activation code to a script. `vfox use` needs
// the activation context ("vfox requires hook support" otherwise).
func activated(activation, script string) string {
	return activation + "\r\n" + script
}

// activatedEnv is activated plus a fresh `vfox env` export. vfox's pwsh
// activation refreshes the toolchain env lazily through a prompt hook, which
// never runs in non-interactive `pwsh -Command` execs, so each call must pull
// the export explicitly (mirrors what the prompt hook itself runs).
// Only valid after a version is selected via `vfox use`.
func activatedEnv(activation, script string) string {
	return activation + "\r\n$__vfoxExport = vfox env -s pwsh | Out-String; " +
		"if ($__vfoxExport.Trim()) { Invoke-Expression -Command $__vfoxExport }\r\n" + script
}

// checkBogusMirrorRejected proves `latest` resolution honours
// $VFOX_NODEJS_MIRROR: Available() hits the bogus host and the install fails
// naming it. If the plugin ignored the env var, the default mirror would
// serve the index and the install would proceed.
func checkBogusMirrorRejected(ctx context.Context, t *testing.T, ctr tc.Container, box slotBox) {
	t.Helper()
	code, out := execRun(ctx, t, ctr,
		"vfox install nodejs@latest",
		withEnv(box, "VFOX_NODEJS_MIRROR="+common.BogusMirror)...)
	require.NotEqualf(t, 0, code, "bogus mirror install unexpectedly succeeded\n--- output ---\n%s", out)
	require.Contains(t, out, "invalid.example.invalid", "bogus mirror error")
}

// checkBogusMirrorVersionRejected proves a pinned install also honours
// $VFOX_NODEJS_MIRROR: PreInstall fetches SHASUMS256.txt from the bogus host
// and fails instead of silently falling back to the default mirror.
func checkBogusMirrorVersionRejected(ctx context.Context, t *testing.T, ctr tc.Container, box slotBox, version string) {
	t.Helper()
	code, out := execRun(ctx, t, ctr,
		"vfox install "+pwshQuote("nodejs@"+version),
		withEnv(box, "VFOX_NODEJS_MIRROR="+common.BogusMirror)...)
	require.NotEqualf(t, 0, code, "bogus mirror install unexpectedly succeeded\n--- output ---\n%s", out)
	require.Contains(t, out, "get checksum failed", "bogus mirror checksum fetch")
}
