package main

import (
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"
)

// Sessions are stateless signed tokens: base64url("email|expiryUnix") + "." + HMAC.
// The web app gets one in the auth_session cookie; the iOS app gets one via the
// lastorders:// callback and sends it as "Authorization: Bearer <token>".
// Because they're signed with a key every Cloud Run instance shares, they survive
// cold starts and instance changes.

const (
	sessionCookieName = "auth_session"
	stateCookieName   = "oauth_state"

	webSessionTTL = 90 * 24 * time.Hour
	appSessionTTL = 365 * 24 * time.Hour

	// Tokens are re-issued (sliding expiry) once less than this much time is left.
	webRenewWithin = 45 * 24 * time.Hour
	appRenewWithin = 180 * 24 * time.Hour

	iosCallbackURL = "lastorders://auth"
)

var sessionKey []byte

// initSessionKey loads SESSION_SECRET, or derives a stable key from
// GOOGLE_CLIENT_SECRET so existing deployments work without new config.
func initSessionKey() {
	if s := os.Getenv("SESSION_SECRET"); s != "" {
		sessionKey = []byte(s)
		return
	}
	if cs := os.Getenv("GOOGLE_CLIENT_SECRET"); cs != "" {
		mac := hmac.New(sha256.New, []byte(cs))
		mac.Write([]byte("last-orders session key v1"))
		sessionKey = mac.Sum(nil)
		log.Printf("SESSION_SECRET not set; deriving session key from GOOGLE_CLIENT_SECRET")
		return
	}
	sessionKey = make([]byte, 32)
	rand.Read(sessionKey)
	log.Printf("Warning: no SESSION_SECRET or GOOGLE_CLIENT_SECRET; sessions will not survive a restart")
}

func signPayload(p string) string {
	mac := hmac.New(sha256.New, sessionKey)
	mac.Write([]byte(p))
	return base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
}

func issueToken(email string, ttl time.Duration) string {
	payload := email + "|" + strconv.FormatInt(time.Now().Add(ttl).Unix(), 10)
	p := base64.RawURLEncoding.EncodeToString([]byte(payload))
	return p + "." + signPayload(p)
}

// verifyToken checks the signature, expiry and (if configured) the authorised email.
func verifyToken(tok string) (email string, expires time.Time, ok bool) {
	dot := strings.LastIndex(tok, ".")
	if dot <= 0 {
		return "", time.Time{}, false
	}
	p, sig := tok[:dot], tok[dot+1:]
	if !hmac.Equal([]byte(sig), []byte(signPayload(p))) {
		return "", time.Time{}, false
	}
	raw, err := base64.RawURLEncoding.DecodeString(p)
	if err != nil {
		return "", time.Time{}, false
	}
	bar := strings.LastIndex(string(raw), "|")
	if bar <= 0 {
		return "", time.Time{}, false
	}
	email = string(raw[:bar])
	exp, err := strconv.ParseInt(string(raw[bar+1:]), 10, 64)
	if err != nil {
		return "", time.Time{}, false
	}
	expires = time.Unix(exp, 0)
	if time.Now().After(expires) {
		return "", time.Time{}, false
	}
	if authorizedEmail != "" && !strings.EqualFold(email, authorizedEmail) {
		return "", time.Time{}, false
	}
	return email, expires, true
}

func isProduction() bool { return os.Getenv("ENV") == "production" }

func setSessionCookie(w http.ResponseWriter, token string) {
	http.SetCookie(w, &http.Cookie{
		Name:     sessionCookieName,
		Value:    token,
		Path:     "/",
		MaxAge:   int(webSessionTTL.Seconds()),
		HttpOnly: true,
		Secure:   isProduction(),
		SameSite: http.SameSiteLaxMode,
	})
}

func clearCookie(w http.ResponseWriter, name string) {
	http.SetCookie(w, &http.Cookie{
		Name:     name,
		Value:    "",
		Path:     "/",
		MaxAge:   -1,
		HttpOnly: true,
		Secure:   isProduction(),
		SameSite: http.SameSiteLaxMode,
	})
}

type emailCtxKey struct{}

// emailFromRequest returns the signed-in user's email (set by authMiddlewareFunc).
func emailFromRequest(r *http.Request) string {
	email, _ := r.Context().Value(emailCtxKey{}).(string)
	return email
}

// authMiddlewareFunc accepts a Bearer token (iOS) or the session cookie (web),
// renews tokens that are getting old, and puts the email in the request context.
func authMiddlewareFunc(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var email string
		var expires time.Time
		ok := false

		if h := r.Header.Get("Authorization"); strings.HasPrefix(h, "Bearer ") {
			email, expires, ok = verifyToken(strings.TrimPrefix(h, "Bearer "))
			if ok && time.Until(expires) < appRenewWithin {
				w.Header().Set("X-Session-Token", issueToken(email, appSessionTTL))
			}
		} else if c, err := r.Cookie(sessionCookieName); err == nil && c.Value != "" {
			email, expires, ok = verifyToken(c.Value)
			if ok && time.Until(expires) < webRenewWithin {
				setSessionCookie(w, issueToken(email, webSessionTTL))
			}
		}

		if !ok {
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}
		next(w, r.WithContext(context.WithValue(r.Context(), emailCtxKey{}, email)))
	}
}
