<script>
  import { activeTab, sheet } from './stores.js';

  const tabs = [
    { id: 'home',    label: 'Cellar',  icon: 'home' },
    { id: 'history', label: 'Journal', icon: 'list' },
    { id: 'stats',   label: 'Stats',   icon: 'bar' },
    { id: 'catalog', label: 'Beers',   icon: 'search' },
  ];

  function openSheet() {
    sheet.update(s => ({ ...s, open: true }));
  }
</script>

<nav>
  <button class="tab" class:active={$activeTab === 'home'} on:click={() => activeTab.set('home')}>
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
      <path d="M3 9.5L12 3l9 6.5V20a1 1 0 01-1 1H4a1 1 0 01-1-1V9.5z"/><path d="M9 21V12h6v9"/>
    </svg>
    <span class="mono">Home</span>
  </button>

  <button class="tab" class:active={$activeTab === 'history'} on:click={() => activeTab.set('history')}>
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
      <path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01"/>
    </svg>
    <span class="mono">Journal</span>
  </button>

  <button class="fab" on:click={openSheet} aria-label="Log a drink">
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round">
      <path d="M12 5v14M5 12h14"/>
    </svg>
  </button>

  <button class="tab" class:active={$activeTab === 'stats'} on:click={() => activeTab.set('stats')}>
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
      <rect x="3" y="12" width="4" height="9" rx="1"/><rect x="10" y="7" width="4" height="14" rx="1"/><rect x="17" y="3" width="4" height="18" rx="1"/>
    </svg>
    <span class="mono">Measures</span>
  </button>

  <button class="tab" class:active={$activeTab === 'catalog'} on:click={() => activeTab.set('catalog')}>
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="11" cy="11" r="8"/><path d="M21 21l-4.35-4.35"/>
    </svg>
    <span class="mono">Cellar</span>
  </button>
</nav>

<style>
nav {
  position: fixed;
  bottom: 0;
  left: 50%;
  transform: translateX(-50%);
  width: 100%;
  max-width: 390px;
  background: var(--nav-bg);
  border-top: 1px solid var(--card-edge);
  border-radius: 18px 18px 0 0;
  box-shadow: var(--nav-shadow);
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
  display: flex;
  align-items: center;
  justify-content: space-around;
  padding: 8px 8px 20px;
  z-index: 30;
}

.tab {
  background: none;
  border: none;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  cursor: pointer;
  color: var(--ink-3);
  padding: 6px 12px;
  border-radius: 10px;
  transition: color .15s;
  flex: 1;
}
.tab svg { width: 22px; height: 22px; }
.tab span {
  font-size: 9px;
  font-weight: 500;
  letter-spacing: .12em;
  text-transform: uppercase;
}
.tab.active { color: var(--amber); }

.fab {
  width: 54px;
  height: 54px;
  border-radius: 50%;
  border: none;
  background: radial-gradient(ellipse at 60% 40%, var(--gold), var(--amber));
  color: #fff;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: var(--fab-shadow);
  flex-shrink: 0;
  margin-bottom: 8px;
  transition: transform .15s;
}
.fab:active { transform: scale(.93); }
.fab svg { width: 24px; height: 24px; }
</style>
