package main

import (
	"fmt"
	"log"
	"os"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"boozer/sheets"
)

// sheetStore keeps an in-memory copy of each sheet range so reads don't hit the
// Sheets API every time, and writes update the copy instead of re-reading the
// whole sheet. The Google Sheet stays the source of truth:
//   - every write goes straight to the Sheet (write-through);
//   - the copy is refetched once it is older than the TTL, so edits made
//     directly in the Sheet show up within that time;
//   - before updating or deleting a row by position we re-check that row's ID
//     in the Sheet, so a row added/removed by hand can't cause the wrong row
//     to be overwritten.
type sheetStore struct {
	ttl time.Duration

	mu      sync.Mutex
	entries map[string]*cachedRange

	// writeMu serialises all writes so ID allocation and row positions can't race.
	writeMu sync.Mutex
}

type cachedRange struct {
	rows    [][]interface{}
	fetched time.Time
	loading chan struct{} // non-nil while a fetch is in flight
	err     error
}

const (
	catalogRange = "Booze!A:G"
	catalogSheet = "Booze"
	logSheet     = "Booze log"
)

var store = newSheetStore()

func newSheetStore() *sheetStore {
	ttl := 2 * time.Minute
	if v := os.Getenv("SHEET_CACHE_TTL"); v != "" {
		if d, err := time.ParseDuration(v); err == nil {
			ttl = d
		} else {
			log.Printf("Invalid SHEET_CACHE_TTL %q, using %s", v, ttl)
		}
	}
	return &sheetStore{ttl: ttl, entries: map[string]*cachedRange{}}
}

// fetchRange is swapped out in tests.
var fetchRange = sheets.ReadRange

// logRange is the configured range for the journal sheet.
func logRange() string {
	if r := os.Getenv("SHEET_READ_RANGE"); r != "" {
		return r
	}
	return logSheet + "!A:F"
}

// Rows returns the cached rows for a range, fetching them if missing or stale.
// Concurrent callers share one fetch. The returned slice must not be modified.
func (s *sheetStore) Rows(rangeName string) ([][]interface{}, error) {
	s.mu.Lock()
	e := s.entries[rangeName]
	if e == nil {
		e = &cachedRange{}
		s.entries[rangeName] = e
	}
	for {
		if e.loading == nil && e.rows != nil && time.Since(e.fetched) < s.ttl {
			rows := e.rows
			s.mu.Unlock()
			return rows, nil
		}
		if e.loading == nil {
			break
		}
		wait := e.loading
		s.mu.Unlock()
		<-wait
		s.mu.Lock()
		if e.err != nil {
			err := e.err
			s.mu.Unlock()
			return nil, err
		}
	}
	e.loading = make(chan struct{})
	s.mu.Unlock()

	rows, err := fetchRange(rangeName)

	s.mu.Lock()
	if err == nil {
		if rows == nil {
			rows = [][]interface{}{}
		}
		e.rows, e.fetched = rows, time.Now()
	}
	e.err = err
	close(e.loading)
	e.loading = nil
	s.mu.Unlock()
	return rows, err
}

// Invalidate drops a range so the next read refetches it.
func (s *sheetStore) Invalidate(rangeName string) {
	s.mu.Lock()
	if e := s.entries[rangeName]; e != nil && e.loading == nil {
		e.rows = nil
	}
	s.mu.Unlock()
}

// mutate applies fn to a copy of the cached rows (copy-on-write, so readers
// holding the old slice are unaffected). No-op if the range isn't cached.
func (s *sheetStore) mutate(rangeName string, fn func([][]interface{}) [][]interface{}) {
	s.mu.Lock()
	defer s.mu.Unlock()
	e := s.entries[rangeName]
	if e == nil || e.rows == nil || e.loading != nil {
		return
	}
	rows := make([][]interface{}, len(e.rows))
	copy(rows, e.rows)
	e.rows = fn(rows)
}

var updatedRowRe = regexp.MustCompile(`![A-Z]+(\d+)`)

// Append writes a row to the end of the range and records it in the cache at
// the exact row the Sheets API reports it landed on.
func (s *sheetStore) Append(rangeName string, values []interface{}) error {
	updated, err := sheets.WriteRange(rangeName, values)
	if err != nil {
		return err
	}
	m := updatedRowRe.FindStringSubmatch(updated)
	if m == nil {
		s.Invalidate(rangeName)
		return nil
	}
	rowNum, _ := strconv.Atoi(m[1])
	s.mutate(rangeName, func(rows [][]interface{}) [][]interface{} {
		for len(rows) < rowNum-1 {
			rows = append(rows, []interface{}{})
		}
		if len(rows) >= rowNum {
			rows[rowNum-1] = values
		} else {
			rows = append(rows, values)
		}
		return rows
	})
	return nil
}

// verifyRow checks that the Sheet row at index i (0-based) still holds id in
// column A. If it doesn't (the Sheet was edited by hand), the cache is
// refreshed and the row is looked up again. Returns the confirmed index or -1.
func (s *sheetStore) verifyRow(sheetName, rangeName string, i int, id string, find func([][]interface{}) int) (int, error) {
	cell, err := sheets.ReadRange(fmt.Sprintf("%s!A%d", sheetName, i+1))
	if err == nil && len(cell) > 0 && len(cell[0]) > 0 &&
		strings.TrimSpace(fmt.Sprintf("%v", cell[0][0])) == id {
		return i, nil
	}
	s.Invalidate(rangeName)
	rows, err := s.Rows(rangeName)
	if err != nil {
		return -1, err
	}
	return find(rows), nil
}

// UpdateRow overwrites the row at index i (0-based) and updates the cache.
func (s *sheetStore) UpdateRow(sheetName, rangeName, lastCol string, i int, values []interface{}) error {
	r := fmt.Sprintf("%s!A%d:%s%d", sheetName, i+1, lastCol, i+1)
	if err := sheets.UpdateRange(r, values); err != nil {
		return err
	}
	s.mutate(rangeName, func(rows [][]interface{}) [][]interface{} {
		if i < len(rows) {
			rows[i] = values
		}
		return rows
	})
	return nil
}

// DeleteRow removes the row at index i (0-based) and updates the cache.
func (s *sheetStore) DeleteRow(sheetName, rangeName string, i int) error {
	if err := sheets.DeleteRow(sheetName, i); err != nil {
		return err
	}
	s.mutate(rangeName, func(rows [][]interface{}) [][]interface{} {
		if i < len(rows) {
			rows = append(rows[:i], rows[i+1:]...)
		}
		return rows
	})
	return nil
}

// cellString returns column c of a row as a trimmed string ("" if missing).
func cellString(row []interface{}, c int) string {
	if c >= len(row) {
		return ""
	}
	return strings.TrimSpace(fmt.Sprintf("%v", row[c]))
}

// findRowByID returns the index of the first row whose column A equals id, or -1.
func findRowByID(rows [][]interface{}, id string) int {
	for i, row := range rows {
		if cellString(row, 0) == id {
			return i
		}
	}
	return -1
}

// maxNumericID returns the highest integer in column A.
func maxNumericID(rows [][]interface{}) int {
	maxID := 0
	for _, row := range rows {
		if len(row) > 0 {
			if id := parseInt(row[0]); id > maxID {
				maxID = id
			}
		}
	}
	return maxID
}
