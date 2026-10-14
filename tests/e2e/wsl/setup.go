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
	"archive/zip"
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"

	"github.com/version-fox/vfox-nodejs/tests/e2e/common"
)

// Node.js defaults for the WSL suite. The pinned release is the exact one
// from https://github.com/version-fox/vfox-nodejs/issues/32 (WSL: install
// succeeds but node is not on PATH); $NODE_VERSION still overrides it.
const (
	// defaultNodeVersion reproduces the issue report.
	defaultNodeVersion = "20.16.0"
	// goWslVersion pins the Go toolchain tarball used to build vfox@main
	// inside WSL (matches goWindowsVersion in tests/e2e/windows/setup.go).
	goWslVersion = "1.27.1"
)

// resolveNodeVersion honours $NODE_VERSION, else the issue #32 release above.
func resolveNodeVersion(t *testing.T) string {
	t.Helper()
	if v := strings.TrimSpace(os.Getenv("NODE_VERSION")); v != "" {
		return v
	}
	return defaultNodeVersion
}

// slot carries the per-combo isolated locations plus the exec env overrides
// that apply them (each wsl.exe call starts a fresh process, so the exports
// must ride along every script).
type slot struct {
	slug     string
	root     string
	home     string
	vfoxHome string
}

// newSlot isolates the combo under /tmp/wsl-e2e-<slug>: HOME and VFOX_HOME
// point inside it, so sequential combos on the single shared distro never
// share vfox state.
func newSlot(slug string) slot {
	root := "/tmp/wsl-e2e-" + slug
	return slot{
		slug:     slug,
		root:     root,
		home:     root + "/home",
		vfoxHome: root + "/.vfox",
	}
}

// env returns the export entries applying the slot isolation.
func (s slot) env() []string {
	return []string{
		"HOME=" + s.home,
		"VFOX_HOME=" + s.vfoxHome,
	}
}

// releasesIndex returns the mirror's Node.js version index
// (the plugin's Available endpoint).
func releasesIndex(mirror string) string {
	return strings.TrimSuffix(mirror, "/") + "/index.json"
}

// waitDistro blocks until the distro answers as root. The CI job boots it
// first, but the first exec after install can still take a while.
func waitDistro(ctx context.Context, t *testing.T) {
	t.Helper()
	execRetry(ctx, t, "wsl distro "+distro()+" boot", "true")
	t.Logf("PASS WSL distro %s answers as root", distro())
}

// setupDeps installs the packages the suite needs inside the distro
// (mirrors the apt set in tests/e2e/linux/Dockerfile).
func setupDeps(ctx context.Context, t *testing.T) {
	t.Helper()
	execRetry(ctx, t, "apt-get update",
		"apt-get update")
	execOK(ctx, t, "apt-get install --assume-yes ca-certificates curl git libatomic1")
	t.Log("PASS WSL deps installed")
}

// installVfoxRelease installs the latest vfox release inside the distro.
func installVfoxRelease(ctx context.Context, t *testing.T) {
	t.Helper()
	execRetry(ctx, t, "install vfox release",
		"curl --fail --silent --show-error --location https://raw.githubusercontent.com/version-fox/vfox/main/install.sh | bash")
	t.Log("PASS installed latest vfox release")
}

// ensureGoToolchain installs the pinned Go tarball under /usr/local once;
// only the vfox@main combos need it.
func ensureGoToolchain(ctx context.Context, t *testing.T) {
	t.Helper()
	if out := execOK(ctx, t, "command -v go || true"); strings.TrimSpace(out) != "" {
		if strings.Contains(execOK(ctx, t, "go version"), "go"+goWslVersion) {
			t.Logf("PASS Go %s already present", goWslVersion)
			return
		}
	}
	machine := strings.TrimSpace(execOK(ctx, t, "uname --machine"))
	goArch, err := goArchOf(machine)
	require.NoError(t, err)
	work := strings.TrimSpace(execOK(ctx, t, "mktemp --directory"))
	defer func() {
		_, _ = execRun(ctx, t, fmt.Sprintf("rm --recursive --force %q", work))
	}()
	execRetry(ctx, t, "download Go "+goWslVersion,
		fmt.Sprintf("curl --fail --silent --show-error --location --output %q/go.tgz https://go.dev/dl/go%s.linux-%s.tar.gz",
			work, goWslVersion, goArch))
	execOK(ctx, t, fmt.Sprintf("rm --recursive --force /usr/local/go && tar -xzf %q/go.tgz -C /usr/local && ln --symbolic --force /usr/local/go/bin/go /usr/local/bin/go", work))
	execOK(ctx, t, "go version")
	t.Logf("PASS installed Go %s (%s)", goWslVersion, goArch)
}

// goArchOf maps uname -m to the arch string in go.dev tarball names.
func goArchOf(machine string) (string, error) {
	arch, err := common.NormalizeArch(strings.TrimSpace(machine))
	if err != nil {
		return "", err
	}
	if arch == "arm64" {
		return "arm64", nil
	}
	return "amd64", nil
}

// installVfoxMain clones vfox and builds vfox into /usr/local/bin.
func installVfoxMain(ctx context.Context, t *testing.T) {
	t.Helper()
	ensureGoToolchain(ctx, t)
	work := strings.TrimSpace(execOK(ctx, t, "mktemp --directory"))
	defer func() {
		_, _ = execRun(ctx, t, fmt.Sprintf("rm --recursive --force %q", work))
	}()
	execRetry(ctx, t, "clone vfox",
		fmt.Sprintf("git clone --depth 1 https://github.com/version-fox/vfox %q/src", work))
	execOK(ctx, t, fmt.Sprintf("(cd %q/src && CGO_ENABLED=0 go build -trimpath -o /usr/local/bin/vfox .)", work))
	t.Log("PASS built vfox from main")
}

// stagePlugin packs metadata.lua/hooks/lib from this checkout into a zip on
// the Windows host, copies it into the distro through the 9P mount, and
// registers it under the slot's VFOX_HOME.
func stagePlugin(ctx context.Context, t *testing.T, s slot) {
	t.Helper()
	here, err := filepath.Abs(".")
	require.NoError(t, err)
	repoRoot := filepath.Join(here, "..", "..", "..")

	zipPath := filepath.Join(t.TempDir(), "nodejs.zip")
	require.NoError(t, packPlugin(repoRoot, zipPath))

	// The host checkout reaches the distro through the 9P mount; wslpath
	// converts the Windows path (drive letter included) for the cp call.
	// wsl.exe treats backslashes in Windows arguments as escapes; pass a
	// slash-separated drive path so wslpath receives the original path.
	wslPath := strings.TrimSpace(hostExecOK(t, "wsl.exe", "-d", distro(), "-u", "root", "--", "wslpath", "-a", filepath.ToSlash(zipPath)))
	work := fmt.Sprintf("%s/work", s.root)
	execOK(ctx, t, fmt.Sprintf("mkdir --parents %q && cp %q %q/nodejs.zip", work, wslPath, work), s.env()...)
	execOK(ctx, t, fmt.Sprintf("vfox add nodejs --source %q/nodejs.zip", work), s.env()...)
	t.Logf("PASS staged local nodejs plugin for slot %s", s.slug)
}

// packPlugin zips metadata.lua, hooks and lib from repoRoot into zipPath.
func packPlugin(repoRoot, zipPath string) error {
	entries := []string{filepath.Join(repoRoot, "metadata.lua")}
	for _, dir := range []string{"hooks", "lib"} {
		found, err := filepath.Glob(filepath.Join(repoRoot, dir, "*"))
		if err != nil {
			return err
		}
		entries = append(entries, found...)
	}
	out, err := os.Create(zipPath)
	if err != nil {
		return err
	}
	defer out.Close()
	w := zip.NewWriter(out)
	defer w.Close()
	for _, abs := range entries {
		info, err := os.Stat(abs)
		if err != nil {
			return err
		}
		if info.IsDir() {
			continue
		}
		rel, err := filepath.Rel(repoRoot, abs)
		if err != nil {
			return err
		}
		name := filepath.ToSlash(rel)
		fw, err := w.Create(name)
		if err != nil {
			return err
		}
		fr, err := os.Open(abs)
		if err != nil {
			return err
		}
		if _, err := io.Copy(fw, fr); err != nil {
			_ = fr.Close()
			return err
		}
		if err := fr.Close(); err != nil {
			return err
		}
	}
	return nil
}

// checkMirrorReachable fails fast when the mirror does not serve the version
// index. The default mirror is not probed: it is nodejs.org/dist itself.
func checkMirrorReachable(ctx context.Context, t *testing.T, s slot, mirror string) {
	t.Helper()
	if mirror == "default" {
		return
	}
	index := releasesIndex(mirror)
	execRetry(ctx, t, "mirror "+index,
		fmt.Sprintf("curl --fail --silent --show-error --location --max-time 20 --output /dev/null %q", index), s.env()...)
	t.Logf("PASS mirror %s serves the version index", mirror)
}

// checkBogusMirrorRejected proves `latest` resolution honours
// $VFOX_NODEJS_MIRROR: Available() hits the bogus host and the install fails
// naming it. If the plugin ignored the env var, the default mirror would
// serve the index and the install would proceed.
func checkBogusMirrorRejected(ctx context.Context, t *testing.T, s slot) {
	t.Helper()
	code, out := execRun(ctx, t, "vfox install nodejs@latest",
		append(s.env(), "VFOX_NODEJS_MIRROR="+common.BogusMirror)...)
	require.NotEqualf(t, 0, code, "bogus mirror install unexpectedly succeeded\n--- output ---\n%s", out)
	require.Contains(t, out, "invalid.example.invalid", "bogus mirror error")
}

// checkBogusMirrorVersionRejected proves a pinned install also honours
// $VFOX_NODEJS_MIRROR: PreInstall fetches SHASUMS256.txt from the bogus host
// and fails instead of silently falling back to the default mirror.
func checkBogusMirrorVersionRejected(ctx context.Context, t *testing.T, s slot, version string) {
	t.Helper()
	code, out := execRun(ctx, t, "vfox install nodejs@"+version,
		append(s.env(), "VFOX_NODEJS_MIRROR="+common.BogusMirror)...)
	require.NotEqualf(t, 0, code, "bogus mirror install unexpectedly succeeded\n--- output ---\n%s", out)
	require.Contains(t, out, "get checksum failed", "bogus mirror checksum fetch")
}
