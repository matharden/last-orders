package gcs

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"
	"strings"
	"sync"
	"time"

	"cloud.google.com/go/compute/metadata"
	"cloud.google.com/go/storage"
	"google.golang.org/api/option"
)

var (
	client     *storage.Client
	bucketName string
	saEmail    string
	saPrivKey  []byte
)

// Init initializes the GCS client and parses credentials for signing URLs
func Init() error {
	bucketName = os.Getenv("GCS_BUCKET_NAME")
	if bucketName == "" {
		// Use a default based on the project ID if not specified
		bucketName = "boozer-466511-uploads"
	}

	ctx := context.Background()
	credFile := os.Getenv("GOOGLE_APPLICATION_CREDENTIALS")

	var opts []option.ClientOption
	if credFile != "" {
		opts = append(opts, option.WithCredentialsFile(credFile))

		// Parse the credentials file for URL signing parameters
		data, err := os.ReadFile(credFile)
		if err == nil {
			var key struct {
				ClientEmail string `json:"client_email"`
				PrivateKey  string `json:"private_key"`
			}
			if err := json.Unmarshal(data, &key); err == nil {
				saEmail = key.ClientEmail
				saPrivKey = []byte(key.PrivateKey)
			}
		}
	}

	var err error
	client, err = storage.NewClient(ctx, opts...)
	if err != nil {
		return fmt.Errorf("unable to initialize storage client: %v", err)
	}

	// Try to get service account email from metadata server if not loaded from file
	if saEmail == "" && metadata.OnGCE() {
		email, err := metadata.Email("default")
		if err == nil {
			saEmail = email
			log.Printf("Loaded GCS Service Account email from GCE metadata: %s", saEmail)
		} else {
			log.Printf("Failed to get default service account email from metadata: %v", err)
		}
	}

	return nil
}

// GetUserPrefix returns the sha256 hash of the email as a folder prefix
func GetUserPrefix(email string) string {
	email = strings.ToLower(strings.TrimSpace(email))
	hash := sha256.Sum256([]byte(email))
	return fmt.Sprintf("%x", hash)
}

// Upload uploads a file to GCS under the user's compartmentalized path
func Upload(ctx context.Context, email, filename string, r io.Reader) error {
	if client == nil {
		return fmt.Errorf("GCS client not initialized")
	}

	userPrefix := GetUserPrefix(email)
	objectKey := fmt.Sprintf("users/%s/%s", userPrefix, filename)

	obj := client.Bucket(bucketName).Object(objectKey)
	w := obj.NewWriter(ctx)
	// Upload names are unique (see main.go), so an object never changes and
	// browsers can cache it for as long as they like.
	w.CacheControl = "private, max-age=31536000, immutable"

	if _, err := io.Copy(w, r); err != nil {
		return fmt.Errorf("failed to copy data to GCS: %v", err)
	}

	if err := w.Close(); err != nil {
		return fmt.Errorf("failed to close GCS writer: %v", err)
	}

	return nil
}

// Signed URLs last close to the V4 maximum of 7 days and are reused until they
// have less than a day left. Reusing the same URL means browsers and iOS can
// serve the photo from their HTTP cache, and on Cloud Run (no local key) it
// avoids an IAM signBlob network call per photo on every catalog load.
const (
	signedURLLifetime = 7*24*time.Hour - time.Hour
	signedURLMinLeft  = 24 * time.Hour
	maxParallelSigns  = 8
)

type cachedURL struct {
	url     string
	expires time.Time
}

var (
	urlCacheMu sync.Mutex
	urlCache   = map[string]cachedURL{}
)

// SignURL returns a signed GET link for the user's image, from cache when possible.
func SignURL(email, filename string) (string, error) {
	if client == nil {
		return "", fmt.Errorf("GCS client not initialized")
	}

	objectKey := fmt.Sprintf("users/%s/%s", GetUserPrefix(email), filename)

	urlCacheMu.Lock()
	c, ok := urlCache[objectKey]
	urlCacheMu.Unlock()
	if ok && time.Until(c.expires) > signedURLMinLeft {
		return c.url, nil
	}

	expires := time.Now().Add(signedURLLifetime)
	url, signed := signObject(objectKey, expires)
	if signed {
		urlCacheMu.Lock()
		urlCache[objectKey] = cachedURL{url: url, expires: expires}
		urlCacheMu.Unlock()
	}
	return url, nil
}

// SignURLs signs many filenames at once, in parallel, returning filename -> URL.
func SignURLs(email string, filenames []string) map[string]string {
	result := make(map[string]string, len(filenames))
	var mu sync.Mutex
	var wg sync.WaitGroup
	sem := make(chan struct{}, maxParallelSigns)
	seen := map[string]bool{}
	for _, f := range filenames {
		if f == "" || seen[f] {
			continue
		}
		seen[f] = true
		wg.Add(1)
		sem <- struct{}{}
		go func(f string) {
			defer wg.Done()
			defer func() { <-sem }()
			if url, err := SignURL(email, f); err == nil {
				mu.Lock()
				result[f] = url
				mu.Unlock()
			}
		}(f)
	}
	wg.Wait()
	return result
}

// signObject signs a GET URL for objectKey. signed is false when signing failed
// and a direct (public-bucket) link was returned instead; that isn't cached.
func signObject(objectKey string, expires time.Time) (url string, signed bool) {
	// If we have private key credentials, we can sign locally
	if saEmail != "" && len(saPrivKey) > 0 {
		url, err := storage.SignedURL(bucketName, objectKey, &storage.SignedURLOptions{
			GoogleAccessID: saEmail,
			PrivateKey:     saPrivKey,
			Method:         "GET",
			Expires:        expires,
			Scheme:         storage.SigningSchemeV4,
		})
		if err == nil {
			return url, true
		}
	}

	// Fall back to signing with the client itself if credentials aren't loaded
	// (e.g. Cloud Run's service account, which signs via the IAM signBlob API).
	opts := &storage.SignedURLOptions{
		Method:  "GET",
		Expires: expires,
		Scheme:  storage.SigningSchemeV4,
	}
	if saEmail != "" {
		opts.GoogleAccessID = saEmail
	}

	url, err := client.Bucket(bucketName).SignedURL(objectKey, opts)
	if err != nil {
		log.Printf("GCS URL signing failed (using direct link fallback): %v", err)
		// If both fail, return a fallback direct link (which will only work if bucket is public)
		return fmt.Sprintf("https://storage.googleapis.com/%s/%s", bucketName, objectKey), false
	}

	return url, true
}
