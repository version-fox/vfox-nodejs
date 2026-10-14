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

// installNodeVersion installs one Node.js version and selects it globally.
// Both install and use go through retries: install downloads ~30 MB, and
// `vfox use` needs the activate context (see exec.go).
func installNodeVersion(ctx context.Context, t *testing.T, ctr tc.Container, version string) {
	t.Helper()
	out := execRetry(ctx, t, ctr, fmt.Sprintf("vfox install nodejs@%s", version),
		fmt.Sprintf("vfox install nodejs@%s", version))
	// The plugin passes the SHA256 from SHASUMS256.txt to vfox; a plugin
	// regression that drops it would install unverified, without this line.
	require.Contains(t, out, "Verifying checksum", "install must verify the SHASUMS256.txt checksum")
	execOK(ctx, t, ctr, activated(fmt.Sprintf("vfox use --global nodejs@%s", version)))
}

// installLatestNode installs the newest published Node.js version. If the
// latest official release has no unofficial ARM64 musl build yet, that one
// platform-specific probe is skipped; the other latest probes still cover
// @latest resolution and installation.
func installLatestNode(ctx context.Context, t *testing.T, ctr tc.Container) (string, bool) {
	t.Helper()
	const label = "vfox install nodejs@latest"
	code, out := execRun(ctx, t, ctr, label)
	if code != 0 {
		version, filename, missing := missingLatestArm64MuslBuild(out)
		if missing {
			available, known := unofficialArm64MuslBuildAvailable(ctx, t, ctr, version, filename)
			if known && !available {
				t.Logf("SKIP @latest install: unofficial musl ARM64 build %s is not published yet", filename)
				return "", false
			}
		}
		out = common.Retry(ctx, t, label, func() (int, string) {
			return execRun(ctx, t, ctr, label)
		})
	}
	latest := common.LatestUsed(out)
	require.NotEmptyf(t, latest, "@latest install did not report the picked version\n--- output ---\n%s", out)
	return latest, true
}

// missingLatestArm64MuslBuild recognizes only the specific error emitted
// after the unofficial-builds checksum list also lacks the requested asset.
func missingLatestArm64MuslBuild(output string) (version, filename string, missing bool) {
	output = common.StripANSI(output)
	version = common.LatestUsed(output)
	if version == "" {
		return "", "", false
	}
	filename = fmt.Sprintf("node-v%s-linux-arm64-musl.tar.gz", version)
	message := fmt.Sprintf("Node.js package %s is not listed in ", filename)
	missing = strings.Contains(output, message) && strings.Contains(output, "SHASUMS256.txt")
	return version, filename, missing
}

// unofficialArm64MuslBuildAvailable checks the exact upstream checksum list
// before treating a missing artifact as an expected release-publication lag.
// The second return value is false when the HTTP result is inconclusive, so
// network errors still fail through the normal retry path instead of skipping.
func unofficialArm64MuslBuildAvailable(ctx context.Context, t *testing.T, ctr tc.Container, version, filename string) (available, known bool) {
	t.Helper()
	url := fmt.Sprintf("https://unofficial-builds.nodejs.org/download/release/v%s/SHASUMS256.txt", version)
	script := fmt.Sprintf("curl -fsSL --max-time 20 -w '\\n%%{http_code}' %q 2>/dev/null", url)
	code, out := execRun(ctx, t, ctr, script)
	trimmed := strings.TrimSpace(out)
	status := trimmed[strings.LastIndex(trimmed, "\n")+1:]
	switch status {
	case "404":
		return false, code == 22
	case "200":
		if code != 0 {
			return false, false
		}
		return strings.Contains(trimmed, filename), true
	default:
		// curl exits non-zero for HTTP errors and reports 000 for transport
		// failures. Do not skip a CI failure unless absence is confirmed.
		return false, false
	}
}
