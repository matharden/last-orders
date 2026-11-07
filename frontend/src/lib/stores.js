import { writable, derived } from 'svelte/store';
import { resolveAbv, unitsFor, weeklyBuckets, topBreweries, topDrinks } from './units.js';

// ---- Theme ----
function initTheme() {
  const stored = localStorage.getItem('lo-theme');
  if (stored) return stored;
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

export const theme = writable(initTheme());
theme.subscribe(t => {
  localStorage.setItem('lo-theme', t);
  document.documentElement.setAttribute('data-theme', t);
});
document.documentElement.setAttribute('data-theme', initTheme());

// ---- Navigation ----
export const activeTab = writable('home');

// ---- Log sheet state ----
export const sheet = writable({
  open: false,
  id: null,       // null = create, number = edit
  drink: '',
  abv: null,
  size: 330,
  amount: 1,
  notes: '',
  date: new Date().toISOString().slice(0, 10),
});

// ---- Data ----
export const catalog = writable([]);
export const log = writable([]);
export const loading = writable(true);

// ---- Enriched log (adds abv + units + image to each entry) ----
export const enrichedLog = derived([log, catalog], ([$log, $catalog]) =>
  $log.map(e => {
    const match = $catalog.find(c => c.drink.toLowerCase() === e.drink.toLowerCase());
    return {
      ...e,
      abv: resolveAbv(e.drink, $catalog),
      units: unitsFor(e, $catalog),
      image: match ? match.image : ''
    };
  })
);

// ---- All-time ----
export const allTime = derived(enrichedLog, ($e) => ({
  units:  $e.reduce((s, x) => s + x.units, 0),
  drinks: $e.reduce((s, x) => s + x.amount, 0),
  days:   new Set($e.map(x => x.date)).size,
}));

// ---- Weekly buckets for bar chart ----
export const weeklyData = derived([log, catalog], ([$l, $c]) => weeklyBuckets($l, $c));

// ---- Top breweries / drinks ----
export const breweriesData = derived([log, catalog], ([$l, $c]) => topBreweries($l, $c));
export const drinksData    = derived(log, ($l) => topDrinks($l));

// ---- API helpers ----
export async function updateCatalogEntry(id, entry) {
  const res = await fetch(`/api/catalog/${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(entry),
  });
  if (res.ok) {
    const updated = await res.json().catch(() => null);
    if (updated) catalog.update(c => c.map(d => d.id === id ? updated : d));
  }
  return res.ok;
}

export async function fetchCatalog() {
  const res = await fetch('/api/catalog');
  if (res.ok) catalog.set((await res.json()) || []);
  return res.status;
}

export async function fetchLog() {
  const res = await fetch('/api/log');
  if (res.ok) log.set((await res.json()) || []);
  return res.status;
}

// Returns 401 if the user isn't signed in, otherwise the catalog status.
export async function refreshAll() {
  loading.set(true);
  try {
    const [catalogStatus, logStatus] = await Promise.all([fetchCatalog(), fetchLog()]);
    return logStatus === 401 ? 401 : catalogStatus;
  }
  finally { loading.set(false); }
}

// The server adds unknown drinks to the catalog (Booze sheet) when they're logged,
// so refresh the Cellar in the background if this drink isn't in it yet.
function refreshCatalogIfNew(drinkName) {
  const name = (drinkName || '').trim().toLowerCase();
  let known = false;
  catalog.update(c => { known = c.some(d => d.drink.trim().toLowerCase() === name); return c; });
  if (name && !known) fetchCatalog();
}

export async function addLogEntry(entry) {
  const res = await fetch('/api/log', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(entry),
  });
  if (res.ok) {
    // Optimistic: prepend
    const created = await res.json().catch(() => null);
    if (created) {
      log.update(l => [created, ...l]);
    } else {
      await fetchLog();
    }
    refreshCatalogIfNew(entry.drink);
  }
  return res.ok;
}

export async function updateLogEntry(id, entry) {
  const res = await fetch(`/api/log/${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(entry),
  });
  if (res.ok) {
    log.update(l => l.map(e => e.id === id ? { ...e, ...entry } : e));
    refreshCatalogIfNew(entry.drink);
  }
  return res.ok;
}

export async function deleteLogEntry(id) {
  const res = await fetch(`/api/log/${id}`, { method: 'DELETE' });
  if (res.ok) log.update(l => l.filter(e => e.id !== id));
  return res.ok;
}

export async function deleteCatalogEntry(id) {
  const res = await fetch(`/api/catalog/${id}`, { method: 'DELETE' });
  if (res.ok) catalog.update(c => c.filter(d => d.id !== id));
  return res.ok;
}
