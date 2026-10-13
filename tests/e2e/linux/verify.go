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

package linux

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
// update this file and tests/e2e/windows/verify.go together.

// nodeArch maps the docker architecture to the arch string the official
// binaries report through process.arch.
var nodeArch = map[string]string{
	"amd64": "x64",
	"arm64": "arm64",
}

// verifyToolchain runs node and npm through the activate hook and checks the
// candidate matches the requested version, platform and architecture, and
// that `vfox current` points at it. Returns the bundled npm version for the
// later search cross-check.
func verifyToolchain(ctx context.Context, t *testing.T, ctr tc.Container, version, arch string) string {
	t.Helper()
	wantArch, ok := nodeArch[arch]
	if !ok {
		t.Fatalf("no node process.arch mapping for %s", arch)
	}

	out := execRetry(ctx, t, ctr, "node --version", activated("node --version"))
	require.Equalf(t, "v"+version, strings.TrimSpace(out), "node --version")

	platform := strings.TrimSpace(execOK(ctx, t, ctr, activated("node -p process.platform")))
	require.Equal(t, "linux", platform, "node -p process.platform")

	gotArch := strings.TrimSpace(execOK(ctx, t, ctr, activated("node -p process.arch")))
	require.Equalf(t, wantArch, gotArch, "node -p process.arch (the %s/%s package must be installed)", platform, arch)

	npm := strings.TrimSpace(execRetry(ctx, t, ctr, "npm --version", activated("npm --version")))
	require.Regexp(t, `^\d+\.\d+\.\d+$`, npm, "npm --version")

	current := execOK(ctx, t, ctr, activated("vfox current"))
	require.Contains(t, current, "nodejs", "vfox current")
	require.Contains(t, current, version, "vfox current version")
	require.NotContains(t, current, "N/A", "vfox current must select the installed nodejs")

	t.Logf("PASS node v%s (linux/%s), npm %s", version, gotArch, npm)
	return npm
}

// verifyShorthand proves PreUse resolves the major and major.minor shorthands
// against the installed versions, without another download.
func verifyShorthand(ctx context.Context, t *testing.T, ctr tc.Container, version string) {
	t.Helper()
	parts := strings.SplitN(version, ".", 3)
	for _, shorthand := range []string{parts[0], parts[0] + "." + parts[1]} {
		execOK(ctx, t, ctr, activated(fmt.Sprintf("vfox use --global nodejs@%s", shorthand)))
		out := execRetry(ctx, t, ctr, "node --version after nodejs@"+shorthand, activated("node --version"))
		require.Equalf(t, "v"+version, strings.TrimSpace(out),
			"nodejs@%s must resolve to the installed %s", shorthand, version)
	}
	t.Logf("PASS major / major.minor shorthands resolve to %s", version)
}

// verifySearch checks the plugin's Available output through `vfox search`:
// the installed release is listed with the npm addition matching the npm the
// binary actually ships.
func verifySearch(ctx context.Context, t *testing.T, ctr tc.Container, version, npm string) {
	t.Helper()
	out := execRetry(ctx, t, ctr, "vfox search nodejs", "vfox search nodejs")
	addition, ok := common.SearchNpm(out, version)
	require.Truef(t, ok, "vfox search does not list %s with its npm addition\n--- output ---\n%s", version, out)
	require.Equalf(t, npm, addition,
		"the npm addition for %s must match the bundled npm", version)
	t.Logf("PASS vfox search lists nodejs %s with npm %s", version, addition)
}

// verifyLegacyFiles proves ParseLegacyFile drives selection from the legacy
// config files vfox searches for, in this order:
//
//  1. .nvmrc and .node-version holding the exact version (the default
//     `specified` strategy), with the global set to a different release;
//  2. .nvmrc holding an LTS codename under the `latest_installed` strategy,
//     which resolves through the plugin's codename table.
//
// Every probe runs in its own freshly activated shell session; node may only
// come from the env the legacy file selects, so a fallback to the global
// (latest) release fails the assertion.
func verifyLegacyFiles(ctx context.Context, t *testing.T, ctr tc.Container, pinned string) {
	t.Helper()
	// Each probe activates inside its own exec rather than relying on the
	// caller's PATH: activation selects a fresh shell session, so the
	// `vfox env` state cache (~/.vfox/tmp/<date>-<pid>/env-state.json) from
	// earlier probes can never answer a probe with the previous selection.
	// The probe prints the resolved node path plus its version, so failures
	// show where node came from.
	run := func(dir string) string {
		t.Helper()
		return strings.TrimSpace(execRetry(ctx, t, ctr, "node in "+dir,
			fmt.Sprintf("cd %q && eval \"$(vfox activate bash)\" && eval \"$(vfox env -s bash)\" && command -v node && node --version", dir)))
	}
	write := func(dir, name, content string) {
		t.Helper()
		execOK(ctx, t, ctr, fmt.Sprintf("mkdir --parents %q && printf '%%s' %q > %q/%s",
			dir, content, dir, name))
	}
	assertProbe := func(got, what string) {
		t.Helper()
		require.Truef(t, strings.HasSuffix(got, "v"+pinned),
			"%s must resolve to %s over the global latest\n--- node path and version ---\n%s", what, pinned, got)
	}

	write("/tmp/e2e-legacy-nvmrc", ".nvmrc", pinned)
	assertProbe(run("/tmp/e2e-legacy-nvmrc"), ".nvmrc "+pinned)

	write("/tmp/e2e-legacy-node-version", ".node-version", pinned)
	assertProbe(run("/tmp/e2e-legacy-node-version"), ".node-version "+pinned)

	codename, known := common.LTSCodename(pinned)
	if !known {
		t.Logf("SKIP LTS codename probe: %s is not in the plugin's codename table", pinned)
		return
	}
	execOK(ctx, t, ctr, "vfox config legacyVersionFile.strategy latest_installed")
	defer func() {
		_, _ = execRun(ctx, t, ctr, "vfox config legacyVersionFile.strategy specified")
	}()
	write("/tmp/e2e-legacy-lts", ".nvmrc", "lts/"+codename)
	assertProbe(run("/tmp/e2e-legacy-lts"), "lts/"+codename+" under latest_installed")
	t.Logf("PASS legacy files select %s (.nvmrc, .node-version, lts/%s)", pinned, codename)
}
