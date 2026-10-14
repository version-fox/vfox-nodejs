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

// Package wsl is the WSL E2E suite: it drives the Ubuntu distribution on the
// Windows host directly through wsl.exe (no containers), reproducing
// https://github.com/version-fox/vfox-nodejs/issues/32 — vfox installs
// Node.js inside WSL without errors, yet node is missing from PATH.
//
// The distro must already be installed before `go test` runs (the CI job in
// .github/workflows/e2e.yml provisions it); WSL_DISTRO selects it for local
// runs. Combos run sequentially against the single shared distro, each with
// its own isolated HOME/VFOX_HOME slot (see setup.go), asserting in Go.
// Target-independent logic (matrix expansion and friends) is reused from the
// common package.
//
// Full matrix runs in CI; locally scope it down, e.g.:
//
//	$env:VFOX_VERSION='latest'; $env:MIRROR='default'; go test -v ./wsl/
package wsl

import (
	"context"
	"os/exec"
	"runtime"
	"strings"
	"testing"
	"time"

	"github.com/version-fox/vfox-nodejs/tests/e2e/common"
)

// TestE2E runs one sequential subtest per (vfox version x mirror) combination
// inside the WSL distro. It refuses non-Windows hosts: wsl.exe only exists
// there, and the Linux container suite (tests/e2e/linux) already covers
// native Linux.
func TestE2E(t *testing.T) {
	if testing.Short() {
		t.Skip("skip WSL E2E in short mode")
	}
	if runtime.GOOS != "windows" {
		t.Skip("WSL E2E runs on Windows hosts only")
	}
	if _, err := exec.LookPath("wsl.exe"); err != nil {
		t.Fatalf("wsl.exe not found on PATH: %v", err)
	}

	ctx := context.Background()
	t.Logf("--- wsl ---\n%s", hostExecOK(t, "wsl.exe", "--version"))
	t.Logf("--- wsl -l -v ---\n%s", hostExecOK(t, "wsl.exe", "-l", "-v"))

	waitDistro(ctx, t)
	machine := strings.TrimSpace(execOK(ctx, t, "uname --machine"))
	t.Logf("--- uname ---\n%s %s", strings.TrimSpace(execOK(ctx, t, "uname --all")), distro())

	combos, err := common.Matrix()
	if err != nil {
		t.Fatal(err)
	}
	if len(combos) == 0 {
		t.Fatal("empty matrix: nothing to run")
	}

	setupDeps(ctx, t)
	if needsGoToolchain(combos) {
		ensureGoToolchain(ctx, t)
	}

	// Sequential on purpose: every combo shares the single distro, and the
	// vfox binary install (/usr/local/bin) is global to it.
	for _, c := range combos {
		c := c
		t.Run(c.Slug(), func(t *testing.T) {
			runOne(t, ctx, machine, c)
		})
	}
}

// needsGoToolchain reports whether any combo builds vfox from source.
func needsGoToolchain(combos []common.Combo) bool {
	for _, c := range combos {
		if c.Vfox == "main" {
			return true
		}
	}
	return false
}

// runOne drives the whole E2E flow (setup -> install -> verify) inside the
// distro for one combo, asserting in Go. A combo passes when every phase
// exits 0 and the outputs carry the expected markers.
func runOne(t *testing.T, ctx context.Context, machine string, c common.Combo) {
	t.Helper()

	// One overall budget per combo; the CI job timeout stays the outer bound.
	ctx, cancel := context.WithTimeout(ctx, 25*time.Minute)
	defer cancel()

	version := resolveNodeVersion(t)
	t.Logf("=== vfox %s, node %s, mirror %s, wsl/%s (%s) ===", c.Vfox, version, c.Mirror, distro(), machine)

	s := newSlot(c.Slug())
	execOK(ctx, t, "mkdir --parents "+s.home+" "+s.vfoxHome)

	if c.Vfox == "main" {
		installVfoxMain(ctx, t)
	} else {
		installVfoxRelease(ctx, t)
	}
	stagePlugin(ctx, t, s)
	checkMirrorReachable(ctx, t, s, c.Mirror)
	checkBogusMirrorRejected(ctx, t, s)
	checkBogusMirrorVersionRejected(ctx, t, s, version)

	installNodeVersion(ctx, t, s, version)
	npm := verifyToolchain(ctx, t, s, version, machine)
	verifyShorthand(ctx, t, s, version)
	verifySearch(ctx, t, s, version, npm)

	// The LTS release backs the `lts/<codename>` legacy-file probe, which
	// needs its major inside the plugin's codename table (see docs/lts.md).
	// The probe itself runs the binary, so no separate toolchain check here.
	lts := common.ResolveLTSVersion(t)
	installNodeVersion(ctx, t, s, lts)

	latest := installLatestNode(ctx, t, s)
	execOK(ctx, t, activated("vfox use --global nodejs@"+latest), s.env()...)
	verifyToolchain(ctx, t, s, latest, machine)
	verifyLegacyFiles(ctx, t, s, version, lts)
}
