<script>
  import StatTile from '../lib/StatTile.svelte';
  import RankRow from '../lib/RankRow.svelte';
  import { allTime, weeklyData, breweriesData, drinksData } from '../lib/stores.js';
  import { fmtDate } from '../lib/units.js';

  $: maxWeekUnits = Math.max(1, ...$weeklyData.map(w => w.units));
  $: maxBrewery   = Math.max(1, ...$breweriesData.map(b => b.count));
  $: maxDrink     = Math.max(1, ...$drinksData.map(d => d.count));
</script>

<div class="screen fade">
  <p class="eyebrow section-eye">ALL TIME</p>
  <div class="card mb">
    <div class="stat-grid">
      <StatTile value={$allTime.units.toFixed(1)} label="Units" />
      <StatTile value={$allTime.drinks.toFixed(0)} label="Drinks" />
      <StatTile value={$allTime.days} label="Days out" />
    </div>
  </div>

  <p class="eyebrow section-eye">UNITS BY WEEK</p>
  <div class="card mb scroll">
    <div class="bar-chart">
      {#each $weeklyData.reverse() as w}
        {@const h = Math.max(4, Math.round((w.units / maxWeekUnits) * 150))}
        <div class="bar-col">
          <span class="bar-val newsreader">{w.units.toFixed(1)}</span>
          <div class="bar" style="height:{h}px"></div>
          <span class="bar-lbl mono">{fmtDate(w.label, {day:'numeric'})}</span>
        </div>
      {:else}
        <p class="empty mono">No data yet.</p>
      {/each}
    </div>
  </div>

  <p class="eyebrow section-eye">FAVOURITE BREWERIES</p>
  <div class="card mb rank-card">
    {#each $breweriesData as b, i}
      <RankRow index={i+1} name={b.name} count={b.count} max={maxBrewery} />
    {:else}
      <p class="empty mono">No data yet.</p>
    {/each}
  </div>

  <p class="eyebrow section-eye">MOST POURED</p>
  <div class="card mb rank-card">
    {#each $drinksData as d, i}
      <RankRow index={i+1} name={d.name} count={d.count} max={maxDrink} />
    {:else}
      <p class="empty mono">No data yet.</p>
    {/each}
  </div>
</div>

<style>
.screen { padding: 20px 20px 100px; }
.fade { animation: settle .4s ease forwards; }
@keyframes settle { from { opacity: .85; transform: translateY(8px); } to { opacity: 1; transform: translateY(0); } }
.section-eye { margin-bottom: 10px; }
.mb { margin-bottom: 20px; }

.card {
  background: var(--card);
  border: 1px solid var(--card-edge);
  border-radius: 14px;
  padding: 16px;
  box-shadow: var(--card-shadow);
}
.scroll {
  overflow-x: auto;
}
.stat-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 10px;
}

.bar-chart {
  display: flex;
  align-items: flex-end;
  gap: 6px;
  height: 200px;
  padding-bottom: 24px;
  position: relative;
}
.bar-col {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-end;
  gap: 4px;
  position: relative;
  height: 100%;
}
.bar-val {
  font-size: 12px;
  font-weight: 600;
  color: var(--ink);
  line-height: 1;
}
.bar {
  width: 100%;
  border-radius: 7px 7px 3px 3px;
  background: linear-gradient(to top, var(--amber), var(--gold));
  box-shadow: 0 0 18px -3px rgba(224,146,47,.5);
  min-height: 4px;
}
.bar-lbl {
  position: absolute;
  bottom: -20px;
  left: 0;
  right: 0;
  font-size: 9px;
  color: var(--ink-3);
  text-align: center;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.rank-card {
  overflow: hidden;
  padding: 4px 16px;
}
.empty { font-size: 13px; color: var(--ink-3); padding: 12px 0; }
</style>
