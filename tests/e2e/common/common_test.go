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

package common

import (
	"testing"
)

func setEnv(t *testing.T, kv map[string]string) {
	t.Helper()
	for k, v := range kv {
		t.Setenv(k, v)
	}
}

func comboKeys(combos []Combo) []string {
	keys := make([]string, 0, len(combos))
	for _, c := range combos {
		keys = append(keys, c.Vfox+"/"+c.Mirror)
	}
	return keys
}

// Default amd64 matrix: latest runs both mirrors, main runs default only.
func TestMatrixDefaultAmd64(t *testing.T) {
	t.Setenv("VFOX_VERSION", "")
	t.Setenv("MIRROR", "")

	// t.Setenv sets the var to "" which LookupEnv reports as set; the empty
	// values above exercise the real defaults via Fields dropping empties.
	combos, err := MatrixForArch("amd64")
	if err != nil {
		t.Fatal(err)
	}
	if len(combos) == 0 {
		t.Fatal("empty matrix")
	}
	t.Logf("combos: %v", comboKeys(combos))
	for _, c := range combos {
		if c.Mirror != "default" && c.Vfox != "latest" {
			t.Errorf("non-default mirror runs against %s vfox: %+v", c.Vfox, c)
		}
	}
}

// arm64 defaults: the default mirror only.
func TestMatrixDefaultArm64(t *testing.T) {
	setEnv(t, map[string]string{
		"VFOX_VERSION": "latest main",
		"MIRROR":       "",
	})

	combos, err := MatrixForArch("arm64")
	if err != nil {
		t.Fatal(err)
	}
	for _, c := range combos {
		if c.Mirror != "default" {
			t.Errorf("arm64 mirror = %s, want default", c.Mirror)
		}
	}
	if len(combos) == 0 {
		t.Fatal("empty matrix")
	}
}

// Explicit MIRROR pins the full mirror matrix even for non-latest vfox.
func TestMatrixExplicitMirror(t *testing.T) {
	setEnv(t, map[string]string{
		"VFOX_VERSION": "main",
		"MIRROR":       "default " + DefaultMirrorCN,
	})

	combos, err := MatrixForArch("amd64")
	if err != nil {
		t.Fatal(err)
	}
	if len(combos) != 2 {
		t.Fatalf("combos = %v, want 2", comboKeys(combos))
	}
}

// PROCESSOR_ARCHITECTURE values from real Windows hosts resolve correctly.
func TestMatrixProcessorArchitecture(t *testing.T) {
	t.Setenv("PROCESSOR_ARCHITECTURE", "ARM64")
	t.Setenv("VFOX_VERSION", "latest")
	t.Setenv("MIRROR", "default")
	combos, err := Matrix()
	if err != nil {
		t.Fatal(err)
	}
	if len(combos) != 1 {
		t.Fatalf("combos = %v, want 1", comboKeys(combos))
	}
}

// Unknown architectures fail fast instead of running a wrong matrix.
func TestMatrixUnknownArch(t *testing.T) {
	t.Setenv("PROCESSOR_ARCHITECTURE", "bogus64")
	if _, err := Matrix(); err == nil {
		t.Error("Matrix() with bogus PROCESSOR_ARCHITECTURE succeeded, want error")
	}
}

func TestNormalizeArch(t *testing.T) {
	for in, want := range map[string]string{
		"AMD64": "amd64", "x86_64": "amd64", "x64": "amd64", "amd64": "amd64",
		"ARM64": "arm64", "aarch64": "arm64", "arm64": "arm64",
	} {
		got, err := NormalizeArch(in)
		if err != nil || got != want {
			t.Errorf("NormalizeArch(%q) = %q, %v; want %q", in, got, err, want)
		}
	}
	for _, bad := range []string{"riscv64", "x86"} {
		if _, err := NormalizeArch(bad); err == nil {
			t.Errorf("NormalizeArch(%q) succeeded, want error", bad)
		}
	}
}

func TestSanitize(t *testing.T) {
	got := Combo{Vfox: "latest", Mirror: DefaultMirrorCN}.Slug()
	want := "latest-https___npmmirror_com_mirrors_node"
	if got != want {
		t.Errorf("slug = %q, want %q", got, want)
	}
}

func TestMaxJobs(t *testing.T) {
	t.Setenv("E2E_MAX_JOBS", "")
	// empty means unset-equivalent for MaxJobs (Atoi fails -> default)
	if got := MaxJobs(3); got != 3 {
		t.Errorf("MaxJobs = %d, want 3", got)
	}
	t.Setenv("E2E_MAX_JOBS", "0")
	if got := MaxJobs(3); got != 3 {
		t.Errorf("MaxJobs(0) = %d, want 3 (clamped to default)", got)
	}
	t.Setenv("E2E_MAX_JOBS", "2")
	if got := MaxJobs(3); got != 2 {
		t.Errorf("MaxJobs(2) = %d, want 2", got)
	}
}

func TestResolveNodeVersion(t *testing.T) {
	t.Setenv("NODE_VERSION", "")
	if got := ResolveNodeVersion(t); got != DefaultNodeVersion {
		t.Errorf("default = %q, want %q", got, DefaultNodeVersion)
	}
	t.Setenv("NODE_VERSION", "24.1.0")
	if got := ResolveNodeVersion(t); got != "24.1.0" {
		t.Errorf("override = %q, want 24.1.0", got)
	}
}

func TestRetryAttemptsDefault(t *testing.T) {
	t.Setenv("E2E_RETRY_ATTEMPTS", "")
	if got := RetryAttempts(); got != 3 {
		t.Errorf("retryAttempts = %d, want 3", got)
	}
	t.Setenv("E2E_RETRY_ATTEMPTS", "5")
	if got := RetryAttempts(); got != 5 {
		t.Errorf("retryAttempts = %d, want 5", got)
	}
}

func TestLTSCodename(t *testing.T) {
	if got, ok := LTSCodename("22.23.3"); !ok || got != "jod" {
		t.Errorf("LTSCodename(22.23.3) = %q, %v; want jod", got, ok)
	}
	if got, ok := LTSCodename("20.19.5"); !ok || got != "iron" {
		t.Errorf("LTSCodename(20.19.5) = %q, %v; want iron", got, ok)
	}
	if _, ok := LTSCodename("24.1.0"); ok {
		t.Error("LTSCodename(24.1.0) succeeded, want unknown")
	}
	if _, ok := LTSCodename("not-semver"); ok {
		t.Error("LTSCodename(not-semver) succeeded, want unknown")
	}
}

func TestInstalledVersions(t *testing.T) {
	// ANSI-wrapped current marker and an unrelated semver-looking token.
	out := "-> \x1b[92m26.11.1\x1b[0m\n-> 22.23.3 <\u2014 current\n22.23.3\n"
	got := InstalledVersions(out)
	want := []string{"26.11.1", "22.23.3"}
	if len(got) != len(want) {
		t.Fatalf("versions = %v, want %v", got, want)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("versions = %v, want %v", got, want)
		}
	}
}

func TestLatestUsed(t *testing.T) {
	if got := LatestUsed("Using latest version: \x1b[92m26.11.1\x1b[0m\n"); got != "26.11.1" {
		t.Errorf("LatestUsed = %q, want 26.11.1", got)
	}
	if got := LatestUsed("Install nodejs@22.23.3 success!"); got != "" {
		t.Errorf("LatestUsed = %q, want empty", got)
	}
}

func TestSearchNpm(t *testing.T) {
	out := "Available versions:\n" +
		" - 26.11.1 [npm 11.20.0]\n" +
		" - 22.23.3 (LTS) [npm 10.9.9] (installed)\n"
	npm, ok := SearchNpm(out, "22.23.3")
	if !ok || npm != "10.9.9" {
		t.Errorf("SearchNpm = %q, %v; want 10.9.9", npm, ok)
	}
	if _, ok := SearchNpm(out, "24.0.0"); ok {
		t.Error("SearchNpm found an absent version")
	}
}
