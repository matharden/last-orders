import { writable, derived, get } from 'svelte/store';
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

// ---- App config (sheet link etc.), loaded when Tankard opens ----
export const config = writable(null);

export async function fetchConfig() {
  const res = await fetch('/api/config');
  if (res.ok) config.set(await res.json());
  return res.status;
}

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

// ---- Save errors ----
// Saves update the screen immediately and go to the server in the background.
// If the server rejects one, the change is rolled back and this message shown.
export const saveError = writable('');

function reportSaveError(what, err) {
  console.error(what, err);
  saveError.set(`Couldn't save ${what} — your change was undone. Please try again.`);
}

async function send(url, options) {
  const res = await fetch(url, options);
  if (!res.ok) throw new Error(`${res.status} ${await res.text().catch(() => '')}`.trim());
  return res;
}

const jsonOptions = (method, body) => ({
  method,
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(body),
});

// ---- API helpers ----
export async function updateCatalogEntry(id, entry) {
  let previous;
  catalog.update(c => c.map(d => {
    if (d.id !== id) return d;
    previous = d;
    // entry.image is a raw filename; the server replies with a signed URL for it.
    // Until then keep showing the current photo (or none, if it was removed).
    const image = entry.image === '' ? '' : d.image;
    return { ...d, ...entry, image };
  }));
  send(`/api/catalog/${id}`, jsonOptions('PUT', entry))
    .then(res => res.json().catch(() => null))
    .then(updated => { if (updated) catalog.update(c => c.map(d => d.id === id ? updated : d)); })
    .catch(err => {
      if (previous) catalog.update(c => c.map(d => d.id === id ? previous : d));
      reportSaveError('that drink', err);
    });
  return true;
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
  if (name && !get(catalog).some(d => d.drink.trim().toLowerCase() === name)) fetchCatalog();
}

// New entries get a temporary id until the server replies with the real one.
// Edits/deletes of an entry that's still being created wait for that id.
const pendingCreates = new Map(); // tempId -> Promise<realId | null>

async function resolveId(id) {
  return pendingCreates.has(id) ? pendingCreates.get(id) : id;
}

export async function addLogEntry(entry) {
  const tempId = `tmp-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
  log.update(l => [{ id: tempId, ...entry }, ...l]);

  const created = send('/api/log', jsonOptions('POST', entry))
    .then(res => res.json())
    .then(saved => {
      log.update(l => l.map(e => e.id === tempId ? { ...e, id: saved.id } : e));
      refreshCatalogIfNew(entry.drink);
      return saved.id;
    })
    .catch(err => {
      log.update(l => l.filter(e => e.id !== tempId));
      reportSaveError('that drink', err);
      return null;
    })
    .finally(() => pendingCreates.delete(tempId));
  pendingCreates.set(tempId, created);
  return true;
}

export async function updateLogEntry(id, entry) {
  let previous;
  log.update(l => l.map(e => {
    if (e.id !== id) return e;
    previous = e;
    return { ...e, ...entry };
  }));
  (async () => {
    const realId = await resolveId(id);
    if (realId == null) return; // the create failed and was already rolled back
    try {
      await send(`/api/log/${realId}`, jsonOptions('PUT', entry));
      refreshCatalogIfNew(entry.drink);
    } catch (err) {
      if (previous) log.update(l => l.map(e => (e.id === id || e.id === realId) ? { ...previous, id: realId } : e));
      reportSaveError('that change', err);
    }
  })();
  return true;
}

export async function deleteLogEntry(id) {
  let removed, index = -1;
  log.update(l => {
    index = l.findIndex(e => e.id === id);
    if (index === -1) return l;
    removed = l[index];
    return l.filter(e => e.id !== id);
  });
  (async () => {
    const realId = await resolveId(id);
    if (realId == null) return;
    try {
      await send(`/api/log/${realId}`, { method: 'DELETE' });
    } catch (err) {
      if (removed) log.update(l => { const c = [...l]; c.splice(Math.min(index, c.length), 0, { ...removed, id: realId }); return c; });
      reportSaveError('that delete', err);
    }
  })();
  return true;
}

export async function deleteCatalogEntry(id) {
  const res = await fetch(`/api/catalog/${id}`, { method: 'DELETE' });
  if (res.ok) catalog.update(c => c.filter(d => d.id !== id));
  return res.ok;
}
