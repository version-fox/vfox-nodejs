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

// Package common holds the shared logic of the Linux and Windows container
// E2E suites.
//
// The two suites target different container systems (bash vs pwsh, different
// release probing and isolation), so the code interacting with containers
// stays in the linux / windows packages; the target-independent parts
// (matrix expansion, version defaults, retry counts, name handling) live
// here and are reused by both platform packages, instead of being copied.
package common

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"os"
	"regexp"
	"runtime"
	"strconv"
	"strings"
	"testing"
	"time"
)

// Node.js defaults, maintained in one place for both packages.
const (
	// DefaultNodeVersion is the pinned Node.js release both suites install.
	DefaultNodeVersion = "22.23.3"
	// BogusMirror is the unreachable mirror domain used by the negative probes.
	BogusMirror = "https://invalid.example.invalid"
	// DefaultMirrorCN is the default mainland-China Node.js mirror.
	DefaultMirrorCN = "https://npmmirror.com/mirrors/node"
)

// PassThroughEnvs are host env knobs the in-container scripts honour.
// Forwarded only when set, so unset stays default.
var PassThroughEnvs = []string{
	"NODE_VERSION",
	"E2E_RETRY_ATTEMPTS",
}

// Combo is one matrix cell: a vfox version and a mirror.
type Combo struct {
	Vfox   string
	Mirror string
}

// Prefix renders the log prefix: "vfox <vfox>, mirror <mirror>, <platform>".
func (c Combo) Prefix(platform string) string {
	return fmt.Sprintf("vfox %s, mirror %s, %s", c.Vfox, c.Mirror, platform)
}

// Slug renders a docker-safe container name fragment for the combo.
func (c Combo) Slug() string {
	return c.Vfox + "-" + Sanitize(c.Mirror)
}

// Sanitize replaces every non-ASCII-alphanumeric byte with '_' so arbitrary
// mirror URLs stay valid in container names.
func Sanitize(s string) string {
	var b strings.Builder
	b.Grow(len(s))
	for i := 0; i < len(s); i++ {
		ch := s[i]
		if ch >= 'A' && ch <= 'Z' || ch >= 'a' && ch <= 'z' || ch >= '0' && ch <= '9' {
			b.WriteByte(ch)
		} else {
			b.WriteByte('_')
		}
	}
	return b.String()
}

// NormalizeArch maps uname-style names, Windows PROCESSOR_ARCHITECTURE values
// and common aliases to docker arch names.
func NormalizeArch(s string) (string, error) {
	switch strings.ToLower(s) {
	case "x86_64", "x64", "amd64":
		return "amd64", nil
	case "aarch64", "arm64":
		return "arm64", nil
	default:
		return "", fmt.Errorf("unknown architecture %s", s)
	}
}

// DetectArch reports the runner architecture: $PROCESSOR_ARCHITECTURE on
// Windows hosts (AMD64/ARM64/x86), else the test binary's own arch. There is
// deliberately no override knob: emulated runs (arm64 on an x64 host) are
// not supported, and CI covers each arch on native runners.
func DetectArch() (string, error) {
	if arch, ok := os.LookupEnv("PROCESSOR_ARCHITECTURE"); ok && strings.TrimSpace(arch) != "" {
		return NormalizeArch(strings.TrimSpace(arch))
	}
	return NormalizeArch(runtime.GOARCH)
}

// Fields splits space-separated env lists (e.g. VFOX_VERSION="latest main").
func Fields(s string) []string {
	return strings.Fields(s)
}

// DefaultMirrors mirrors the rule the Flutter plugin suite uses: the extra
// mirror only runs on amd64, where the full matrix is affordable.
func DefaultMirrors(arch string) []string {
	if arch == "arm64" {
		return []string{"default"}
	}
	return []string{"default", DefaultMirrorCN}
}

// Matrix expands the vfox x mirror combinations for the runner architecture.
// Env overrides: VFOX_VERSION (default "latest main"), MIRROR. The mirror
// matrix only runs against latest vfox unless the caller explicitly pins
// MIRROR, to keep CI time bounded.
func Matrix() ([]Combo, error) {
	arch, err := DetectArch()
	if err != nil {
		return nil, err
	}
	return MatrixForArch(arch)
}

// MatrixForArch expands the matrix for an explicit arch. Tests use it
// directly so each arch branch stays covered on any host.
func MatrixForArch(arch string) ([]Combo, error) {
	foxes := []string{"latest", "main"}
	if v, ok := os.LookupEnv("VFOX_VERSION"); ok && len(Fields(v)) > 0 {
		foxes = Fields(v)
	}
	mirrors := DefaultMirrors(arch)
	if v, ok := os.LookupEnv("MIRROR"); ok && len(Fields(v)) > 0 {
		mirrors = Fields(v)
	}
	_, mirrorExplicit := os.LookupEnv("MIRROR")
	mirrorExplicit = mirrorExplicit && len(Fields(os.Getenv("MIRROR"))) > 0

	var combos []Combo
	for _, vfox := range foxes {
		for _, mirror := range mirrors {
			if !mirrorExplicit && mirror != "default" && vfox != "latest" {
				continue
			}
			combos = append(combos, Combo{Vfox: vfox, Mirror: mirror})
		}
	}
	return combos, nil
}

// MaxJobs bounds parallel containers; honours $E2E_MAX_JOBS and falls back
// to def when unset or invalid. Linux passes 3, Windows passes 2.
func MaxJobs(def int) int {
	if v, ok := os.LookupEnv("E2E_MAX_JOBS"); ok {
		if n, err := strconv.Atoi(strings.TrimSpace(v)); err == nil && n >= 1 {
			return n
		}
	}
	return def
}

// RetryAttempts caps exec retries; honours $E2E_RETRY_ATTEMPTS (default 3).
func RetryAttempts() int {
	if v, ok := os.LookupEnv("E2E_RETRY_ATTEMPTS"); ok && strings.TrimSpace(v) != "" {
		if n, err := strconv.Atoi(strings.TrimSpace(v)); err == nil {
			return n
		}
	}
	return 3
}

// ResolveNodeVersion honours $NODE_VERSION, else the default above.
func ResolveNodeVersion(t *testing.T) string {
	t.Helper()
	if v := os.Getenv("NODE_VERSION"); v != "" {
		return v
	}
	return DefaultNodeVersion
}

// LTSCodenames maps the Node.js LTS codenames the plugin resolves
// (hooks/parse_legacy_file.lua) to their major versions.
var LTSCodenames = map[string]int{
	"argon": 4, "boron": 6, "carbon": 8, "dubnium": 10, "erbium": 12,
	"fermium": 14, "gallium": 16, "hydrogen": 18, "iron": 20, "jod": 22,
}

// LTSCodename returns the codename for a version's major, if the plugin's
// legacy resolver knows it.
func LTSCodename(version string) (string, bool) {
	major, err := strconv.Atoi(strings.SplitN(version, ".", 2)[0])
	if err != nil {
		return "", false
	}
	for name, m := range LTSCodenames {
		if m == major {
			return name, true
		}
	}
	return "", false
}

// ansiEscape matches the SGR colour sequences pterm emits when it believes
// it writes to a terminal.
var ansiEscape = regexp.MustCompile(`\x1b\[[0-9;]*m`)

// StripANSI removes SGR colour sequences from command output.
func StripANSI(s string) string {
	return ansiEscape.ReplaceAllString(s, "")
}

// latestUsed matches the "Using latest version: X" line `vfox install` and
// `vfox use` print after resolving @latest through Available.
var latestUsed = regexp.MustCompile(`Using latest version:\s*(\d+\.\d+\.\d+)`)

// LatestUsed extracts the picked @latest version from command output, or ""
// when the line is absent.
func LatestUsed(output string) string {
	if m := latestUsed.FindStringSubmatch(StripANSI(output)); m != nil {
		return m[1]
	}
	return ""
}

// searchNpm matches the "[npm X.Y.Z]" addition `vfox search` prints.
var searchNpm = regexp.MustCompile(`\[npm ([0-9]+\.[0-9]+\.[0-9]+)\]`)

// SearchNpm finds the npm version on the `vfox search nodejs` line carrying
// the given release.
func SearchNpm(searchOutput, version string) (string, bool) {
	for _, line := range strings.Split(StripANSI(searchOutput), "\n") {
		if strings.Contains(line, version) {
			if m := searchNpm.FindStringSubmatch(line); m != nil {
				return m[1], true
			}
		}
	}
	return "", false
}

// semverToken matches the X.Y.Z release tokens `vfox list nodejs` prints.
var semverToken = regexp.MustCompile(`\d+\.\d+\.\d+`)

// InstalledVersions extracts the release tokens from `vfox list nodejs`
// output, in the order vfox printed them, without duplicates.
func InstalledVersions(listOutput string) []string {
	seen := map[string]bool{}
	var out []string
	for _, m := range semverToken.FindAllString(listOutput, -1) {
		if !seen[m] {
			seen[m] = true
			out = append(out, m)
		}
	}
	return out
}

// ContainerName returns a unique container name per run: the combo slug stays
// greppable in `docker ps`, the random suffix avoids clashes with leftovers
// from killed runs.
func ContainerName(slug string) string {
	var b [4]byte
	if _, err := rand.Read(b[:]); err != nil {
		return fmt.Sprintf("vfox-nodejs-e2e-%s-%d", slug, time.Now().UnixNano())
	}
	return "vfox-nodejs-e2e-" + slug + "-" + hex.EncodeToString(b[:])
}
