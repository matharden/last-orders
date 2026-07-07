export const SIZE_LABELS = { 100: 'Shot', 330: 'Small', 400: 'Medium', 500: 'Large', 568: 'Pint' };

const ABV_OVERRIDES = {
  'Side Pocket': 4.4, 'Ale': 4.5, 'Peroni Capri': 4.2, 'Camden Ale': 4.0,
  'Badger Master Stoat': 5.0, 'Badger Cranbourne Poacher': 5.6,
  'Badger Thirsty Ferret': 4.4, 'Moth: Old Fashioned': 28, 'Tribute': 4.2,
  'Neck Oil': 4.3, 'Hazy Jane': 5.0, 'Doombar': 4.3, 'London Pride': 4.7,
};

export function resolveAbv(drinkName, catalog = []) {
  const hit = catalog.find(c =>
    c.drink.toLowerCase() === drinkName.toLowerCase() ||
    drinkName.toLowerCase().includes(c.drink.toLowerCase())
  );
  if (hit) return hit.abv;
  if (ABV_OVERRIDES[drinkName] != null) return ABV_OVERRIDES[drinkName];
  return 4.5;
}

export function unitsFor(entry, catalog = []) {
  const abv = resolveAbv(entry.drink, catalog);
  return (abv * entry.size * entry.amount) / 1000;
}

export function labelColor(name, theme) {
  let h = 0;
  for (let i = 0; i < name.length; i++) h = (h * 31 + name.charCodeAt(i)) % 360;
  const hue = (h % 40) + 22;
  return theme === 'dark' ? `hsl(${hue},66%,46%)` : `hsl(${hue},70%,38%)`;
}

export function drinkInitials(name) {
  const words = name.trim().split(/\s+/);
  if (words.length === 1) return words[0].slice(0, 2).toUpperCase();
  return (words[0][0] + words[1][0]).toUpperCase();
}

export function fmtDate(iso, opts) {
  const d = new Date(iso + 'T00:00:00');
  return d.toLocaleDateString('en-GB', opts || { day: 'numeric', month: 'short' });
}

export function fmtWeekday(iso) {
  return new Date(iso + 'T00:00:00').toLocaleDateString('en-GB', { weekday: 'short' }).toUpperCase();
}

export function weekMonday(dateStr) {
  const d = new Date(dateStr + 'T00:00:00Z');
  const day = (d.getUTCDay() + 6) % 7;
  const mon = new Date(d);
  mon.setUTCDate(d.getUTCDate() - day);
  return mon.toISOString().slice(0, 10);
}

export function thisWeekEntries(log, offset = 0) {
  const { mon, sun } = weekRange(offset);
  return log.filter(e => e.date >= mon && e.date <= sun);
}

export function weekRange(offset = 0) {
  const d = new Date(weekMonday(new Date().toISOString().slice(0, 10)) + 'T00:00:00Z');
  d.setUTCDate(d.getUTCDate() + offset * 7);
  const mon = d.toISOString().slice(0, 10);
  d.setUTCDate(d.getUTCDate() + 6);
  return { mon, sun: d.toISOString().slice(0, 10) };
}

export function weeklyBuckets(log, catalog) {
  const weeks = {};
  log.forEach(e => {
    const key = weekMonday(e.date);
    if (!weeks[key]) weeks[key] = { label: key, units: 0, drinks: 0 };
    weeks[key].units += unitsFor(e, catalog);
    weeks[key].drinks += e.amount;
  });
  return Object.values(weeks).sort((a, b) => a.label.localeCompare(b.label));
}

export function topBreweries(log, catalog) {
  const map = {};
  log.forEach(e => {
    const cat = catalog.find(c => e.drink.toLowerCase().includes(c.drink.toLowerCase()));
    let brewery = cat ? cat.brewery : null;
    if (!brewery) {
      if (/badger/i.test(e.drink)) brewery = 'Badger';
      else if (/camden/i.test(e.drink)) brewery = 'Camden Town Brewery';
      else if (/neck oil/i.test(e.drink)) brewery = 'Beavertown';
      else if (/hazy jane/i.test(e.drink)) brewery = 'Brewdog';
      else if (/london pride/i.test(e.drink)) brewery = 'Fullers';
      else if (/doombar/i.test(e.drink)) brewery = 'Sharps';
      else if (/peroni/i.test(e.drink)) brewery = 'Peroni';
      else if (/tribute/i.test(e.drink)) brewery = 'St Austell';
      else if (/moth/i.test(e.drink)) brewery = 'Moth';
      else brewery = 'Other';
    }
    map[brewery] = (map[brewery] || 0) + e.amount;
  });
  return Object.entries(map).map(([name, count]) => ({ name, count }))
    .sort((a, b) => b.count - a.count);
}

export function topDrinks(log) {
  const map = {};
  log.forEach(e => { map[e.drink] = (map[e.drink] || 0) + e.amount; });
  return Object.entries(map).map(([name, count]) => ({ name, count }))
    .sort((a, b) => b.count - a.count);
}
