<script>
  import { sheet, catalog, addLogEntry, updateLogEntry, deleteLogEntry } from './stores.js';
  import { unitsFor, SIZE_LABELS } from './units.js';

  const SIZES   = [100, 330, 500, 568];
  const AMOUNTS = [1, 1.5, 2, 3];

  let suggestions = [];
  let toastVisible = false;
  let toastTimer;

  $: units = ($sheet.drink && $sheet.size && $sheet.amount && $sheet.abv != null)
    ? unitsFor({ drink: $sheet.drink, size: $sheet.size, amount: $sheet.amount }, $catalog)
    : null;

  function onDrinkInput(e) {
    const q = e.target.value.toLowerCase();
    sheet.update(s => ({ ...s, drink: e.target.value, abv: null }));
    if (q.length < 1) { suggestions = []; return; }
    suggestions = $catalog
      .filter(c => c.drink.toLowerCase().includes(q) || c.brewery.toLowerCase().includes(q))
      .slice(0, 5);
  }

  function selectSuggestion(c) {
    sheet.update(s => ({ ...s, drink: c.drink, abv: c.abv }));
    suggestions = [];
  }

  const resetSheet = () =>
    sheet.set({ open: false, id: null, drink: '', abv: null, size: 500, amount: 1, notes: '', date: new Date().toISOString().slice(0, 10) });

  async function save() {
    if (!$sheet.drink) return;
    const payload = {
      date:   $sheet.date || new Date().toISOString().slice(0, 10),
      drink:  $sheet.drink,
      amount: $sheet.amount,
      size:   $sheet.size,
      notes:  $sheet.notes,
    };
    const ok = $sheet.id
      ? await updateLogEntry($sheet.id, payload)
      : await addLogEntry(payload);
    if (ok) {
      resetSheet();
      suggestions = [];
      showToast();
    }
  }

  async function handleDelete() {
    const id = $sheet.id;
    resetSheet();
    await deleteLogEntry(id);
  }

  function showToast() {
    toastVisible = true;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => { toastVisible = false; }, 1900);
  }

  function close() {
    resetSheet();
    suggestions = [];
  }
</script>

{#if toastVisible}
  <div class="toast">
    <span class="mono">Logged — cheers!</span>
  </div>
{/if}

{#if $sheet.open}
  <!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
  <div class="scrim" on:click={close}></div>
  <div class="sheet" role="dialog" aria-modal="true">
    <div class="handle"></div>
    <div class="sheet-header">
      <div>
        <h2 class="newsreader">{$sheet.id ? 'Edit entry' : 'Pour one in'}</h2>
        <p class="hint">{$sheet.id ? 'Update or delete this log entry.' : 'Log a drink to your journal.'}</p>
      </div>
      {#if $sheet.id}
        <button class="delete-btn" on:click={handleDelete} aria-label="Delete entry">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
            <polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 01-2 2H8a2 2 0 01-2-2L5 6"/><path d="M10 11v6M14 11v6"/><path d="M9 6V4a1 1 0 011-1h4a1 1 0 011 1v2"/>
          </svg>
        </button>
      {/if}
    </div>

    <div class="field-group">
      <label class="field-label mono">Date</label>
      <input class="field-input" type="date" bind:value={$sheet.date} />
    </div>

    <div class="field-group">
      <label class="field-label mono">What are you having?</label>
      <div class="autocomplete-wrap">
        <input
          class="field-input"
          type="text"
          placeholder="Drink name or brewery…"
          value={$sheet.drink}
          on:input={onDrinkInput}
        />
        {#if suggestions.length}
          <ul class="suggestions">
            {#each suggestions as s}
              <!-- svelte-ignore a11y-click-events-have-key-events a11y-no-noninteractive-element-interactions -->
              <li on:click={() => selectSuggestion(s)}>
                <span class="s-drink">{s.drink}</span>
                <span class="s-meta mono">{s.brewery} · {s.abv}%</span>
              </li>
            {/each}
          </ul>
        {/if}
      </div>
    </div>

    <div class="field-group">
      <label class="field-label mono">Serving</label>
      <div class="chips">
        {#each SIZES as sz}
          <button
            class="chip" class:selected={$sheet.size === sz}
            on:click={() => sheet.update(s => ({ ...s, size: sz }))}
          >{SIZE_LABELS[sz]}</button>
        {/each}
      </div>
      <input
        id="size"
        class="field-input size-input"
        type="number"
        min="1"
        placeholder="Enter ml…"
        bind:value={$sheet.size}
      />
    </div>

    <div class="field-group">
      <label class="field-label mono">How many?</label>
      <div class="chips">
        {#each AMOUNTS as a}
          <button
            class="chip" class:selected={$sheet.amount === a}
            on:click={() => sheet.update(s => ({ ...s, amount: a }))}
          >{a}</button>
        {/each}
      </div>
    </div>

    <div class="units-panel">
      <span class="up-label mono">ESTIMATED UNITS</span>
      <span class="up-value newsreader">{units != null ? units.toFixed(1) : '—'}</span>
    </div>

    <div class="field-group">
      <label class="field-label mono">Notes (optional)</label>
      <input
        class="field-input"
        type="text"
        placeholder="e.g. very hoppy"
        bind:value={$sheet.notes}
      />
    </div>

    <button class="save-btn" on:click={save} disabled={!$sheet.drink}>Save</button>
  </div>
{/if}

<style>
.scrim {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,.5);
  z-index: 40;
  animation: fadeIn .3s ease forwards;
}
@keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }

.sheet {
  position: fixed;
  bottom: 0;
  left: 50%;
  transform: translateX(-50%);
  width: 100%;
  max-width: 390px;
  background: var(--card);
  border-top: 1px solid var(--card-edge);
  border-radius: 22px 22px 0 0;
  padding: 12px 20px 36px;
  z-index: 50;
  max-height: 92dvh;
  overflow-y: auto;
  animation: slideUp .3s cubic-bezier(.3,.9,.3,1) forwards;
}
@keyframes slideUp { from { transform: translateX(-50%) translateY(102%); } to { transform: translateX(-50%) translateY(0); } }

.handle {
  width: 36px;
  height: 4px;
  border-radius: 2px;
  background: var(--card-edge);
  margin: 0 auto 16px;
}

.sheet-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  margin-bottom: 20px;
}
h2 { font-size: 23px; font-weight: 600; color: var(--ink); margin-bottom: 4px; }
.hint { font-size: 14px; color: var(--ink-2); }
.delete-btn {
  background: none;
  border: none;
  cursor: pointer;
  color: var(--ink-3);
  padding: 4px;
  border-radius: 8px;
  transition: color .15s;
  flex-shrink: 0;
  margin-top: 2px;
}
.delete-btn:hover { color: #c0392b; }
.delete-btn svg { width: 20px; height: 20px; display: block; }

.field-group { margin-bottom: 16px; }
.field-label {
  display: block;
  font-size: 10px;
  font-weight: 600;
  letter-spacing: .18em;
  text-transform: uppercase;
  color: var(--ink-3);
  margin-bottom: 8px;
}

.autocomplete-wrap { position: relative; }
.field-input {
  width: 100%;
  background: var(--paper);
  border: 1px solid var(--card-edge);
  border-radius: 11px;
  padding: 11px 13px;
  font-family: 'Hanken Grotesk', sans-serif;
  font-size: 15px;
  color: var(--ink);
  outline: none;
}
.field-input:focus { border-color: var(--amber); }
.size-input { margin-top: 8px; }

.suggestions {
  position: absolute;
  top: calc(100% + 4px);
  left: 0; right: 0;
  background: var(--card);
  border: 1px solid var(--card-edge);
  border-radius: 11px;
  list-style: none;
  z-index: 60;
  overflow: hidden;
  box-shadow: var(--card-shadow);
}
.suggestions li {
  padding: 10px 13px;
  cursor: pointer;
  display: flex;
  flex-direction: column;
  gap: 2px;
  border-bottom: 1px solid var(--line);
}
.suggestions li:last-child { border-bottom: none; }
.suggestions li:hover { background: var(--paper-2); }
.s-drink { font-size: 14px; color: var(--ink); }
.s-meta { font-size: 11px; color: var(--ink-3); }

.chips { display: flex; flex-wrap: wrap; gap: 8px; }
.chip {
  background: var(--paper-2);
  border: 1px solid var(--card-edge);
  border-radius: 10px;
  padding: 7px 13px;
  font-family: 'Hanken Grotesk', sans-serif;
  font-size: 13px;
  color: var(--ink-2);
  cursor: pointer;
  transition: background .15s, color .15s;
}
.chip.selected {
  background: var(--stout);
  color: var(--paper);
  border-color: var(--stout);
}
:global([data-theme="dark"]) .chip.selected {
  background: var(--amber);
  color: var(--stout);
  border-color: var(--amber);
}

.units-panel {
  background: var(--paper-2);
  border: 1px solid var(--card-edge);
  border-radius: 13px;
  padding: 14px 16px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 16px;
}
.up-label {
  font-size: 10px;
  font-weight: 600;
  letter-spacing: .2em;
  text-transform: uppercase;
  color: var(--ink-3);
}
.up-value {
  font-size: 30px;
  font-weight: 600;
  color: var(--amber);
  line-height: 1;
}

.save-btn {
  width: 100%;
  padding: 15px;
  border: none;
  border-radius: 13px;
  background: radial-gradient(ellipse at 60% 40%, var(--gold), var(--amber));
  color: var(--paper);
  font-family: 'Hanken Grotesk', sans-serif;
  font-size: 16px;
  font-weight: 700;
  cursor: pointer;
  margin-top: 8px;
  transition: opacity .15s;
}
.save-btn:disabled { opacity: .4; cursor: not-allowed; }

.toast {
  position: fixed;
  top: 16px;
  left: 50%;
  transform: translateX(-50%);
  background: var(--stout);
  color: var(--paper);
  padding: 10px 20px;
  border-radius: 10px;
  font-size: 13px;
  letter-spacing: .1em;
  z-index: 100;
  animation: toastIn .25s ease forwards;
}
@keyframes toastIn { from { opacity: 0; transform: translateX(-50%) translateY(-8px); } to { opacity: 1; transform: translateX(-50%) translateY(0); } }
</style>
