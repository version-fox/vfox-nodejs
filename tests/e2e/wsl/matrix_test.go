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
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestDistroDefault(t *testing.T) {
	t.Setenv("WSL_DISTRO", "")
	if got := distro(); got != defaultDistro {
		t.Errorf("distro = %q, want %q", got, defaultDistro)
	}
	t.Setenv("WSL_DISTRO", "Debian")
	if got := distro(); got != "Debian" {
		t.Errorf("distro = %q, want %q", got, "Debian")
	}
}

func TestResolveNodeVersion(t *testing.T) {
	t.Setenv("NODE_VERSION", "")
	if got := resolveNodeVersion(t); got != defaultNodeVersion {
		t.Errorf("resolveNodeVersion = %q, want the issue #32 release %q", got, defaultNodeVersion)
	}
	t.Setenv("NODE_VERSION", "22.23.3")
	if got := resolveNodeVersion(t); got != "22.23.3" {
		t.Errorf("resolveNodeVersion = %q, want %q", got, "22.23.3")
	}
}

func TestReleasesIndex(t *testing.T) {
	got := releasesIndex("https://npmmirror.com/mirrors/node/")
	want := "https://npmmirror.com/mirrors/node/index.json"
	if got != want {
		t.Errorf("releasesIndex = %q, want %q", got, want)
	}
}

func TestNewSlot(t *testing.T) {
	s := newSlot("latest-default")
	if s.root != "/tmp/wsl-e2e-latest-default" {
		t.Errorf("slot root = %q", s.root)
	}
	for _, kv := range s.env() {
		k, v, _ := strings.Cut(kv, "=")
		switch k {
		case "HOME":
			if v != s.home {
				t.Errorf("HOME = %q, want %q", v, s.home)
			}
		case "VFOX_HOME":
			if v != s.vfoxHome {
				t.Errorf("VFOX_HOME = %q, want %q", v, s.vfoxHome)
			}
		default:
			t.Errorf("unexpected slot env %q", kv)
		}
	}
}

func TestBashQuote(t *testing.T) {
	if got := bashQuote(`/tmp/a b`); got != `'/tmp/a b'` {
		t.Errorf("bashQuote = %q", got)
	}
	if got := bashQuote(`it's`); got != `'it'\''s'` {
		t.Errorf("bashQuote escape = %q", got)
	}
}

func TestActivatedSetsVfoxBashContext(t *testing.T) {
	got := activated("vfox current")
	for _, want := range []string{
		"export __VFOX_PID=$$",
		"export __VFOX_SHELL='bash'",
		`eval "$(vfox env -s bash)"`,
		"vfox current",
	} {
		if !strings.Contains(got, want) {
			t.Errorf("activated script %q missing %q", got, want)
		}
	}
}

func TestGoArchOf(t *testing.T) {
	if got, _ := goArchOf("x86_64"); got != "amd64" {
		t.Errorf("goArchOf(x86_64) = %q, want amd64", got)
	}
	if got, _ := goArchOf("aarch64"); got != "arm64" {
		t.Errorf("goArchOf(aarch64) = %q, want arm64", got)
	}
	if _, err := goArchOf("mips"); err == nil {
		t.Error("goArchOf(mips) should fail")
	}
}

func TestPackPlugin(t *testing.T) {
	repoRoot := t.TempDir()
	for name, content := range map[string]string{
		"metadata.lua":       "PLUGIN = {}",
		"hooks/env_keys.lua": "return {}",
		"lib/util.lua":       "return {}",
	} {
		path := filepath.Join(repoRoot, filepath.FromSlash(name))
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
			t.Fatal(err)
		}
	}

	zipPath := filepath.Join(t.TempDir(), "nodejs.zip")
	if err := packPlugin(repoRoot, zipPath); err != nil {
		t.Fatalf("packPlugin: %v", err)
	}

	archive, err := zip.OpenReader(zipPath)
	if err != nil {
		t.Fatal(err)
	}
	defer archive.Close()
	got := make(map[string]bool, len(archive.File))
	for _, file := range archive.File {
		got[file.Name] = true
	}
	for _, want := range []string{"metadata.lua", "hooks/env_keys.lua", "lib/util.lua"} {
		if !got[want] {
			t.Errorf("plugin archive missing %q", want)
		}
	}
}
