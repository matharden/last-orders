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
	"sort"
	"strings"
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
	mux.HandleFunc("/api/drinks", authMiddlewareFunc(handleApiDrinks))
	mux.HandleFunc("/api/catalog", authMiddlewareFunc(handleApiCatalog))
	mux.HandleFunc("/api/log/{id}", authMiddlewareFunc(handleApiLogItem))
	mux.HandleFunc("/api/log", authMiddlewareFunc(handleApiLog))

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

		// Check if the drink is already in the Booze sheet, and if not, add it
		boozeData, err := sheets.ReadRange("Booze!A:E")
		if err == nil {
			drinkExists := false
			trimmedReqDrink := strings.TrimSpace(req.Drink)
			for _, row := range boozeData {
				if len(row) > 2 {
					if strings.EqualFold(strings.TrimSpace(fmt.Sprintf("%v", row[2])), trimmedReqDrink) {
						drinkExists = true
						break
					}
				}
			}

			if !drinkExists && trimmedReqDrink != "" {
				// Calculate next ID for the Booze sheet
				maxBoozeID := 0
				for _, row := range boozeData {
					if len(row) > 0 {
						var id int
						_, err := fmt.Sscanf(fmt.Sprintf("%v", row[0]), "%d", &id)
						if err == nil {
							if id > maxBoozeID {
								maxBoozeID = id
							}
						}
					}
				}
				nextBoozeID := maxBoozeID + 1

				// Append new drink to Booze sheet
				newBoozeRow := []interface{}{nextBoozeID, "", trimmedReqDrink, "", ""}
				_ = sheets.WriteRange("Booze!A:E", newBoozeRow) // ignore error to not block logging if just master list append fails
			}
		}

		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"success"}`))
	} else if r.Method == http.MethodPut {
		// Update existing row in sheets
		var req struct {
			ID     int     `json:"id"`
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

		// Read current data to find the row index of the matching ID
		data, err := sheets.ReadData()
		if err != nil {
			http.Error(w, fmt.Sprintf("Failed to read sheet data: %v", err), http.StatusInternalServerError)
			return
		}

		rowIndex := -1
		for i, row := range data {
			if len(row) > 0 {
				var id int
				_, err := fmt.Sscanf(fmt.Sprintf("%v", row[0]), "%d", &id)
				if err == nil && id == req.ID {
					rowIndex = i
					break
				}
			}
		}

		if rowIndex == -1 {
			http.Error(w, fmt.Sprintf("Entry with ID %d not found", req.ID), http.StatusNotFound)
			return
		}

		// Convert date to standard 2 Jan format
		var dateStr string
		if req.Date != "" {
			t, err := time.Parse("2006-01-02", req.Date)
			if err != nil {
				_, err2 := time.Parse("2 Jan", req.Date)
				if err2 == nil {
					dateStr = req.Date
				} else {
					dateStr = time.Now().Format("2 Jan")
				}
			} else {
				dateStr = t.Format("2 Jan")
			}
		} else {
			dateStr = time.Now().Format("2 Jan")
		}

		values := []interface{}{
			req.ID,
			dateStr,
			req.Drink,
			req.Amount,
			req.Size,
			req.Notes,
		}

		// Update specific row (row number is rowIndex + 1 because sheet is 1-indexed)
		rangeName := fmt.Sprintf("Booze log!A%d:F%d", rowIndex+1, rowIndex+1)
		err = sheets.UpdateRange(rangeName, values)
		if err != nil {
			http.Error(w, fmt.Sprintf("Failed to update data: %v", err), http.StatusInternalServerError)
			return
		}

		// Also check if the drink is new and add to Booze sheet
		boozeData, err := sheets.ReadRange("Booze!A:E")
		if err == nil {
			drinkExists := false
			trimmedReqDrink := strings.TrimSpace(req.Drink)
			for _, row := range boozeData {
				if len(row) > 2 {
					if strings.EqualFold(strings.TrimSpace(fmt.Sprintf("%v", row[2])), trimmedReqDrink) {
						drinkExists = true
						break
					}
				}
			}

			if !drinkExists && trimmedReqDrink != "" {
				maxBoozeID := 0
				for _, row := range boozeData {
					if len(row) > 0 {
						var id int
						_, err := fmt.Sscanf(fmt.Sprintf("%v", row[0]), "%d", &id)
						if err == nil {
							if id > maxBoozeID {
								maxBoozeID = id
							}
						}
					}
				}
				nextBoozeID := maxBoozeID + 1

				newBoozeRow := []interface{}{nextBoozeID, "", trimmedReqDrink, "", ""}
				_ = sheets.WriteRange("Booze!A:E", newBoozeRow)
			}
		}

		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"success"}`))
	} else if r.Method == http.MethodDelete {
		idStr := r.URL.Query().Get("id")
		if idStr == "" {
			http.Error(w, "Missing id parameter", http.StatusBadRequest)
			return
		}
		var id int
		_, err := fmt.Sscanf(idStr, "%d", &id)
		if err != nil {
			http.Error(w, "Invalid id parameter", http.StatusBadRequest)
			return
		}

		// Read current data to find the row index of the matching ID
		data, err := sheets.ReadData()
		if err != nil {
			http.Error(w, fmt.Sprintf("Failed to read sheet data: %v", err), http.StatusInternalServerError)
			return
		}

		rowIndex := -1
		for i, row := range data {
			if len(row) > 0 {
				var rID int
				_, err := fmt.Sscanf(fmt.Sprintf("%v", row[0]), "%d", &rID)
				if err == nil && rID == id {
					rowIndex = i
					break
				}
			}
		}

		if rowIndex == -1 {
			http.Error(w, fmt.Sprintf("Entry with ID %d not found", id), http.StatusNotFound)
			return
		}

		err = sheets.DeleteRow("Booze log", rowIndex)
		if err != nil {
			http.Error(w, fmt.Sprintf("Failed to delete row: %v", err), http.StatusInternalServerError)
			return
		}

		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"success"}`))
	} else {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

func handleApiDrinks(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodGet {
		data, err := sheets.ReadRange("Booze!A:E")
		if err != nil {
			http.Error(w, fmt.Sprintf("Failed to read Booze sheet: %v", err), http.StatusInternalServerError)
			return
		}

		var drinks []string
		if len(data) > 1 {
			for _, row := range data[1:] {
				if len(row) > 2 {
					drinkName := fmt.Sprintf("%v", row[2])
					if drinkName != "" {
						drinks = append(drinks, drinkName)
					}
				}
			}
		}

		// Remove duplicates
		uniqueDrinks := make([]string, 0)
		seen := make(map[string]bool)
		for _, d := range drinks {
			d = strings.TrimSpace(d)
			if d != "" && !seen[strings.ToLower(d)] {
				seen[strings.ToLower(d)] = true
				uniqueDrinks = append(uniqueDrinks, d)
			}
		}

		// Sort case-insensitively
		sort.Slice(uniqueDrinks, func(i, j int) bool {
			return strings.ToLower(uniqueDrinks[i]) < strings.ToLower(uniqueDrinks[j])
		})

		json.NewEncoder(w).Encode(uniqueDrinks)
	} else {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

// ---- Structured types for the new frontend ----

type Drink struct {
	ID      int     `json:"id"`
	Brewery string  `json:"brewery"`
	Drink   string  `json:"drink"`
	ABV     float64 `json:"abv"`
	Rating  int     `json:"rating"`
	Style   string  `json:"style"`
	Image   string  `json:"image"`
}

type LogEntry struct {
	ID     string  `json:"id"`
	Date   string  `json:"date"`
	Drink  string  `json:"drink"`
	Amount float64 `json:"amount"`
	Size   int     `json:"size"`
	Notes  string  `json:"notes"`
}

func parseRowsToLogEntries(rows [][]interface{}, start int) []LogEntry {
	if len(rows) == 0 {
		return []LogEntry{}
	}

	type rawEntry struct {
		row   []interface{}
		t     time.Time
		month time.Month
		day   int
		hasT  bool
	}

	raws := make([]rawEntry, len(rows))
	for i := start; i < len(rows); i++ {
		row := rows[i]
		if len(row) < 3 {
			continue
		}
		rawDate := strings.TrimSpace(fmt.Sprintf("%v", row[1]))
		
		if t, err := time.Parse("2006-01-02", rawDate); err == nil {
			raws[i] = rawEntry{
				row:   row,
				t:     t,
				month: t.Month(),
				day:   t.Day(),
				hasT:  true,
			}
		} else if t, err := time.Parse("2 Jan", rawDate); err == nil {
			raws[i] = rawEntry{
				row:   row,
				month: t.Month(),
				day:   t.Day(),
				hasT:  false,
			}
		} else {
			tNow := time.Now()
			raws[i] = rawEntry{
				row:   row,
				month: tNow.Month(),
				day:   tNow.Day(),
				hasT:  false,
			}
		}
	}

	now := time.Now()
	currentYear := now.Year()

	lastYear := currentYear
	for i := len(raws) - 1; i >= start; i-- {
		if raws[i].row == nil {
			continue
		}
		if raws[i].hasT {
			lastYear = raws[i].t.Year()
			break
		}
	}

	assignedYears := make([]int, len(raws))
	activeYear := lastYear
	var nextMonth time.Month = 0
	var nextHasVal bool = false

	for i := len(raws) - 1; i >= start; i-- {
		if raws[i].row == nil {
			continue
		}
		
		if raws[i].hasT {
			activeYear = raws[i].t.Year()
			assignedYears[i] = activeYear
			nextMonth = raws[i].month
			nextHasVal = true
			continue
		}

		if nextHasVal {
			currMonth := raws[i].month
			if int(currMonth) - int(nextMonth) >= 6 {
				activeYear--
			}
		}
		
		assignedYears[i] = activeYear
		nextMonth = raws[i].month
		nextHasVal = true
	}

	var result []LogEntry
	for i := start; i < len(raws); i++ {
		r := raws[i]
		if r.row == nil {
			continue
		}
		
		var dateStr string
		if r.hasT {
			dateStr = r.t.Format("2006-01-02")
		} else {
			dateStr = fmt.Sprintf("%d-%02d-%02d", assignedYears[i], int(r.month), r.day)
		}

		e := LogEntry{
			ID:    strings.TrimSpace(fmt.Sprintf("%v", r.row[0])),
			Date:  dateStr,
			Drink: fmt.Sprintf("%v", r.row[2]),
		}
		if len(r.row) > 3 {
			e.Amount = parseFloat(r.row[3])
		}
		if len(r.row) > 4 {
			e.Size = parseInt(r.row[4])
		}
		if len(r.row) > 5 {
			e.Notes = fmt.Sprintf("%v", r.row[5])
		}
		result = append(result, e)
	}

	return result
}

func parseDateToISO(s string) string {
	s = strings.TrimSpace(s)
	if s == "" {
		return time.Now().Format("2006-01-02")
	}
	if _, err := time.Parse("2006-01-02", s); err == nil {
		return s
	}
	if t, err := time.Parse("2 Jan", s); err == nil {
		now := time.Now()
		year := now.Year()
		parsed := time.Date(year, t.Month(), t.Day(), 0, 0, 0, 0, now.Location())
		if parsed.After(now.Add(24 * time.Hour)) {
			year--
		}
		return fmt.Sprintf("%d-%02d-%02d", year, int(t.Month()), t.Day())
	}
	return s
}

func parseFloat(v interface{}) float64 {
	var f float64
	fmt.Sscanf(fmt.Sprintf("%v", v), "%f", &f)
	return f
}

func parseInt(v interface{}) int {
	var i int
	fmt.Sscanf(fmt.Sprintf("%v", v), "%d", &i)
	return i
}

func handleApiCatalog(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	rows, err := sheets.ReadRange("Booze!A:G")
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to read catalog: %v", err), http.StatusInternalServerError)
		return
	}
	var result []Drink
	start := 0
	if len(rows) > 0 {
		var id int
		if _, err := fmt.Sscanf(fmt.Sprintf("%v", rows[0][0]), "%d", &id); err != nil {
			start = 1
		}
	}
	for _, row := range rows[start:] {
		if len(row) < 3 {
			continue
		}
		d := Drink{
			ID:      parseInt(row[0]),
			Brewery: fmt.Sprintf("%v", row[1]),
			Drink:   fmt.Sprintf("%v", row[2]),
		}
		if len(row) > 3 {
			d.ABV = parseFloat(row[3])
		}
		if len(row) > 4 {
			d.Rating = parseInt(row[4])
		}
		if len(row) > 5 {
			d.Style = fmt.Sprintf("%v", row[5])
		}
		if len(row) > 6 {
			d.Image = fmt.Sprintf("%v", row[6])
		}
		if d.Drink == "" {
			continue
		}
		result = append(result, d)
	}
	if result == nil {
		result = []Drink{}
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

func handleApiLog(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	switch r.Method {
	case http.MethodGet:
		rows, err := sheets.ReadData()
		if err != nil {
			http.Error(w, fmt.Sprintf("Failed to read log: %v", err), http.StatusInternalServerError)
			return
		}
		start := 0
		if len(rows) > 0 {
			var id int
			if _, err := fmt.Sscanf(fmt.Sprintf("%v", rows[0][0]), "%d", &id); err != nil {
				start = 1
			}
		}
		result := parseRowsToLogEntries(rows, start)
		json.NewEncoder(w).Encode(result)

	case http.MethodPost:
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
		rows, err := sheets.ReadData()
		if err != nil {
			http.Error(w, "Failed to read log", http.StatusInternalServerError)
			return
		}
		maxID := 0
		for _, row := range rows {
			if len(row) > 0 {
				if id := parseInt(row[0]); id > maxID {
					maxID = id
				}
			}
		}
		nextID := maxID + 1
		dateStr := time.Now().Format("2 Jan")
		if req.Date != "" {
			if t, err := time.Parse("2006-01-02", req.Date); err == nil {
				dateStr = t.Format("2 Jan")
			}
		}
		if err := sheets.WriteData([]interface{}{nextID, dateStr, req.Drink, req.Amount, req.Size, req.Notes}); err != nil {
			http.Error(w, "Failed to write log", http.StatusInternalServerError)
			return
		}
		addToCatalogIfNew(req.Drink)
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(LogEntry{ID: fmt.Sprintf("%d", nextID), Date: req.Date, Drink: req.Drink, Amount: req.Amount, Size: req.Size, Notes: req.Notes})

	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

func handleApiLogItem(w http.ResponseWriter, r *http.Request) {
	idStr := strings.TrimSpace(r.PathValue("id"))
	if idStr == "" {
		http.Error(w, "Invalid id", http.StatusBadRequest)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	switch r.Method {
	case http.MethodPut:
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
		rows, err := sheets.ReadData()
		if err != nil {
			http.Error(w, "Failed to read log", http.StatusInternalServerError)
			return
		}
		rowIndex := -1
		for i, row := range rows {
			if len(row) > 0 && strings.TrimSpace(fmt.Sprintf("%v", row[0])) == idStr {
				rowIndex = i
				break
			}
		}
		if rowIndex == -1 {
			http.Error(w, "Not found", http.StatusNotFound)
			return
		}
		dateStr := time.Now().Format("2 Jan")
		if req.Date != "" {
			if t, err := time.Parse("2006-01-02", req.Date); err == nil {
				dateStr = t.Format("2 Jan")
			}
		}
		rangeName := fmt.Sprintf("Booze log!A%d:F%d", rowIndex+1, rowIndex+1)
		if err := sheets.UpdateRange(rangeName, []interface{}{idStr, dateStr, req.Drink, req.Amount, req.Size, req.Notes}); err != nil {
			http.Error(w, "Failed to update log", http.StatusInternalServerError)
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})

	case http.MethodDelete:
		rows, err := sheets.ReadData()
		if err != nil {
			http.Error(w, "Failed to read log", http.StatusInternalServerError)
			return
		}
		rowIndex := -1
		for i, row := range rows {
			if len(row) > 0 && strings.TrimSpace(fmt.Sprintf("%v", row[0])) == idStr {
				rowIndex = i
				break
			}
		}
		if rowIndex == -1 {
			http.Error(w, "Not found", http.StatusNotFound)
			return
		}
		if err := sheets.DeleteRow("Booze log", rowIndex); err != nil {
			http.Error(w, "Failed to delete row", http.StatusInternalServerError)
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})

	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

func addToCatalogIfNew(drinkName string) {
	drinkName = strings.TrimSpace(drinkName)
	if drinkName == "" {
		return
	}
	rows, err := sheets.ReadRange("Booze!A:E")
	if err != nil {
		return
	}
	for _, row := range rows {
		if len(row) > 2 && strings.EqualFold(strings.TrimSpace(fmt.Sprintf("%v", row[2])), drinkName) {
			return
		}
	}
	maxID := 0
	for _, row := range rows {
		if len(row) > 0 {
			if id := parseInt(row[0]); id > maxID {
				maxID = id
			}
		}
	}
	_ = sheets.WriteRange("Booze!A:E", []interface{}{maxID + 1, "", drinkName, "", ""})
}
