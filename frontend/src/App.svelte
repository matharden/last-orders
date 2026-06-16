<script>
  import { onMount } from 'svelte';
  import { activeTab, theme, refreshAll, loading, sheet } from './lib/stores.js';
  import BottomNav from './lib/BottomNav.svelte';
  import LogSheet from './lib/LogSheet.svelte';
  import Home from './routes/Home.svelte';
  import History from './routes/History.svelte';
  import Stats from './routes/Stats.svelte';
  import Catalog from './routes/Catalog.svelte';

  function toggleTheme() {
    theme.update(t => t === 'light' ? 'dark' : 'light');
  }

  onMount(async () => {
    const res = await fetch('/api/catalog');
    if (res.status === 401) {
      window.location.href = '/login';
      return;
    }
    await refreshAll();
  });

  $: if (typeof document !== 'undefined') {
    document.body.classList.toggle('no-scroll', $sheet.open);
  }
</script>

<div class="glow"></div>

<div class="top-bar">
  <button class="theme-btn" on:click={toggleTheme} aria-label="Toggle theme">
    {#if $theme === 'light'}
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
        <circle cx="12" cy="12" r="5"/><path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42"/>
      </svg>
    {:else}
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
        <path d="M21 12.79A9 9 0 1111.21 3 7 7 0 0021 12.79z"/>
      </svg>
    {/if}
  </button>
  <button class="logout-btn mono" on:click={() => window.location.href = '/logout'}>logout</button>
</div>

{#if $loading}
  <div class="loader">
    <span class="mono">loading…</span>
  </div>
{:else if $activeTab === 'home'}
  <Home />
{:else if $activeTab === 'history'}
  <History />
{:else if $activeTab === 'stats'}
  <Stats />
{:else if $activeTab === 'catalog'}
  <Catalog />
{/if}

<BottomNav />
<LogSheet />

<style>
.glow {
  position: fixed;
  top: 0; left: 0; right: 0;
  height: 200px;
  background: var(--glow);
  pointer-events: none;
  z-index: 0;
}

.top-bar {
  display: flex;
  justify-content: flex-end;
  align-items: center;
  gap: 8px;
  padding: 12px 20px 0;
  position: sticky;
  top: 0;
  z-index: 10;
}

.theme-btn {
  background: none;
  border: none;
  cursor: pointer;
  color: var(--ink-3);
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 8px;
  transition: color .15s;
}
.theme-btn:hover { color: var(--amber); }
.theme-btn svg { width: 18px; height: 18px; }

.logout-btn {
  background: none;
  border: none;
  cursor: pointer;
  font-size: 10px;
  font-weight: 500;
  letter-spacing: .12em;
  text-transform: uppercase;
  color: var(--ink-3);
  padding: 4px 8px;
  border-radius: 6px;
  transition: color .15s;
}
.logout-btn:hover { color: var(--amber); }

.loader {
  display: flex;
  align-items: center;
  justify-content: center;
  flex: 1;
  padding: 60px;
  color: var(--ink-3);
  font-size: 13px;
  letter-spacing: .14em;
}
</style>
