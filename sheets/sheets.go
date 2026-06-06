package sheets

import (
	"context"
	"fmt"
	"os"

	"google.golang.org/api/option"
	"google.golang.org/api/sheets/v4"
)

var svc *sheets.Service
var spreadsheetId string
var readRange string
var writeRange string

// Init initializes the Google Sheets API client using application default credentials
// (or the GOOGLE_APPLICATION_CREDENTIALS environment variable which points to a service account JSON key).
func Init() error {
	spreadsheetId = os.Getenv("SPREADSHEET_ID")
	readRange = os.Getenv("SHEET_READ_RANGE")
	writeRange = os.Getenv("SHEET_WRITE_RANGE")

	ctx := context.Background()
	
	// Ensure that the credentials file is specified.
	// We'll use option.WithCredentialsFile if provided, otherwise default to Application Default Credentials.
	credFile := os.Getenv("GOOGLE_APPLICATION_CREDENTIALS")
	var opts []option.ClientOption
	if credFile != "" {
		opts = append(opts, option.WithCredentialsFile(credFile))
	}

	var err error
	svc, err = sheets.NewService(ctx, opts...)
	if err != nil {
		return fmt.Errorf("unable to retrieve Sheets client: %v", err)
	}

	if spreadsheetId == "" {
		return fmt.Errorf("SPREADSHEET_ID environment variable is not set")
	}

	return nil
}

// ReadRange fetches data from a specific range in the spreadsheet
func ReadRange(rangeName string) ([][]interface{}, error) {
	if svc == nil {
		return nil, fmt.Errorf("sheets service not initialized")
	}

	resp, err := svc.Spreadsheets.Values.Get(spreadsheetId, rangeName).Do()
	if err != nil {
		return nil, fmt.Errorf("unable to retrieve data from range %s: %v", rangeName, err)
	}

	return resp.Values, nil
}

// WriteRange appends a row of data to a specific range in the spreadsheet
func WriteRange(rangeName string, values []interface{}) error {
	if svc == nil {
		return fmt.Errorf("sheets service not initialized")
	}

	valueRange := &sheets.ValueRange{
		Values: [][]interface{}{values},
	}

	_, err := svc.Spreadsheets.Values.Append(spreadsheetId, rangeName, valueRange).ValueInputOption("USER_ENTERED").Do()
	if err != nil {
		return fmt.Errorf("unable to append data to range %s: %v", rangeName, err)
	}

	return nil
}

// ReadData fetches data from the default spreadsheet range
func ReadData() ([][]interface{}, error) {
	return ReadRange(readRange)
}

// WriteData appends a row of data to the default spreadsheet range
func WriteData(values []interface{}) error {
	return WriteRange(writeRange, values)
}
