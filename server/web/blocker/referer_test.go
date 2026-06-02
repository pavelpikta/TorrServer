package blocker

import "testing"

func TestHostMatchesBlocked(t *testing.T) {
	blocked := []string{"bylampa.online", "example.com"}

	tests := []struct {
		host string
		want bool
	}{
		{"bylampa.online", true},
		{"zerkalo.bylampa.online", true},
		{"www.bylampa.online", true},
		{"notbylampa.online", false},
		{"bylampa.online.evil.com", false},
		{"example.com", true},
		{"sub.example.com", true},
		{"localhost", false},
		{"", false},
	}

	for _, tt := range tests {
		if got := hostMatchesBlocked(tt.host, blocked); got != tt.want {
			t.Errorf("hostMatchesBlocked(%q) = %v, want %v", tt.host, got, tt.want)
		}
	}
}

func TestIsBlockedReferer(t *testing.T) {
	blocked := []string{"bylampa.online"}

	if host, ok := isBlockedReferer("https://zerkalo.bylampa.online/player", "", blocked); !ok || host != "zerkalo.bylampa.online" {
		t.Fatalf("expected blocked referer, got host=%q ok=%v", host, ok)
	}
	if _, ok := isBlockedReferer("", "https://bylampa.online", blocked); !ok {
		t.Fatal("expected blocked origin")
	}
	if _, ok := isBlockedReferer("", "", blocked); ok {
		t.Fatal("expected empty headers to pass")
	}
	if _, ok := isBlockedReferer("https://myserver.local/stream", "", blocked); ok {
		t.Fatal("expected unrelated referer to pass")
	}
}

func TestBlockedReferersFromFile(t *testing.T) {
	got := blockedReferersFromFile([]byte("example.com\nbylampa.online\n"))
	want := []string{"bylampa.online", "example.com"}
	if len(got) != len(want) {
		t.Fatalf("blockedReferersFromFile() = %v, want %v", got, want)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("blockedReferersFromFile()[%d] = %q, want %q", i, got[i], want[i])
		}
	}

	empty := blockedReferersFromFile(nil)
	if len(empty) != 1 || empty[0] != "bylampa.online" {
		t.Fatalf("blockedReferersFromFile(nil) = %v, want [bylampa.online]", empty)
	}
}

func TestScanRefererBuf(t *testing.T) {
	got := scanRefererBuf([]byte("# comment\nbylampa.online\n\n# another\nexample.com\n"))
	want := []string{"bylampa.online", "example.com"}
	if len(got) != len(want) {
		t.Fatalf("scanRefererBuf() = %v, want %v", got, want)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("scanRefererBuf()[%d] = %q, want %q", i, got[i], want[i])
		}
	}
}
