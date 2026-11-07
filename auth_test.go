package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func withTestAuth(t *testing.T, email string) {
	t.Helper()
	oldKey, oldEmail := sessionKey, authorizedEmail
	sessionKey, authorizedEmail = []byte("test-key"), email
	t.Cleanup(func() { sessionKey, authorizedEmail = oldKey, oldEmail })
}

func TestTokenRoundTrip(t *testing.T) {
	withTestAuth(t, "me@example.com")
	tok := issueToken("me@example.com", time.Hour)
	email, exp, ok := verifyToken(tok)
	if !ok || email != "me@example.com" || time.Until(exp) < 59*time.Minute {
		t.Fatalf("verify failed: %q %v %v", email, exp, ok)
	}
}

func TestTokenRejects(t *testing.T) {
	withTestAuth(t, "me@example.com")
	cases := map[string]string{
		"raw email (old cookie)": "me@example.com",
		"expired":                issueToken("me@example.com", -time.Minute),
		"other user":             issueToken("someone@example.com", time.Hour),
		"tampered":               strings.Replace(issueToken("me@example.com", time.Hour), ".", "x.", 1),
		"empty":                  "",
	}
	for name, tok := range cases {
		if _, _, ok := verifyToken(tok); ok {
			t.Errorf("%s: token accepted", name)
		}
	}
}

func TestMiddleware(t *testing.T) {
	withTestAuth(t, "me@example.com")
	var got string
	h := authMiddlewareFunc(func(w http.ResponseWriter, r *http.Request) { got = emailFromRequest(r) })

	// Forged cookie is rejected.
	req := httptest.NewRequest("GET", "/api/log", nil)
	req.AddCookie(&http.Cookie{Name: sessionCookieName, Value: "me@example.com"})
	rec := httptest.NewRecorder()
	h(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("forged cookie: got %d", rec.Code)
	}

	// Valid cookie passes; nearly-expired cookie is renewed.
	req = httptest.NewRequest("GET", "/api/log", nil)
	req.AddCookie(&http.Cookie{Name: sessionCookieName, Value: issueToken("me@example.com", 24*time.Hour)})
	rec = httptest.NewRecorder()
	h(rec, req)
	if rec.Code != http.StatusOK || got != "me@example.com" {
		t.Fatalf("valid cookie: got %d %q", rec.Code, got)
	}
	if !strings.Contains(rec.Header().Get("Set-Cookie"), sessionCookieName+"=") {
		t.Errorf("expected renewed cookie")
	}

	// Bearer token passes and is renewed via header when old.
	req = httptest.NewRequest("GET", "/api/log", nil)
	req.Header.Set("Authorization", "Bearer "+issueToken("me@example.com", 24*time.Hour))
	rec = httptest.NewRecorder()
	h(rec, req)
	if rec.Code != http.StatusOK || rec.Header().Get("X-Session-Token") == "" {
		t.Fatalf("bearer: got %d, renew header %q", rec.Code, rec.Header().Get("X-Session-Token"))
	}
}
