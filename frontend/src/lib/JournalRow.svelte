<script>
  import { theme } from './stores.js';
  import { labelColor, drinkInitials, fmtDate, SIZE_LABELS } from './units.js';

  export let entry;        // enriched LogEntry (has .units, .abv)
  export let last = false;
</script>

<div class="row" class:last>
  <div class="mat" style="background:{labelColor(entry.drink, $theme)}">
    <span class="initials newsreader">{drinkInitials(entry.drink)}</span>
  </div>
  <div class="mid">
    <span class="drink newsreader">{entry.drink}</span>
    <span class="meta mono">{entry.amount} &times; {SIZE_LABELS[entry.size] ?? entry.size+'ml'} · {entry.abv ?? '?'}%</span>
  </div>
  <div class="right">
    <span class="units-val newsreader">{entry.units.toFixed(1)}</span>
    <span class="units-lbl mono">UNITS</span>
  </div>
</div>

<style>
.row {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 0;
  border-bottom: 1px solid var(--line);
}
.row.last { border-bottom: none; }

.mat {
  width: 46px;
  height: 46px;
  border-radius: 50%;
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 0 0 3px var(--card), 0 0 0 4px var(--card-edge);
}
.initials {
  color: #fff;
  font-size: 16px;
  font-weight: 500;
  line-height: 1;
}
.mid {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 3px;
}
.drink {
  font-size: 17px;
  font-weight: 500;
  color: var(--ink);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.meta {
  font-size: 12px;
  color: var(--ink-2);
}
.right {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  flex-shrink: 0;
}
.units-val {
  font-size: 19px;
  font-weight: 600;
  color: var(--ink);
  line-height: 1;
}
.units-lbl {
  font-size: 9px;
  color: var(--ink-3);
  letter-spacing: .12em;
}
</style>
