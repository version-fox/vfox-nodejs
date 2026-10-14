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

package wsl

import (
	"context"
	"fmt"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"

	"github.com/version-fox/vfox-nodejs/tests/e2e/common"
)

// NOTE: the markers asserted here are part of the plugin's or vfox's
// user-facing contract (see hooks/ lib/). If either side rewords them,
// update this file and tests/e2e/linux/verify.go together.

// nodeArch maps uname -m to the arch string the official binaries report
// through process.arch.
var nodeArch = map[string]string{
	"x86_64":  "x64",
	"aarch64": "arm64",
}

// verifyToolchain runs node and npm through the activate hook and checks the
// candidate matches the requested version, platform and architecture, and
// that `vfox current` points at it. Returns the bundled npm version for the
// later search cross-check.
//
// On top of the Linux container suite it carries the regression probes for
// https://github.com/version-fox/vfox-nodejs/issues/32 (install succeeds but
// node is not on PATH): the resolved node binary must live under the slot's
// VFOX_HOME, and `vfox env` must export the SDK bin directory.
func verifyToolchain(ctx context.Context, t *testing.T, s slot, version, machine string) string {
	t.Helper()
	wantArch, ok := nodeArch[machine]
	if !ok {
		t.Fatalf("no node process.arch mapping for %s", machine)
	}

	// Capture vfox's state and the exact shell export before executing node,
	// so an empty PATH export is distinguishable from a missing executable.
	current := execOK(ctx, t, "vfox current", s.env()...)
	envExport := execOK(ctx, t, "vfox env -s bash", s.env()...)
	t.Logf("vfox current:\n%s\nvfox env -s bash:\n%s", current, envExport)

	// The issue #32 symptom first: node must resolve at all.
	diagnosticScript := activated(`printf 'PATH=%s\n' "$PATH"; ` +
		`ls -ld "$HOME/.vfox/sdks/nodejs" "$HOME/.vfox/sdks/nodejs/bin" 2>&1 || true; ` +
		`find "$VFOX_HOME/installs" -maxdepth 8 \( -name node -o -name node.exe \) -print -exec ls -l {} \; 2>&1; ` +
		`command -v node`)
	code, out := execRun(ctx, t, diagnosticScript, s.env()...)
	require.Zero(t, code, "node not found on PATH after install (issue #32)\n--- vfox current ---\n%s\n--- vfox env ---\n%s\n--- PATH and SDK files ---\n%s", current, envExport, out)
	trimmedOutput := strings.TrimSpace(out)
	nodePath := trimmedOutput[strings.LastIndex(trimmedOutput, "\n")+1:]
	require.Containsf(t, nodePath, ".vfox",
		"node must resolve under VFOX_HOME %s, not the Windows interop PATH (issue #32)\n--- node path ---\n%s",
		s.vfoxHome, nodePath)

	require.Containsf(t, envExport, "nodejs",
		"vfox env must export the nodejs SDK path (issue #32)\n--- vfox env ---\n%s", envExport)

	out = execRetry(ctx, t, s.slug+" node --version", activated("node --version"), s.env()...)
	require.Equalf(t, "v"+version, strings.TrimSpace(out), "node --version")

	platform := strings.TrimSpace(execOK(ctx, t, activated("node -p process.platform"), s.env()...))
	require.Equal(t, "linux", platform, "node -p process.platform")

	gotArch := strings.TrimSpace(execOK(ctx, t, activated("node -p process.arch"), s.env()...))
	require.Equalf(t, wantArch, gotArch, "node -p process.arch (the %s/%s package must be installed)", platform, machine)

	npm := strings.TrimSpace(execRetry(ctx, t, s.slug+" npm --version", activated("npm --version"), s.env()...))
	require.Regexp(t, `^\d+\.\d+\.\d+$`, npm, "npm --version")

	current = execOK(ctx, t, activated("vfox current"), s.env()...)
	require.Contains(t, current, "nodejs", "vfox current")
	require.Contains(t, current, version, "vfox current version")
	require.NotContains(t, current, "N/A", "vfox current must select the installed nodejs")

	t.Logf("PASS node v%s (wsl/%s), npm %s, node at %s", version, gotArch, npm, nodePath)
	return npm
}

// verifyShorthand proves PreUse resolves the major and major.minor shorthands
// against the installed versions, without another download.
func verifyShorthand(ctx context.Context, t *testing.T, s slot, version string) {
	t.Helper()
	parts := strings.SplitN(version, ".", 3)
	for _, shorthand := range []string{parts[0], parts[0] + "." + parts[1]} {
		execOK(ctx, t, activated(fmt.Sprintf("vfox use --global nodejs@%s", shorthand)), s.env()...)
		out := execRetry(ctx, t, s.slug+" node --version after nodejs@"+shorthand, activated("node --version"), s.env()...)
		require.Equalf(t, "v"+version, strings.TrimSpace(out),
			"nodejs@%s must resolve to the installed %s", shorthand, version)
	}
	t.Logf("PASS major / major.minor shorthands resolve to %s", version)
}

// verifySearch checks the plugin's Available output through `vfox search`:
// the installed release is listed with the npm addition matching the npm the
// binary actually ships.
func verifySearch(ctx context.Context, t *testing.T, s slot, version, npm string) {
	t.Helper()
	out := execRetry(ctx, t, s.slug+" vfox search nodejs", "vfox search nodejs", s.env()...)
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
func verifyLegacyFiles(ctx context.Context, t *testing.T, s slot, pinned, lts string) {
	t.Helper()
	// Each probe activates inside its own exec rather than relying on the
	// caller's PATH: activation selects a fresh shell session, so the
	// `vfox env` state cache (~/.vfox/tmp/<date>-<pid>/env-state.json) from
	// earlier probes can never answer a probe with the previous selection.
	// The probe prints the resolved node path plus its version, so failures
	// show where node came from.
	run := func(dir string) string {
		t.Helper()
		return strings.TrimSpace(execRetry(ctx, t, s.slug+" node in "+dir,
			fmt.Sprintf("cd %q && %s", dir, activated("command -v node && node --version")),
			s.env()...))
	}
	write := func(dir, name, content string) {
		t.Helper()
		execOK(ctx, t, fmt.Sprintf("mkdir --parents %q && printf '%%s' %q > %q/%s",
			dir, content, dir, name), s.env()...)
	}
	assertProbe := func(got, want, what string) {
		t.Helper()
		require.Truef(t, strings.HasSuffix(got, "v"+want),
			"%s must resolve to %s over the global latest\n--- node path and version ---\n%s", what, want, got)
	}

	write("/tmp/wsl-e2e-legacy-nvmrc", ".nvmrc", pinned)
	assertProbe(run("/tmp/wsl-e2e-legacy-nvmrc"), pinned, ".nvmrc "+pinned)

	write("/tmp/wsl-e2e-legacy-node-version", ".node-version", pinned)
	assertProbe(run("/tmp/wsl-e2e-legacy-node-version"), pinned, ".node-version "+pinned)

	codename, known := common.LTSCodename(lts)
	if !known {
		t.Logf("SKIP LTS codename probe: %s is not in the plugin's codename table", lts)
		return
	}
	execOK(ctx, t, "vfox config legacyVersionFile.strategy latest_installed", s.env()...)
	defer func() {
		_, _ = execRun(ctx, t, "vfox config legacyVersionFile.strategy specified", s.env()...)
	}()
	write("/tmp/wsl-e2e-legacy-lts", ".nvmrc", "lts/"+codename)
	assertProbe(run("/tmp/wsl-e2e-legacy-lts"), lts, "lts/"+codename+" under latest_installed")
	t.Logf("PASS legacy files select %s (.nvmrc, .node-version) and %s (lts/%s)", pinned, lts, codename)
}
