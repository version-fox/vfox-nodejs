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
	"testing"

	"github.com/stretchr/testify/require"

	"github.com/version-fox/vfox-nodejs/tests/e2e/common"
)

// installNodeVersion installs one Node.js version and selects it globally.
// Both install and use go through retries: install downloads ~30 MB, and
// `vfox use` needs the activate context (see exec.go).
func installNodeVersion(ctx context.Context, t *testing.T, s slot, version string) {
	t.Helper()
	out := execRetry(ctx, t, fmt.Sprintf("vfox install nodejs@%s", version),
		fmt.Sprintf("vfox install nodejs@%s", version), s.env()...)
	// The plugin passes the SHA256 from SHASUMS256.txt to vfox; a plugin
	// regression that drops it would install unverified, without this line.
	require.Contains(t, out, "Verifying checksum", "install must verify the SHASUMS256.txt checksum")
	execOK(ctx, t, activated(fmt.Sprintf("vfox use --global nodejs@%s", version)), s.env()...)
}

// installLatestNode installs the newest published Node.js version. `vfox
// install nodejs@latest` resolves @latest through the plugin's Available
// (the first, newest entry) and prints the pick; the version is returned so
// the caller can drive `vfox use` against it.
func installLatestNode(ctx context.Context, t *testing.T, s slot) string {
	t.Helper()
	out := execRetry(ctx, t, "vfox install nodejs@latest", "vfox install nodejs@latest", s.env()...)
	latest := common.LatestUsed(out)
	require.NotEmptyf(t, latest, "@latest install did not report the picked version\n--- output ---\n%s", out)
	return latest
}
