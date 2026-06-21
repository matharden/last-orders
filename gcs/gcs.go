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

	if _, err := io.Copy(w, r); err != nil {
		return fmt.Errorf("failed to copy data to GCS: %v", err)
	}

	if err := w.Close(); err != nil {
		return fmt.Errorf("failed to close GCS writer: %v", err)
	}

	return nil
}

// SignURL generates a temporary secure GET link for the user's image
func SignURL(email, filename string) (string, error) {
	if client == nil {
		return "", fmt.Errorf("GCS client not initialized")
	}

	userPrefix := GetUserPrefix(email)
	objectKey := fmt.Sprintf("users/%s/%s", userPrefix, filename)

	// If we have private key credentials, we can sign locally
	if saEmail != "" && len(saPrivKey) > 0 {
		url, err := storage.SignedURL(bucketName, objectKey, &storage.SignedURLOptions{
			GoogleAccessID: saEmail,
			PrivateKey:     saPrivKey,
			Method:         "GET",
			Expires:        time.Now().Add(15 * time.Minute),
			Scheme:         storage.SigningSchemeV4,
		})
		if err == nil {
			return url, nil
		}
	}

	// Fall back to signing with the client itself if credentials aren't loaded (like Cloud Run default SA)
	// Cloud Run default credentials can sign using signing options
	opts := &storage.SignedURLOptions{
		Method:  "GET",
		Expires: time.Now().Add(15 * time.Minute),
		Scheme:  storage.SigningSchemeV4,
	}
	if saEmail != "" {
		opts.GoogleAccessID = saEmail
	}

	url, err := client.Bucket(bucketName).SignedURL(objectKey, opts)
	if err != nil {
		log.Printf("GCS URL signing failed (using direct link fallback): %v", err)
		// If both fail, return a fallback direct link (which will only work if bucket is public)
		return fmt.Sprintf("https://storage.googleapis.com/%s/%s", bucketName, objectKey), nil
	}

	return url, nil
}
