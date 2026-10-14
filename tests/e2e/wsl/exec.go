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
	"os"
	"os/exec"
	"strings"
	"testing"

	"github.com/version-fox/vfox-nodejs/tests/e2e/common"
)

// defaultDistro is the WSL distribution the suite drives. It must stay
// installed by the CI job before `go test` runs (see .github/workflows/e2e.yml);
// WSL_DISTRO overrides it for local runs.
const defaultDistro = "Ubuntu-24.04"

// distro returns the WSL distribution under test.
func distro() string {
	if v := strings.TrimSpace(os.Getenv("WSL_DISTRO")); v != "" {
		return v
	}
	return defaultDistro
}

// bashQuote renders a single-quoted bash string literal.
func bashQuote(s string) string {
	return "'" + strings.ReplaceAll(s, "'", `'\''`) + "'"
}

// exportPrefix renders extraEnv entries ("K=V") as a bash export prefix so
// every wsl.exe invocation carries its own environment: each call starts a
// fresh process, exactly like the container suites' per-exec env overrides.
func exportPrefix(extraEnv []string) string {
	if len(extraEnv) == 0 {
		return ""
	}
	quoted := make([]string, 0, len(extraEnv))
	for _, kv := range extraEnv {
		k, v, _ := strings.Cut(kv, "=")
		quoted = append(quoted, k+"="+bashQuote(v))
	}
	return "export " + strings.Join(quoted, " ") + "; "
}

// execRun runs script via `wsl.exe -d <distro> -u root -- bash` on the
// Windows host and returns its exit code with the combined stdout+stderr
// output. The script is sent on stdin rather than as a `bash -c` argument:
// WSL's Windows command-line forwarding rewrites quoting and expansions in
// complex bash command strings. Always root to skip first-run user creation.
func execRun(ctx context.Context, t *testing.T, script string, extraEnv ...string) (int, string) {
	t.Helper()
	full := exportPrefix(extraEnv) + script
	cmd := exec.CommandContext(ctx, "wsl.exe", "-d", distro(), "-u", "root", "--", "bash")
	cmd.Stdin = strings.NewReader(full)
	out, err := cmd.CombinedOutput()
	if err != nil {
		if exit, ok := err.(*exec.ExitError); ok {
			return exit.ExitCode(), string(out)
		}
		t.Fatalf("wsl exec: %v\n--- script ---\n%s", err, script)
	}
	return 0, string(out)
}

// execOK runs script and fatals unless it exits 0, returning the output.
func execOK(ctx context.Context, t *testing.T, script string, extraEnv ...string) string {
	t.Helper()
	code, out := execRun(ctx, t, script, extraEnv...)
	if code != 0 {
		t.Fatalf("wsl exec exited with code %d\n--- script ---\n%s\n--- output ---\n%s", code, script, out)
	}
	return out
}

// execRetry runs script through the shared common.Retry helper (linear
// 10s*attempt backoff, per-attempt logging).
func execRetry(ctx context.Context, t *testing.T, label, script string, extraEnv ...string) string {
	t.Helper()
	return common.Retry(ctx, t, label, func() (int, string) {
		return execRun(ctx, t, script, extraEnv...)
	})
}

// activated sets the shell context that `vfox activate bash` normally exports,
// then refreshes the SDK environment explicitly. A non-interactive `bash -c`
// never runs PROMPT_COMMAND; evaluating the full activation hook here also
// exposes a `;;` parsing bug in vfox's generated prompt hook on WSL.
func activated(script string) string {
	return `export __VFOX_PID=$$; ` +
		`export __VFOX_SHELL='bash'; ` +
		`eval "$(vfox env -s bash)"; ` + script
}

// hostExecOK runs a command on the Windows host (not inside WSL) and fatals
// unless it exits 0, returning the trimmed combined output.
func hostExecOK(t *testing.T, name string, args ...string) string {
	t.Helper()
	out, err := exec.Command(name, args...).CombinedOutput()
	if err != nil {
		t.Fatalf("host exec %s %s: %v\n--- output ---\n%s", name, strings.Join(args, " "), err, out)
	}
	return strings.TrimSpace(string(out))
}
