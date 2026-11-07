package main

import (
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

func TestStoreCachesAndSharesFetches(t *testing.T) {
	var calls int32
	old := fetchRange
	fetchRange = func(string) ([][]interface{}, error) {
		atomic.AddInt32(&calls, 1)
		time.Sleep(20 * time.Millisecond)
		return [][]interface{}{{"ID"}, {"1", "1 Jan", "Stout"}}, nil
	}
	t.Cleanup(func() { fetchRange = old })

	s := &sheetStore{ttl: time.Minute, entries: map[string]*cachedRange{}}
	var wg sync.WaitGroup
	for i := 0; i < 10; i++ {
		wg.Add(1)
		go func() { defer wg.Done(); s.Rows("r") }()
	}
	wg.Wait()
	s.Rows("r")
	if calls != 1 {
		t.Fatalf("expected 1 fetch, got %d", calls)
	}

	// Copy-on-write mutation leaves earlier readers' slices alone.
	before, _ := s.Rows("r")
	s.mutate("r", func(rows [][]interface{}) [][]interface{} { return append(rows[:1], rows[2:]...) })
	after, _ := s.Rows("r")
	if len(before) != 2 || len(after) != 1 {
		t.Fatalf("mutate: before %d after %d", len(before), len(after))
	}

	s.Invalidate("r")
	s.Rows("r")
	if calls != 2 {
		t.Fatalf("expected refetch after invalidate, got %d", calls)
	}

	s.ttl = 0
	s.Rows("r")
	if calls != 3 {
		t.Fatalf("expected refetch after TTL, got %d", calls)
	}
}

func TestRowHelpers(t *testing.T) {
	rows := [][]interface{}{{"ID"}, {"3"}, {}, {"12", "x"}, {"ec10de62"}}
	if maxNumericID(rows) != 12 {
		t.Errorf("maxNumericID = %d", maxNumericID(rows))
	}
	if findRowByID(rows, "ec10de62") != 4 || findRowByID(rows, "99") != -1 {
		t.Errorf("findRowByID wrong")
	}
	m := updatedRowRe.FindStringSubmatch("'Booze log'!A377:F377")
	if m == nil || m[1] != "377" {
		t.Errorf("updatedRowRe: %v", m)
	}
}
