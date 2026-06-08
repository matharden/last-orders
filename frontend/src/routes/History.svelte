<script>
  import JournalRow from '../lib/JournalRow.svelte';
  import { enrichedLog, sheet } from '../lib/stores.js';
  import { fmtDate, fmtWeekday } from '../lib/units.js';

  function openEdit(entry) {
    sheet.set({
      open: true,
      id: entry.id,
      drink: entry.drink,
      abv: entry.abv,
      size: entry.size || 500,
      amount: entry.amount || 1,
      notes: entry.notes || '',
      date: entry.date,
    });
  }

  $: groups = (() => {
    const map = {};
    $enrichedLog.slice().sort((a, b) => b.date.localeCompare(a.date)).forEach(e => {
      (map[e.date] = map[e.date] || []).push(e);
    });
    return Object.entries(map).sort(([a], [b]) => b.localeCompare(a));
  })();
</script>

<div class="screen fade">
  <p class="eyebrow section-eye">THE JOURNAL</p>

  {#each groups as [date, entries]}
    {@const dayUnits = entries.reduce((s, e) => s + e.units, 0)}
    <div class="day-group">
      <div class="day-header">
        <span class="day-name newsreader">{fmtDate(date, { day:'numeric', month:'long' })}</span>
        <span class="day-wd mono">{fmtWeekday(date)}</span>
        <span class="day-units">{dayUnits.toFixed(1)} units</span>
      </div>
      <div class="rule"></div>
      <div class="card">
        {#each entries as entry, i}
          <JournalRow {entry} last={i === entries.length - 1} clickable on:click={() => openEdit(entry)} />
        {/each}
      </div>
    </div>
  {:else}
    <p class="empty mono">No entries yet. Tap + to log your first drink.</p>
  {/each}
</div>

<style>
.screen { padding: 20px 20px 100px; }
.fade { animation: settle .4s ease forwards; }
@keyframes settle { from { opacity: .85; transform: translateY(8px); } to { opacity: 1; transform: translateY(0); } }
.section-eye { margin-bottom: 16px; }

.day-group { margin-bottom: 22px; }

.day-header {
  display: flex;
  align-items: baseline;
  gap: 8px;
  margin-bottom: 8px;
}
.day-name { font-size: 19px; font-weight: 600; color: var(--ink); }
.day-wd {
  font-size: 10px;
  font-weight: 500;
  letter-spacing: .14em;
  text-transform: uppercase;
  color: var(--ink-3);
}
.day-units {
  margin-left: auto;
  font-size: 13px;
  color: var(--amber);
  font-weight: 500;
}

.rule {
  height: 1px;
  background: repeating-linear-gradient(to right, var(--line) 0, var(--line) 5px, transparent 5px, transparent 10px);
  margin-bottom: 8px;
}

.card {
  background: var(--card);
  border: 1px solid var(--card-edge);
  border-radius: 14px;
  padding: 0 16px;
  box-shadow: var(--card-shadow);
}

.empty { font-size: 13px; color: var(--ink-3); padding: 20px 0; text-align: center; }
</style>
