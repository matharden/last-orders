<script>
  import { createEventDispatcher } from 'svelte';
  import { updateCatalogEntry } from './stores.js';

  export let drink = null; // Drink object to edit; null = closed

  const dispatch = createEventDispatcher();

  let brewery = '';
  let name    = '';
  let abv     = '';
  let rating  = 0;
  let image   = '';
  let notes   = '';
  let saving  = false;

  let uploadFile = null;
  let previewUrl = '';

  $: if (drink) {
    brewery = drink.brewery || '';
    name    = drink.drink   || '';
    abv     = drink.abv     != null ? String(drink.abv) : '';
    rating  = drink.rating  || 0;
    image   = drink.image   || '';
    notes   = drink.notes   || '';
    uploadFile = null;
    previewUrl = '';
  }

  function close() { dispatch('close'); }

  function handleFileChange(e) {
    const file = e.target.files[0];
    if (!file) return;
    uploadFile = file;
    previewUrl = URL.createObjectURL(file);
  }

  function removeImage() {
    image = '';
    uploadFile = null;
    previewUrl = '';
  }

  async function save() {
    if (!name) return;
    saving = true;

    let finalImage = image;
    if (uploadFile) {
      const formData = new FormData();
      formData.append('image', uploadFile);
      try {
        const res = await fetch('/api/upload', {
          method: 'POST',
          body: formData,
        });
        if (res.ok) {
          const data = await res.json();
          // Store only the raw filename returned by GCS upload
          finalImage = data.filename;
        } else {
          console.error('Failed to upload image');
        }
      } catch (err) {
        console.error('Upload error', err);
      }
    }

    await updateCatalogEntry(drink.id, {
      brewery,
      drink: name,
      abv:   parseFloat(abv) || 0,
      rating,
      image: finalImage,
      notes,
    });
    saving = false;
    close();
  }
</script>

{#if drink}
  <!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
  <div class="scrim" on:click={close}></div>
  <div class="sheet" role="dialog" aria-modal="true">
    <div class="handle"></div>

    <div class="sheet-header">
      <div>
        <h2 class="newsreader">Edit beer</h2>
        <p class="hint">Update the catalogue entry.</p>
      </div>
    </div>

    <div class="field-group">
      <label class="field-label mono">Brewery</label>
      <input class="field-input" type="text" placeholder="e.g. Beavertown" bind:value={brewery} />
    </div>

    <div class="field-group">
      <label class="field-label mono">Drink</label>
      <input class="field-input" type="text" placeholder="e.g. Neck Oil" bind:value={name} />
    </div>

    <div class="field-group">
      <label class="field-label mono">ABV %</label>
      <input
        class="field-input"
        type="number"
        step="0.1"
        min="0"
        max="100"
        placeholder="4.3"
        inputmode="decimal"
        pattern="[0-9\.]*"
        bind:value={abv}
      />
    </div>

    <div class="field-group">
      <label class="field-label mono">Rating</label>
      <div class="stars">
        {#each [1,2,3,4,5] as n}
          <button class="star" class:filled={n <= rating} on:click={() => rating = rating === n ? 0 : n}>
            {n <= rating ? '★' : '☆'}
          </button>
        {/each}
        {#if rating}<span class="rating-val mono">{rating}/5</span>{/if}
      </div>
    </div>

    <div class="field-group">
      <label class="field-label mono">Image</label>
      <div class="image-upload-wrapper">
        {#if previewUrl || image}
          <div class="preview-container">
            <img src={previewUrl || image} alt="Preview" class="image-preview" />
            <button type="button" class="remove-image-btn" on:click={removeImage}>✕ Remove</button>
          </div>
        {:else}
          <label class="upload-zone">
            <input type="file" accept="image/*" on:change={handleFileChange} style="display:none;" />
            <svg class="upload-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <rect x="3" y="3" width="18" height="18" rx="2" ry="2"/>
              <circle cx="8.5" cy="8.5" r="1.5"/>
              <polyline points="21 15 16 10 5 21"/>
            </svg>
            <span class="upload-text">Upload photo</span>
          </label>
        {/if}
      </div>
    </div>

    <div class="field-group">
      <label class="field-label mono">Notes</label>
      <input class="field-input" type="text" placeholder="e.g. Seasonal, limited edition…" bind:value={notes} />
    </div>

    <button class="save-btn" on:click={save} disabled={!name || saving}>
      {saving ? 'Saving…' : 'Save changes'}
    </button>
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

.sheet-header { margin-bottom: 20px; }
h2 { font-size: 23px; font-weight: 600; color: var(--ink); margin-bottom: 4px; }
.hint { font-size: 14px; color: var(--ink-2); }

.field-group { margin-bottom: 14px; }
.field-label {
  display: block;
  font-size: 10px;
  font-weight: 600;
  letter-spacing: .18em;
  text-transform: uppercase;
  color: var(--ink-3);
  margin-bottom: 7px;
}
.field-input {
  width: 100%;
  background: var(--paper);
  border: 1px solid var(--card-edge);
  border-radius: 11px;
  padding: 11px 13px;
  font-family: 'Hanken Grotesk', sans-serif;
  font-size: 1rem;
  color: var(--ink);
  outline: none;
}
.field-input:focus { border-color: var(--amber); }

.stars {
  display: flex;
  align-items: center;
  gap: 4px;
}
.star {
  background: none;
  border: none;
  font-size: 26px;
  color: var(--paper-2);
  cursor: pointer;
  padding: 2px;
  line-height: 1;
  transition: color .1s, transform .1s;
}
.star.filled { color: var(--gold); }
.star:hover { transform: scale(1.15); }
.rating-val {
  font-size: 11px;
  color: var(--ink-3);
  margin-left: 6px;
}

.image-upload-wrapper {
  margin-top: 4px;
}
.preview-container {
  display: flex;
  align-items: center;
  gap: 12px;
  background: var(--paper);
  border: 1px solid var(--card-edge);
  padding: 8px;
  border-radius: 11px;
}
.image-preview {
  width: 54px;
  height: 54px;
  border-radius: 7px;
  object-fit: cover;
  background: var(--paper-2);
}
.remove-image-btn {
  background: none;
  border: 1px solid var(--card-edge);
  color: var(--ink-3);
  padding: 6px 12px;
  border-radius: 8px;
  font-family: inherit;
  font-size: 12px;
  cursor: pointer;
  transition: background .12s, color .12s;
}
.remove-image-btn:hover {
  background: var(--paper-2);
  color: var(--ink);
}
.upload-zone {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  border: 1px dashed var(--card-edge);
  padding: 16px;
  border-radius: 11px;
  cursor: pointer;
  background: var(--paper);
  transition: border-color .15s;
}
.upload-zone:hover {
  border-color: var(--amber);
}
.upload-icon {
  width: 20px;
  height: 20px;
  color: var(--ink-3);
}
.upload-text {
  font-size: 13px;
  color: var(--ink-2);
  font-weight: 500;
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
</style>
