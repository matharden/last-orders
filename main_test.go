package main

import (
	"testing"
)

func TestParseRowsToLogEntries(t *testing.T) {
	// Construct simulated rows from the spreadsheet
	// Column 0: ID, Column 1: Drank on, Column 2: Drink
	rows := [][]interface{}{
		{"ID", "Drank on", "Drink"},
		{"1", "18 Oct", "Side Pocket"},
		{"77", "31 Dec", "Stonewall IPA"},
		{"78", "1 Jan", "Guinness"},
		{"135", "1 Jun", "Gold Beer"},
		{"150", "4 Jul", "Cruzcampo"},
		{"262", "30 Dec", "Satellite"},
		{"263", "1 Jan", "Draught Stout"},
		{"374", "6 Jun", "Draught Stout"},
		{"375", "5 Jun", "Stella Artois"},
	}

	// Since current system year is 2026, working backwards:
	// last entries (Row 375, 374) are in 2026.
	// row 263 (1 Jan) is in 2026.
	// row 262 (30 Dec) is Dec 2025 (year wrapped).
	// row 150 (4 Jul) is Jul 2025.
	// row 135 (1 Jun) is Jun 2025.
	// row 78 (1 Jan) is Jan 2025.
	// row 77 (31 Dec) is Dec 2024 (year wrapped).
	// row 1 (18 Oct) is Oct 2024.

	expectedDates := map[string]string{
		"1":   "2024-10-18",
		"77":  "2024-12-31",
		"78":  "2025-01-01",
		"135": "2025-06-01",
		"150": "2025-07-04",
		"262": "2025-12-30",
		"263": "2026-01-01",
		"374": "2026-06-06",
		"375": "2026-06-05",
	}

	results := parseRowsToLogEntries(rows, 1)

	for _, entry := range results {
		expDate, exists := expectedDates[entry.ID]
		if !exists {
			t.Errorf("Unexpected entry ID: %s", entry.ID)
			continue
		}
		if entry.Date != expDate {
			t.Errorf("Entry ID %s: got Date %q, want %q", entry.ID, entry.Date, expDate)
		}
	}

	// Verify that hex IDs are kept as strings
	hexRows := [][]interface{}{
		{"ec10de62", "25 Apr", "Level Head"},
	}
	hexResults := parseRowsToLogEntries(hexRows, 0)
	if len(hexResults) != 1 {
		t.Fatalf("Expected 1 result for hex row, got %d", len(hexResults))
	}
	if hexResults[0].ID != "ec10de62" {
		t.Errorf("Expected ID %q, got %q", "ec10de62", hexResults[0].ID)
	}
}

func TestParseDateToISO(t *testing.T) {
	// Keep existing parser test if still relevant
	got := parseDateToISO("2006-01-02")
	if got != "2006-01-02" {
		t.Errorf("parseDateToISO(\"2006-01-02\") = %q, want \"2006-01-02\"", got)
	}
}
