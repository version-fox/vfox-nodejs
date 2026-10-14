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
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
	tc "github.com/testcontainers/testcontainers-go"

	"github.com/version-fox/vfox-nodejs/tests/e2e/common"
)

// maxJobs bounds parallel containers; honours $E2E_MAX_JOBS (default 3).
func maxJobs() int {
	return common.MaxJobs(3)
}

// checkMuslUserland proves the Alpine suite really runs on musl (issue #29):
// the musl loader exists, there is no glibc loader, and ldd reports musl.
// The later node install+run then proves the plugin selected the *-musl
// tarball, since the glibc tarball cannot execute here.
func checkMuslUserland(ctx context.Context, t *testing.T, ctr tc.Container) {
	t.Helper()
	execOK(ctx, t, ctr, "test -e /lib/ld-musl-x86_64.so.1 -o -e /lib/ld-musl-aarch64.so.1")
	code, _ := execRun(ctx, t, ctr, "test -e /lib64/ld-linux-x86-64.so.2 -o -e /lib/ld-linux-aarch64.so.1")
	require.NotEqual(t, 0, code, "glibc loader must be absent on the musl image")
	// musl's ldd prints its version banner but exits non-zero; tolerate it.
	out := execOK(ctx, t, ctr, "ldd --version 2>&1 || true")
	require.Contains(t, strings.ToLower(out), "musl", "ldd must report musl")
	t.Log("PASS musl userland (ld-musl present, no ld-linux, ldd reports musl)")
}
