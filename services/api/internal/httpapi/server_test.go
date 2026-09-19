package httpapi

import (
	"net/http/httptest"
	"testing"
)

func TestNormalizeEmail(t *testing.T) {
	t.Parallel()
	got, err := normalizeEmail("  Example.User@example.com ")
	if err != nil {
		t.Fatal(err)
	}
	if got != "example.user@example.com" {
		t.Fatalf("unexpected normalized email: %s", got)
	}
}

func TestRandomTokenIsUnique(t *testing.T) {
	t.Parallel()
	first, err := randomOpaqueToken()
	if err != nil {
		t.Fatal(err)
	}
	second, err := randomOpaqueToken()
	if err != nil {
		t.Fatal(err)
	}
	if first == second {
		t.Fatal("random tokens must differ")
	}
	if len(first) < 40 {
		t.Fatal("refresh token unexpectedly short")
	}
}

func TestAuthRateLimit(t *testing.T) {
	t.Parallel()
	server := New(nil, nil)
	allowed := 0
	for index := 0; index < 25; index++ {
		request := httptest.NewRequest("POST", "http://example.test/v1/auth/login", nil)
		request.RemoteAddr = "192.0.2.10:5555"
		if server.allowAuth(request) {
			allowed++
		}
	}
	if allowed != 20 {
		t.Fatalf("expected 20 requests, got %d", allowed)
	}
}
