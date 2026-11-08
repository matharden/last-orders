<script>
  import { onMount } from 'svelte';
  import { theme, config, fetchConfig } from '../lib/stores.js';

  onMount(() => { if (!$config) fetchConfig(); });
</script>

<div class="screen fade">
  <h1 class="newsreader title">Tankard</h1>
  <p class="sub">Your settings, and where your journal lives.</p>

  <p class="eyebrow section-eye">APPEARANCE</p>
  <div class="card mb">
    <div class="row">
      <span>Theme</span>
      <div class="seg" role="radiogroup" aria-label="Theme">
        <button class="mono" role="radio" aria-checked={$theme === 'light'} class:on={$theme === 'light'} on:click={() => theme.set('light')}>Light</button>
        <button class="mono" role="radio" aria-checked={$theme === 'dark'} class:on={$theme === 'dark'} on:click={() => theme.set('dark')}>Dark</button>
      </div>
    </div>
  </div>

  <p class="eyebrow section-eye">DATA</p>
  <div class="card mb">
    {#if $config?.sheetUrl}
      <a class="row link" href={$config.sheetUrl} target="_blank" rel="noopener">
        <span>Open source sheet</span>
        <span class="arrow" aria-hidden="true">↗</span>
      </a>
    {:else}
      <div class="row muted"><span>Open source sheet</span><span class="mono small">loading…</span></div>
    {/if}
  </div>

  <p class="eyebrow section-eye">ACCOUNT</p>
  <div class="card mb">
    <a class="row link" href="/logout">
      <span>Sign out</span>
      <span class="mono small amber">logout</span>
    </a>
  </div>
</div>

<style>
.screen { padding: 20px 20px 100px; }
.fade { animation: settle .4s ease forwards; }
@keyframes settle { from { opacity: .85; transform: translateY(8px); } to { opacity: 1; transform: translateY(0); } }
.title { font-size: 28px; font-weight: 600; color: var(--ink); line-height: 1.1; }
.sub { font-size: 14px; color: var(--ink-2); margin: 4px 0 22px; }
.section-eye { margin-bottom: 10px; }
.mb { margin-bottom: 20px; }
.card {
  background: var(--card);
  border: 1px solid var(--card-edge);
  border-radius: 14px;
  padding: 4px 16px;
  box-shadow: var(--card-shadow);
}
.row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  min-height: 48px;
  font-size: 15px;
  color: var(--ink);
}
.link { text-decoration: none; }
.link:hover span:first-child { color: var(--amber); }
.muted { color: var(--ink-3); }
.arrow { color: var(--amber); font-size: 16px; }
.small { font-size: 10px; letter-spacing: .12em; text-transform: uppercase; color: var(--ink-3); }
.amber { color: var(--amber); }
.seg {
  display: flex;
  background: var(--paper-2);
  border: 1px solid var(--card-edge);
  border-radius: 9px;
  padding: 2px;
}
.seg button {
  background: none;
  border: none;
  cursor: pointer;
  font-size: 10px;
  font-weight: 500;
  letter-spacing: .12em;
  text-transform: uppercase;
  color: var(--ink-3);
  padding: 6px 12px;
  border-radius: 7px;
}
.seg button.on { background: var(--card); color: var(--amber); box-shadow: var(--card-shadow); }
</style>
