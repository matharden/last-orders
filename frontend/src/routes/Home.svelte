<script>
  import { activeTab, thisWeek, enrichedLog, sheet } from '../lib/stores.js';
  import StatTile from '../lib/StatTile.svelte';
  import JournalRow from '../lib/JournalRow.svelte';
  import { weekRange } from '../lib/units.js';

  const TARGET_UNITS = 14;

  $: week = $thisWeek;
  $: pipsCount = Math.min(7, Math.round((week.units / TARGET_UNITS) * 7));
  $: recent = $enrichedLog.slice().sort((a, b) => b.date.localeCompare(a.date)).slice(0, 4);
  $: avgUnits = week.drinks > 0 ? (week.units / week.days || 0) : 0;

  const { mon, sun } = weekRange();
  const rangeLabel = `${new Date(mon+'T00:00').toLocaleDateString('en-GB',{day:'numeric',month:'short'})} – ${new Date(sun+'T00:00').toLocaleDateString('en-GB',{day:'numeric',month:'short'})}`;

  const today = new Date().toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
</script>

<div class="screen fade">
  <header>
    <div class="brand">
      <span class="eyebrow">THE TASTING JOURNAL</span>
      <h1 class="newsreader">Last orders</h1>
    </div>
    <span class="date-label mono">{today}</span>
  </header>

  <p class="eyebrow section-eye">THIS WEEK'S MEASURE</p>

  <div class="hero-card">
    <div class="deco-circle"></div>
    <span class="hero-label mono">UK UNITS · {rangeLabel}</span>
    <div class="hero-number newsreader">
      {week.units.toFixed(1)}<span class="hero-target"> / {TARGET_UNITS}</span>
    </div>
    <p class="hero-sub">{week.drinks} drinks across {week.days} evening{week.days !== 1 ? 's' : ''}…</p>
    <div class="pips">
      {#each Array(7) as _, i}
        <div class="pip" class:filled={i < pipsCount}></div>
      {/each}
    </div>
  </div>

  <div class="stat-grid">
    <StatTile value={week.drinks.toFixed(1)} label="Drinks" />
    <StatTile value={avgUnits.toFixed(1)} label="Avg units" />
    <StatTile value={week.dryDays} label="Dry days" />
  </div>

  <p class="eyebrow section-eye">LAST POURED</p>

  <div class="card log-card">
    {#each recent as entry, i}
      <JournalRow {entry} last={i === recent.length - 1} />
    {:else}
      <p class="empty mono">No entries yet — tap + to log.</p>
    {/each}
    {#if $enrichedLog.length > 4}
      <button class="more-btn mono" on:click={() => activeTab.set('history')}>
        Read the full journal →
      </button>
    {/if}
  </div>
</div>

<style>
.screen { padding: 20px 20px 100px; }
.fade { animation: settle .4s ease forwards; }
@keyframes settle { from { opacity: .85; transform: translateY(8px); } to { opacity: 1; transform: translateY(0); } }

header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 20px;
}
.brand { display: flex; flex-direction: column; gap: 2px; }
.brand h1 { font-size: 24px; font-weight: 600; color: var(--ink); line-height: 1; }
.date-label { font-size: 11px; color: var(--ink-3); padding-top: 6px; }
.section-eye { margin-bottom: 10px; }

.hero-card {
  position: relative;
  background: var(--card);
  border: 1px solid var(--card-edge);
  border-radius: 16px;
  padding: 18px 16px 16px;
  margin-bottom: 12px;
  box-shadow: var(--card-shadow);
  overflow: hidden;
}
.deco-circle {
  position: absolute;
  top: -40px;
  right: -40px;
  width: 130px;
  height: 130px;
  border-radius: 50%;
  border: 1.5px dashed var(--line);
  opacity: .5;
  pointer-events: none;
}
.hero-label { font-size: 10px; color: var(--ink-3); display: block; margin-bottom: 6px; }
.hero-number {
  font-size: 60px;
  font-weight: 500;
  color: var(--ink);
  line-height: 1;
  margin-bottom: 6px;
}
.hero-target { font-size: 28px; color: var(--amber); }
.hero-sub { font-size: 13.5px; color: var(--ink-2); margin-bottom: 14px; }
.pips { display: flex; gap: 6px; }
.pip {
  flex: 1;
  height: 8px;
  border-radius: 4px;
  background: var(--paper-2);
  box-shadow: inset 0 0 0 1px var(--line);
  transition: background .3s;
}
.pip.filled {
  background: linear-gradient(to right, var(--gold), var(--amber));
  box-shadow: 0 0 18px -3px rgba(224,146,47,.5);
}

.stat-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 10px;
  margin-bottom: 20px;
}

.card {
  background: var(--card);
  border: 1px solid var(--card-edge);
  border-radius: 14px;
  padding: 0 16px;
  box-shadow: var(--card-shadow);
}
.log-card { padding: 0 16px; }
.empty { font-size: 13px; color: var(--ink-3); padding: 16px 0; text-align: center; }
.more-btn {
  display: block;
  width: 100%;
  background: none;
  border: none;
  border-top: 1px solid var(--line);
  padding: 12px 0;
  text-align: center;
  font-size: 11px;
  font-weight: 600;
  letter-spacing: .14em;
  text-transform: uppercase;
  color: var(--amber);
  cursor: pointer;
}
</style>
