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

// NOTE: the markers asserted here are part of the plugin's or vfox's
// user-facing contract (see hooks/ lib/). If either side rewords them,
// update this file and tests/e2e/linux/verify.go together.

// nodeArch maps $env:PROCESSOR_ARCHITECTURE to the arch string the official
// binaries report through process.arch.
var nodeArch = map[string]string{
	"AMD64": "x64",
	"ARM64": "arm64",
}

// verifyToolchain runs node and npm through the activate + env hooks and
// checks the candidate matches the requested version, platform and
// architecture, and that `vfox current` points at it. Returns the bundled
// npm version for the later search cross-check.
func verifyToolchain(ctx context.Context, t *testing.T, ctr tc.Container, box slotBox, activation, version string) string {
	t.Helper()
	procArch := procArchOfContainer(ctx, t, ctr)
	wantArch, ok := nodeArch[procArch]
	if !ok {
		t.Fatalf("no node process.arch mapping for %s", procArch)
	}

	out := execRetry(ctx, t, ctr, "node --version",
		activatedEnv(activation, "node --version"), box.vars...)
	require.Equalf(t, "v"+version, strings.TrimSpace(out), "node --version")

	platform := strings.TrimSpace(execOK(ctx, t, ctr,
		activatedEnv(activation, "node -p process.platform"), box.vars...))
	require.Equal(t, "win32", platform, "node -p process.platform")

	gotArch := strings.TrimSpace(execOK(ctx, t, ctr,
		activatedEnv(activation, "node -p process.arch"), box.vars...))
	require.Equalf(t, wantArch, gotArch, "node -p process.arch (the windows/%s package must be installed)", wantArch)

	npm := strings.TrimSpace(execRetry(ctx, t, ctr, "npm --version",
		activatedEnv(activation, "npm --version"), box.vars...))
	require.Regexp(t, `^\d+\.\d+\.\d+$`, npm, "npm --version")

	current := execOK(ctx, t, ctr, "vfox current", box.vars...)
	require.Contains(t, current, "nodejs", "vfox current")
	require.Contains(t, current, version, "vfox current version")
	require.NotContains(t, current, "N/A", "vfox current must select the installed nodejs")

	t.Logf("PASS node v%s (windows/%s), npm %s", version, gotArch, npm)
	return npm
}

// verifyShorthand proves PreUse resolves the major and major.minor shorthands
// against the installed versions, without another download.
func verifyShorthand(ctx context.Context, t *testing.T, ctr tc.Container, box slotBox, activation, version string) {
	t.Helper()
	parts := strings.SplitN(version, ".", 3)
	for _, shorthand := range []string{parts[0], parts[0] + "." + parts[1]} {
		execOK(ctx, t, ctr, activated(activation, "vfox use --global "+pwshQuote("nodejs@"+shorthand)), box.vars...)
		out := execRetry(ctx, t, ctr, "node --version after nodejs@"+shorthand,
			activatedEnv(activation, "node --version"), box.vars...)
		require.Equalf(t, "v"+version, strings.TrimSpace(out),
			"nodejs@%s must resolve to the installed %s", shorthand, version)
	}
	t.Logf("PASS major / major.minor shorthands resolve to %s", version)
}

// verifySearch checks the plugin's Available output through `vfox search`:
// the installed release is listed with the npm addition matching the npm the
// binary actually ships.
func verifySearch(ctx context.Context, t *testing.T, ctr tc.Container, box slotBox, version, npm string) {
	t.Helper()
	out := execRetry(ctx, t, ctr, "vfox search nodejs", "vfox search nodejs", box.vars...)
	addition, ok := common.SearchNpm(out, version)
	require.Truef(t, ok, "vfox search does not list %s with its npm addition\n--- output ---\n%s", version, out)
	require.Equalf(t, npm, addition,
		"the npm addition for %s must match the bundled npm", version)
	t.Logf("PASS vfox search lists nodejs %s with npm %s", version, addition)
}

// verifyLegacyFiles proves ParseLegacyFile drives selection from the legacy
// config files vfox searches for, in this order:
//
//  1. .nvmrc and .node-version holding the exact pinned version (the default
//     `specified` strategy), with the global set to a different release;
//  2. .nvmrc holding an LTS codename under the `latest_installed` strategy,
//     which resolves through the plugin's codename table to the LTS release
//     (see docs/lts.md).
//
// Every probe runs in its own freshly activated shell session; node may only
// come from the env the legacy file selects, so a fallback to the global
// (latest) release fails the assertion.
func verifyLegacyFiles(ctx context.Context, t *testing.T, ctr tc.Container, box slotBox, pinned, lts string) {
	t.Helper()
	// Each probe captures its own `vfox activate` rather than reusing the
	// combo's shared activation: activation pins __VFOX_PID, which scopes the
	// `vfox env` state cache (~/.vfox/tmp/<date>-<pid>/env-state.json).
	// Reusing one activation for every exec would let the cached output of
	// the previous (global) selection answer the legacy probe unchanged; a
	// fresh activation is a new session without cache, exactly like a newly
	// opened terminal. The probe prints the resolved node path plus its
	// version, so failures show where node came from.
	run := func(dir string) string {
		t.Helper()
		script := fmt.Sprintf(
			"Invoke-Expression -Command (vfox activate pwsh | Out-String); "+
				"Set-Location -LiteralPath %s; "+
				"$__vfoxExport = vfox env -s pwsh | Out-String; "+
				"if ($__vfoxExport.Trim()) { Invoke-Expression -Command $__vfoxExport }; "+
				"(Get-Command node -CommandType Application | Select-Object -First 1).Source; "+
				"node --version", pwshQuote(dir))
		return strings.TrimSpace(execRetry(ctx, t, ctr, "node in "+dir, script, box.vars...))
	}
	write := func(dir, name, content string) {
		t.Helper()
		execOK(ctx, t, ctr, fmt.Sprintf(
			"New-Item -ItemType Directory -Force -Path %s | Out-Null; "+
				"Set-Content -NoNewline -Path %s -Value %s",
			pwshQuote(dir), pwshQuote(dir+`\`+name), pwshQuote(content)), box.vars...)
	}
	assertProbe := func(got, want, what string) {
		t.Helper()
		require.Truef(t, strings.HasSuffix(got, "v"+want),
			"%s must resolve to %s over the global latest\n--- node path and version ---\n%s", what, want, got)
	}

	write(`C:\e2e-legacy-nvmrc`, ".nvmrc", pinned)
	assertProbe(run(`C:\e2e-legacy-nvmrc`), pinned, ".nvmrc "+pinned)

	write(`C:\e2e-legacy-node-version`, ".node-version", pinned)
	assertProbe(run(`C:\e2e-legacy-node-version`), pinned, ".node-version "+pinned)

	codename, known := common.LTSCodename(lts)
	if !known {
		t.Logf("SKIP LTS codename probe: %s is not in the plugin's codename table", lts)
		return
	}
	execOK(ctx, t, ctr, "vfox config legacyVersionFile.strategy latest_installed", box.vars...)
	defer func() {
		_, _ = execRun(ctx, t, ctr, "vfox config legacyVersionFile.strategy specified", box.vars...)
	}()
	write(`C:\e2e-legacy-lts`, ".nvmrc", "lts/"+codename)
	assertProbe(run(`C:\e2e-legacy-lts`), lts, "lts/"+codename+" under latest_installed")
	t.Logf("PASS legacy files select %s (.nvmrc, .node-version) and %s (lts/%s)", pinned, lts, codename)
}
