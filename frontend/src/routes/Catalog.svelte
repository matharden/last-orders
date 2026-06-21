<script>
  import { catalog, sheet, theme } from '../lib/stores.js';
  import { labelColor } from '../lib/units.js';
  import DrinkEditSheet from '../lib/DrinkEditSheet.svelte';

  let query = '';
  let editingDrink = null;

  $: filtered = $catalog.filter(c => {
    if (!query) return true;
    const q = query.toLowerCase();
    return c.drink.toLowerCase().includes(q)
        || c.brewery.toLowerCase().includes(q)
        || (c.style || '').toLowerCase().includes(q);
  });

  function openEdit(drink) { editingDrink = drink; }

  function quickLog(drink, e) {
    e.stopPropagation();
    sheet.update(s => ({ ...s, open: true, drink: drink.drink, abv: drink.abv, size: 568, amount: 1 }));
  }

  function starRating(r) {
    const filled = r || 0;
    return '★'.repeat(filled) + '☆'.repeat(5 - filled);
  }
</script>

<div class="screen fade">
  <p class="eyebrow section-eye">THE CELLAR · {$catalog.length} beers</p>

  <div class="search-wrap">
    <svg class="search-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round">
      <circle cx="11" cy="11" r="8"/><path d="M21 21l-4.35-4.35"/>
    </svg>
    <input class="search-input" type="search" placeholder="Search beers, brewery, style…" bind:value={query} />
  </div>

  <div class="card">
    {#each filtered as drink, i}
      <div class="beer-row" role="button" tabindex="0"
           on:click={() => openEdit(drink)}
           on:keydown={e => e.key === 'Enter' && openEdit(drink)}>
        <button class="label-art" style="background:{drink.image ? `url(${drink.image}) center/cover no-repeat` : labelColor(drink.drink, $theme)}"
                title="Quick-log {drink.drink}"
                on:click={e => quickLog(drink, e)}>
          {#if !drink.image}
            <div class="label-strap">
              <span class="label-name mono">{drink.drink.toUpperCase()}</span>
            </div>
          {/if}
          <span class="log-hint mono">+ log</span>
        </button>
        <div class="mid">
          <span class="brewery mono">{drink.brewery.toUpperCase()}</span>
          <span class="drink-name newsreader">{drink.drink}</span>
          <span class="style-abv">{drink.abv ? drink.abv + '%' : ''}</span>
        </div>
        <div class="rating">
          {#if drink.rating}
            <span class="stars">{starRating(drink.rating)}</span>
          {:else}
            <span class="unrated mono">· · ·</span>
          {/if}
        </div>
      </div>
      {#if i < filtered.length - 1}
        <div class="divider"></div>
      {/if}
    {:else}
      <p class="empty mono">No beers found.</p>
    {/each}
  </div>
</div>

<DrinkEditSheet drink={editingDrink} on:close={() => editingDrink = null} />

<style>
.screen { padding: 20px 20px 100px; }
.fade { animation: settle .4s ease forwards; }
@keyframes settle { from { opacity: .85; transform: translateY(8px); } to { opacity: 1; transform: translateY(0); } }
.section-eye { margin-bottom: 12px; }

.search-wrap {
  position: relative;
  margin-bottom: 12px;
}
.search-icon {
  position: absolute;
  left: 12px;
  top: 50%;
  transform: translateY(-50%);
  width: 18px;
  height: 18px;
  color: var(--ink-3);
  pointer-events: none;
}
.search-input {
  width: 100%;
  background: var(--card);
  border: 1px solid var(--card-edge);
  border-radius: 12px;
  padding: 11px 12px 11px 38px;
  font-family: 'Hanken Grotesk', sans-serif;
  font-size: 1rem;
  color: var(--ink);
  outline: none;
  box-shadow: var(--card-shadow);
}
.search-input:focus { border-color: var(--amber); }

.card {
  background: var(--card);
  border: 1px solid var(--card-edge);
  border-radius: 14px;
  overflow: hidden;
  box-shadow: var(--card-shadow);
}

.beer-row {
  width: 100%;
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 16px;
  cursor: pointer;
  text-align: left;
  transition: background .12s;
}
.beer-row:hover { background: var(--paper-2); }

.label-art {
  width: 50px;
  height: 64px;
  border-radius: 7px;
  flex-shrink: 0;
  position: relative;
  overflow: hidden;
  display: flex;
  align-items: center;
  justify-content: center;
  border: none;
  padding: 0;
  cursor: pointer;
}
.label-art:hover .log-hint { opacity: 1; }
.log-hint {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(0,0,0,.45);
  color: #fff;
  font-size: 9px;
  font-weight: 600;
  letter-spacing: .1em;
  opacity: 0;
  transition: opacity .15s;
}
.label-strap {
  position: absolute;
  left: 0; right: 0;
  top: 50%;
  transform: translateY(-50%);
  background: rgba(255,255,255,.25);
  padding: 3px 2px;
  display: flex;
  align-items: center;
  justify-content: center;
}
.label-name {
  font-size: 7.5px;
  font-weight: 500;
  color: #fff;
  text-overflow: ellipsis;
  overflow: hidden;
  white-space: nowrap;
  max-width: 44px;
}

.mid {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.brewery {
  font-size: 10px;
  font-weight: 500;
  letter-spacing: .1em;
  color: var(--ink-3);
}
.drink-name {
  font-size: 17px;
  font-weight: 500;
  color: var(--ink);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.style-abv {
  font-size: 13px;
  font-weight: 600;
  color: var(--amber);
}

.rating { flex-shrink: 0; }
.stars { font-size: 14px; color: var(--gold); letter-spacing: 1px; }
.unrated { font-size: 14px; color: var(--ink-3); letter-spacing: 4px; }

.divider { height: 1px; background: var(--line); margin: 0 16px; }
.empty { font-size: 13px; color: var(--ink-3); padding: 16px; }
</style>
