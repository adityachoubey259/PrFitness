package httpapi

import (
	"net/http/httptest"
	"testing"
)

func TestClientIPTrustsRealIPFromLoopbackProxy(t *testing.T) {
	request := httptest.NewRequest("GET", "http://localhost/", nil)
	request.RemoteAddr = "127.0.0.1:51234"
	request.Header.Set("X-Real-IP", "198.51.100.25")

	got := clientIP(request)

	if got != "198.51.100.25" {
		t.Fatalf("expected trusted proxy client IP, got %q", got)
	}
}

func TestClientIPRejectsSpoofedRealIPFromRemotePeer(t *testing.T) {
	request := httptest.NewRequest("GET", "http://localhost/", nil)
	request.RemoteAddr = "203.0.113.44:51234"
	request.Header.Set("X-Real-IP", "198.51.100.25")

	got := clientIP(request)

	if got != "203.0.113.44" {
		t.Fatalf("expected transport peer IP, got %q", got)
	}
}

func TestClientIPRejectsInvalidProxyHeader(t *testing.T) {
	request := httptest.NewRequest("GET", "http://localhost/", nil)
	request.RemoteAddr = "127.0.0.1:51234"
	request.Header.Set("X-Real-IP", "not-an-ip")

	got := clientIP(request)

	if got != "127.0.0.1" {
		t.Fatalf("expected loopback peer for invalid header, got %q", got)
	}
}
