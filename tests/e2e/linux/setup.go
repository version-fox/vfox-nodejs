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
		fmt.Sprintf("curl --fail --silent --show-error --location --max-time 20 --output /dev/null %q", index))
	t.Logf("PASS mirror %s serves the version index", mirror)
}

// setupVfox installs vfox (release, or builds main with the in-image Go
// toolchain) and registers the local nodejs plugin.
func setupVfox(ctx context.Context, t *testing.T, ctr tc.Container, vfoxVersion string) {
	t.Helper()
	work := strings.TrimSpace(execOK(ctx, t, ctr, "mktemp --directory"))
	// The container is removed after the test, but clean up anyway so
	// repeated local runs don't leak /tmp.
	defer func() {
		_, _ = execRun(ctx, t, ctr, fmt.Sprintf("rm --recursive --force %q", work))
	}()

	if vfoxVersion == "main" {
		execOK(ctx, t, ctr, fmt.Sprintf(
			"git clone --depth 1 https://github.com/version-fox/vfox %q/src && (cd %q/src && CGO_ENABLED=0 go build -trimpath -o /usr/local/bin/vfox .)",
			work, work))
	} else {
		execOK(ctx, t, ctr,
			"curl --fail --silent --show-error --location https://raw.githubusercontent.com/version-fox/vfox/main/install.sh | bash")
	}
	execOK(ctx, t, ctr, fmt.Sprintf(
		"(cd /e2e && zip -qr %q/nodejs.zip metadata.lua hooks lib) && vfox add nodejs --source %q/nodejs.zip",
		work, work))
}

// checkBogusMirrorRejected proves `latest` resolution honours
// $VFOX_NODEJS_MIRROR: Available() hits the bogus host and the install fails
// naming it. If the plugin ignored the env var, the default mirror would
// serve the index and the install would proceed.
func checkBogusMirrorRejected(ctx context.Context, t *testing.T, ctr tc.Container) {
	t.Helper()
	code, out := execRun(ctx, t, ctr,
		"vfox install nodejs@latest",
		"VFOX_NODEJS_MIRROR="+common.BogusMirror)
	require.NotEqualf(t, 0, code, "bogus mirror install unexpectedly succeeded\n--- output ---\n%s", out)
	require.Contains(t, out, "invalid.example.invalid", "bogus mirror error")
}

// checkBogusMirrorVersionRejected proves a pinned install also honours
// $VFOX_NODEJS_MIRROR: PreInstall fetches SHASUMS256.txt from the bogus host
// and fails instead of silently falling back to the default mirror.
func checkBogusMirrorVersionRejected(ctx context.Context, t *testing.T, ctr tc.Container, version string) {
	t.Helper()
	code, out := execRun(ctx, t, ctr,
		"vfox install nodejs@"+version,
		"VFOX_NODEJS_MIRROR="+common.BogusMirror)
	require.NotEqualf(t, 0, code, "bogus mirror install unexpectedly succeeded\n--- output ---\n%s", out)
	require.Contains(t, out, "get checksum failed", "bogus mirror checksum fetch")
}
