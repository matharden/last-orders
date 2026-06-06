package main

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
	"github.com/joho/godotenv"
	"boozer/sheets"
)

var (
	googleOauthConfig *oauth2.Config
	oauthStateString  = generateStateOauthCookie()
	authorizedEmail   string
)

// Config is now initialized in main()

func generateStateOauthCookie() string {
	b := make([]byte, 16)
	rand.Read(b)
	return base64.URLEncoding.EncodeToString(b)
}

func main() {
	// Load .env file if it exists (useful for local development)
	_ = godotenv.Load()

	// Initialize configuration from environment variables
	authorizedEmail = os.Getenv("AUTHORIZED_EMAIL")
	googleOauthConfig = &oauth2.Config{
		RedirectURL:  os.Getenv("OAUTH_REDIRECT_URL"),
		ClientID:     os.Getenv("GOOGLE_CLIENT_ID"),
		ClientSecret: os.Getenv("GOOGLE_CLIENT_SECRET"),
		Scopes:       []string{"https://www.googleapis.com/auth/userinfo.email"},
		Endpoint:     google.Endpoint,
	}

	// Initialize sheets client
	err := sheets.Init()
	if err != nil {
		log.Printf("Warning: Failed to initialize sheets client: %v", err)
	}

	mux := http.NewServeMux()

	// Serve static files
	fs := http.FileServer(http.Dir("static"))
	mux.Handle("/", authMiddleware(fs))

	// Auth routes
	mux.HandleFunc("/login", handleGoogleLogin)
	mux.HandleFunc("/callback", handleGoogleCallback)
	mux.HandleFunc("/logout", handleLogout)

	// API routes
	mux.HandleFunc("/api/data", authMiddlewareFunc(handleApiData))

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	log.Printf("Server listening on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, mux))
}

func handleGoogleLogin(w http.ResponseWriter, r *http.Request) {
	url := googleOauthConfig.AuthCodeURL(oauthStateString)
	http.Redirect(w, r, url, http.StatusTemporaryRedirect)
}

func handleGoogleCallback(w http.ResponseWriter, r *http.Request) {
	if r.FormValue("state") != oauthStateString {
		http.Redirect(w, r, "/", http.StatusTemporaryRedirect)
		return
	}

	token, err := googleOauthConfig.Exchange(context.Background(), r.FormValue("code"))
	if err != nil {
		http.Error(w, "Code exchange failed", http.StatusInternalServerError)
		return
	}

	client := googleOauthConfig.Client(context.Background(), token)
	resp, err := client.Get("https://www.googleapis.com/oauth2/v2/userinfo")
	if err != nil {
		http.Error(w, "Failed to get user info", http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	var userInfo struct {
		Email string `json:"email"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&userInfo); err != nil {
		http.Error(w, "Failed to decode user info", http.StatusInternalServerError)
		return
	}

	if authorizedEmail != "" && userInfo.Email != authorizedEmail {
		http.Error(w, "Unauthorized email address", http.StatusUnauthorized)
		return
	}

	// Set a simple cookie for demonstration. In production, use signed JWT or gorilla/sessions
	cookie := &http.Cookie{
		Name:     "auth_session",
		Value:    "authenticated",
		Path:     "/",
		HttpOnly: true,
		Secure:   os.Getenv("ENV") == "production",
	}
	http.SetCookie(w, cookie)
	http.Redirect(w, r, "/", http.StatusTemporaryRedirect)
}

func handleLogout(w http.ResponseWriter, r *http.Request) {
	cookie := &http.Cookie{
		Name:   "auth_session",
		Value:  "",
		Path:   "/",
		MaxAge: -1,
	}
	http.SetCookie(w, cookie)
	http.Redirect(w, r, "/login", http.StatusTemporaryRedirect)
}

func authMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Bypass auth for login and callback
		if r.URL.Path == "/login" || r.URL.Path == "/callback" {
			next.ServeHTTP(w, r)
			return
		}

		cookie, err := r.Cookie("auth_session")
		if err != nil || cookie.Value != "authenticated" {
			// If not authenticated and asking for an API, return 401
			if len(r.URL.Path) > 4 && r.URL.Path[:4] == "/api" {
				http.Error(w, "Unauthorized", http.StatusUnauthorized)
				return
			}
			// Otherwise redirect to login
			http.Redirect(w, r, "/login", http.StatusTemporaryRedirect)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func authMiddlewareFunc(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		cookie, err := r.Cookie("auth_session")
		if err != nil || cookie.Value != "authenticated" {
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}
		next(w, r)
	}
}

func handleApiData(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodGet {
		// Read from sheets
		data, err := sheets.ReadData()
		if err != nil {
			http.Error(w, fmt.Sprintf("Failed to read data: %v", err), http.StatusInternalServerError)
			return
		}
		json.NewEncoder(w).Encode(data)
	} else if r.Method == http.MethodPost {
		// Write to sheets
		var req struct {
			Date   string  `json:"date"`
			Drink  string  `json:"drink"`
			Amount float64 `json:"amount"`
			Size   int     `json:"size"`
			Notes  string  `json:"notes"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Invalid request body", http.StatusBadRequest)
			return
		}

		// Read current data to generate next ID
		data, err := sheets.ReadData()
		if err != nil {
			http.Error(w, fmt.Sprintf("Failed to read sheet data: %v", err), http.StatusInternalServerError)
			return
		}

		maxID := 0
		for _, row := range data {
			if len(row) > 0 {
				var id int
				_, err := fmt.Sscanf(fmt.Sprintf("%v", row[0]), "%d", &id)
				if err == nil {
					if id > maxID {
						maxID = id
					}
				}
			}
		}
		nextID := maxID + 1

		var dateStr string
		if req.Date != "" {
			t, err := time.Parse("2006-01-02", req.Date)
			if err != nil {
				dateStr = time.Now().Format("2 Jan")
			} else {
				dateStr = t.Format("2 Jan")
			}
		} else {
			dateStr = time.Now().Format("2 Jan")
		}

		values := []interface{}{
			nextID,
			dateStr,
			req.Drink,
			req.Amount,
			req.Size,
			req.Notes,
		}

		err = sheets.WriteData(values)
		if err != nil {
			http.Error(w, fmt.Sprintf("Failed to write data: %v", err), http.StatusInternalServerError)
			return
		}
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"success"}`))
	} else {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}
