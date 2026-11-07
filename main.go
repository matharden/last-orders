package main

import (
	"crypto/hmac"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	neturl "net/url"
	"os"
	"strings"
	"time"

	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
	"github.com/joho/godotenv"
	"boozer/sheets"
	"boozer/gcs"
)

var (
	googleOauthConfig *oauth2.Config
	authorizedEmail   string
)

func randomState() string {
	b := make([]byte, 16)
	rand.Read(b)
	return base64.RawURLEncoding.EncodeToString(b)
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
	initSessionKey()

	// Initialize sheets client
	err := sheets.Init()
	if err != nil {
		log.Printf("Warning: Failed to initialize sheets client: %v", err)
	}

	// Initialize gcs client
	err = gcs.Init()
	if err != nil {
		log.Printf("Warning: Failed to initialize gcs client: %v", err)
	}

	mux := http.NewServeMux()

	// Serve static files
	fs := http.FileServer(http.Dir("static"))
	// The SPA shell is public; it shows the sign-in screen when /api/* returns 401.
	mux.Handle("/", fs)

	// Auth routes
	mux.HandleFunc("/login", handleGoogleLogin)
	mux.HandleFunc("/callback", handleGoogleCallback)
	mux.HandleFunc("/logout", handleLogout)

	// API routes
	mux.HandleFunc("/api/catalog/{id}", authMiddlewareFunc(handleApiCatalogItem))
	mux.HandleFunc("/api/catalog", authMiddlewareFunc(handleApiCatalog))
	mux.HandleFunc("/api/log/{id}", authMiddlewareFunc(handleApiLogItem))
	mux.HandleFunc("/api/log", authMiddlewareFunc(handleApiLog))
	mux.HandleFunc("/api/upload", authMiddlewareFunc(handleApiUpload))

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	log.Printf("Server listening on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, mux))
}

func handleGoogleLogin(w http.ResponseWriter, r *http.Request) {
	// The state lives in a short-lived cookie rather than server memory, so the
	// callback works even if Cloud Run routes it to a different instance.
	state := randomState()
	if r.URL.Query().Get("app") == "ios" {
		state += ".ios"
	}
	http.SetCookie(w, &http.Cookie{
		Name:     stateCookieName,
		Value:    state,
		Path:     "/",
		MaxAge:   600,
		HttpOnly: true,
		Secure:   isProduction(),
		SameSite: http.SameSiteLaxMode,
	})
	url := googleOauthConfig.AuthCodeURL(state)
	http.Redirect(w, r, url, http.StatusTemporaryRedirect)
}

func handleGoogleCallback(w http.ResponseWriter, r *http.Request) {
	stateCookie, err := r.Cookie(stateCookieName)
	state := r.FormValue("state")
	if err != nil || state == "" || !hmac.Equal([]byte(stateCookie.Value), []byte(state)) {
		http.Redirect(w, r, "/", http.StatusTemporaryRedirect)
		return
	}
	clearCookie(w, stateCookieName)
	isApp := strings.HasSuffix(state, ".ios")

	token, err := googleOauthConfig.Exchange(r.Context(), r.FormValue("code"))
	if err != nil {
		http.Error(w, "Code exchange failed", http.StatusInternalServerError)
		return
	}

	client := googleOauthConfig.Client(r.Context(), token)
	resp, err := client.Get("https://www.googleapis.com/oauth2/v2/userinfo")
	if err != nil {
		http.Error(w, "Failed to get user info", http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	var userInfo struct {
		Email         string `json:"email"`
		VerifiedEmail bool   `json:"verified_email"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&userInfo); err != nil {
		http.Error(w, "Failed to decode user info", http.StatusInternalServerError)
		return
	}

	if userInfo.Email == "" || !userInfo.VerifiedEmail ||
		(authorizedEmail != "" && !strings.EqualFold(userInfo.Email, authorizedEmail)) {
		http.Error(w, "Unauthorized email address", http.StatusUnauthorized)
		return
	}

	if isApp {
		q := neturl.Values{}
		q.Set("token", issueToken(userInfo.Email, appSessionTTL))
		q.Set("email", userInfo.Email)
		http.Redirect(w, r, iosCallbackURL+"?"+q.Encode(), http.StatusFound)
		return
	}

	setSessionCookie(w, issueToken(userInfo.Email, webSessionTTL))
	frontendURL := os.Getenv("FRONTEND_URL")
	if frontendURL == "" {
		frontendURL = "/"
	}
	http.Redirect(w, r, frontendURL, http.StatusTemporaryRedirect)
}

func handleLogout(w http.ResponseWriter, r *http.Request) {
	clearCookie(w, sessionCookieName)
	http.Redirect(w, r, "/", http.StatusTemporaryRedirect)
}

// ---- Structured types for the new frontend ----

type Drink struct {
	ID      int     `json:"id"`
	Brewery string  `json:"brewery"`
	Drink   string  `json:"drink"`
	ABV     float64 `json:"abv"`
	Rating  int     `json:"rating"`
	Image   string  `json:"image"`
	Notes   string  `json:"notes"`
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

// hasHeader reports whether the first row is a header (non-numeric ID).
func hasHeader(rows [][]interface{}) bool {
	if len(rows) == 0 || len(rows[0]) == 0 {
		return false
	}
	var id int
	_, err := fmt.Sscanf(fmt.Sprintf("%v", rows[0][0]), "%d", &id)
	return err != nil
}

func handleApiCatalog(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	rows, err := store.Rows(catalogRange)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to read catalog: %v", err), http.StatusInternalServerError)
		return
	}
	var result []Drink
	start := 0
	if hasHeader(rows) {
		start = 1
	}
	// Sign all photo URLs up front, in parallel (cached across requests).
	var imageNames []string
	for _, row := range rows[start:] {
		if img := cellString(row, 5); img != "" && !strings.HasPrefix(img, "http://") && !strings.HasPrefix(img, "https://") {
			imageNames = append(imageNames, img)
		}
	}
	signed := gcs.SignURLs(emailFromRequest(r), imageNames)

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
			imgVal := strings.TrimSpace(fmt.Sprintf("%v", row[5]))
			if imgVal != "" {
				if strings.HasPrefix(imgVal, "http://") || strings.HasPrefix(imgVal, "https://") {
					d.Image = imgVal
				} else if signedURL, ok := signed[imgVal]; ok {
					d.Image = signedURL
				} else {
					d.Image = imgVal
				}
			}
		}
		if len(row) > 6 {
			d.Notes = fmt.Sprintf("%v", row[6])
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

// findCatalogRow locates a catalog row by numeric ID in the cache and confirms
// it against the Sheet. Returns -1 if not found.
func findCatalogRow(id int) (int, [][]interface{}, error) {
	find := func(rows [][]interface{}) int {
		for i, row := range rows {
			if len(row) > 0 && parseInt(row[0]) == id {
				return i
			}
		}
		return -1
	}
	rows, err := store.Rows(catalogRange)
	if err != nil {
		return -1, nil, err
	}
	i := find(rows)
	if i == -1 {
		return -1, rows, nil
	}
	i, err = store.verifyRow(catalogSheet, catalogRange, i, cellString(rows[i], 0), find)
	if err != nil {
		return -1, nil, err
	}
	rows, _ = store.Rows(catalogRange)
	return i, rows, nil
}

func handleApiCatalogItem(w http.ResponseWriter, r *http.Request) {
	id := parseInt(r.PathValue("id"))
	if id == 0 {
		http.Error(w, "Invalid id", http.StatusBadRequest)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	switch r.Method {
	case http.MethodPut:
		var req struct {
			Brewery string  `json:"brewery"`
			Drink   string  `json:"drink"`
			ABV     float64 `json:"abv"`
			Rating  int     `json:"rating"`
			Image   string  `json:"image"`
			Notes   string  `json:"notes"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Invalid request body", http.StatusBadRequest)
			return
		}
		store.writeMu.Lock()
		defer store.writeMu.Unlock()
		rowIndex, _, err := findCatalogRow(id)
		if err != nil {
			http.Error(w, "Failed to read catalog", http.StatusInternalServerError)
			return
		}
		if rowIndex == -1 {
			http.Error(w, "Not found", http.StatusNotFound)
			return
		}

		// Store only the raw filename: if the client sent back a signed GCS URL,
		// extract the object name from it.
		imageToSave := req.Image
		if strings.Contains(imageToSave, "storage.googleapis.com") {
			parts := strings.Split(imageToSave, "?")
			pathParts := strings.Split(parts[0], "/")
			imageToSave = pathParts[len(pathParts)-1]
		}

		values := []interface{}{id, req.Brewery, req.Drink, req.ABV, req.Rating, imageToSave, req.Notes}
		if err := store.UpdateRow(catalogSheet, catalogRange, "G", rowIndex, values); err != nil {
			http.Error(w, "Failed to update catalog", http.StatusInternalServerError)
			return
		}

		responseImage := imageToSave
		if imageToSave != "" && !strings.HasPrefix(imageToSave, "http://") && !strings.HasPrefix(imageToSave, "https://") {
			if signedURL, err := gcs.SignURL(emailFromRequest(r), imageToSave); err == nil {
				responseImage = signedURL
			}
		}

		json.NewEncoder(w).Encode(Drink{ID: id, Brewery: req.Brewery, Drink: req.Drink, ABV: req.ABV, Rating: req.Rating, Image: responseImage, Notes: req.Notes})

	case http.MethodDelete:
		store.writeMu.Lock()
		defer store.writeMu.Unlock()
		rowIndex, rows, err := findCatalogRow(id)
		if err != nil {
			http.Error(w, "Failed to read catalog", http.StatusInternalServerError)
			return
		}
		if rowIndex == -1 {
			http.Error(w, "Not found", http.StatusNotFound)
			return
		}
		drinkName := cellString(rows[rowIndex], 2)

		if drinkName != "" {
			// Refuse if the drink is used in the journal.
			if logRows, err := store.Rows(logRange()); err == nil {
				for _, row := range logRows {
					if strings.EqualFold(cellString(row, 2), drinkName) {
						http.Error(w, "Cannot delete catalog entry because it is used in history log", http.StatusConflict)
						return
					}
				}
			}
		}

		if err := store.DeleteRow(catalogSheet, catalogRange, rowIndex); err != nil {
			http.Error(w, "Failed to delete catalog entry", http.StatusInternalServerError)
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})

	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

// sheetDate converts an ISO date from the client into the Sheet's "2 Jan" format
// (today if missing or invalid), and returns the ISO date it represents.
func sheetDate(iso string) (sheet string, normalized string) {
	t, err := time.Parse("2006-01-02", iso)
	if err != nil {
		t = time.Now()
	}
	return t.Format("2 Jan"), t.Format("2006-01-02")
}

func handleApiLog(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	switch r.Method {
	case http.MethodGet:
		rows, err := store.Rows(logRange())
		if err != nil {
			http.Error(w, fmt.Sprintf("Failed to read log: %v", err), http.StatusInternalServerError)
			return
		}
		start := 0
		if hasHeader(rows) {
			start = 1
		}
		result := parseRowsToLogEntries(rows, start)
		if result == nil {
			result = []LogEntry{}
		}
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
		store.writeMu.Lock()
		defer store.writeMu.Unlock()
		rows, err := store.Rows(logRange())
		if err != nil {
			http.Error(w, "Failed to read log", http.StatusInternalServerError)
			return
		}
		nextID := maxNumericID(rows) + 1
		dateStr, isoDate := sheetDate(req.Date)
		if err := store.Append(logRange(), []interface{}{nextID, dateStr, req.Drink, req.Amount, req.Size, req.Notes}); err != nil {
			http.Error(w, "Failed to write log", http.StatusInternalServerError)
			return
		}
		addToCatalogIfNew(req.Drink)
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(LogEntry{ID: fmt.Sprintf("%d", nextID), Date: isoDate, Drink: req.Drink, Amount: req.Amount, Size: req.Size, Notes: req.Notes})

	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

// findLogRow locates a journal row by ID in the cache and confirms it against the Sheet.
func findLogRow(idStr string) (int, error) {
	find := func(rows [][]interface{}) int { return findRowByID(rows, idStr) }
	rows, err := store.Rows(logRange())
	if err != nil {
		return -1, err
	}
	i := find(rows)
	if i == -1 {
		return -1, nil
	}
	return store.verifyRow(logSheet, logRange(), i, idStr, find)
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
		store.writeMu.Lock()
		defer store.writeMu.Unlock()
		rowIndex, err := findLogRow(idStr)
		if err != nil {
			http.Error(w, "Failed to read log", http.StatusInternalServerError)
			return
		}
		if rowIndex == -1 {
			http.Error(w, "Not found", http.StatusNotFound)
			return
		}
		dateStr, _ := sheetDate(req.Date)
		values := []interface{}{idStr, dateStr, req.Drink, req.Amount, req.Size, req.Notes}
		if err := store.UpdateRow(logSheet, logRange(), "F", rowIndex, values); err != nil {
			http.Error(w, "Failed to update log", http.StatusInternalServerError)
			return
		}
		addToCatalogIfNew(req.Drink)
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})

	case http.MethodDelete:
		store.writeMu.Lock()
		defer store.writeMu.Unlock()
		rowIndex, err := findLogRow(idStr)
		if err != nil {
			http.Error(w, "Failed to read log", http.StatusInternalServerError)
			return
		}
		if rowIndex == -1 {
			http.Error(w, "Not found", http.StatusNotFound)
			return
		}
		if err := store.DeleteRow(logSheet, logRange(), rowIndex); err != nil {
			http.Error(w, "Failed to delete row", http.StatusInternalServerError)
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})

	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

// addToCatalogIfNew appends a drink to the catalog if it isn't there yet.
// Callers must hold store.writeMu.
func addToCatalogIfNew(drinkName string) {
	drinkName = strings.TrimSpace(drinkName)
	if drinkName == "" {
		return
	}
	rows, err := store.Rows(catalogRange)
	if err != nil {
		return
	}
	for _, row := range rows {
		if strings.EqualFold(cellString(row, 2), drinkName) {
			return
		}
	}
	// Ignore errors: failing to update the master list shouldn't fail the log write.
	_ = store.Append(catalogRange, []interface{}{maxNumericID(rows) + 1, "", drinkName, "", ""})
}

func handleApiUpload(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	email := emailFromRequest(r)

	// limit uploads to 5MB
	err := r.ParseMultipartForm(5 << 20)
	if err != nil {
		http.Error(w, "Payload too large", http.StatusRequestEntityTooLarge)
		return
	}

	file, header, err := r.FormFile("image")
	if err != nil {
		http.Error(w, "Missing file parameter 'image'", http.StatusBadRequest)
		return
	}
	defer file.Close()

	filename := header.Filename
	if lastSlash := strings.LastIndex(filename, "/"); lastSlash != -1 {
		filename = filename[lastSlash+1:]
	}
	if lastSlash := strings.LastIndex(filename, "\\"); lastSlash != -1 {
		filename = filename[lastSlash+1:]
	}
	if filename == "" {
		filename = "image.png"
	}
	// Make every upload name unique so a stored photo never changes. That keeps
	// cached signed URLs and browser caches correct when a name is reused
	// (e.g. two different photos both called IMG_0001.jpg).
	filename = fmt.Sprintf("%d-%s", time.Now().UnixMilli(), filename)

	err = gcs.Upload(r.Context(), email, filename, file)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to upload image: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"filename": filename,
	})
}
