<script>
  import { onMount, tick } from 'svelte';
  import { activeTab, refreshAll, loading, sheet, saveError } from './lib/stores.js';
  import PourLoader from './lib/PourLoader.svelte';
  import BottomNav from './lib/BottomNav.svelte';
  import LogSheet from './lib/LogSheet.svelte';
  import Home from './routes/Home.svelte';
  import History from './routes/History.svelte';
  import Stats from './routes/Stats.svelte';
  import Catalog from './routes/Catalog.svelte';
  import Tankard from './routes/Tankard.svelte';

  let showLoginScreen = false;

  onMount(async () => {
    // One round of requests: refreshAll fetches catalog + log in parallel and
    // reports 401 so we can show the login screen (previously /api/catalog was
    // fetched once just to check auth, then again inside refreshAll).
    const status = await refreshAll();
    if (status === 401) showLoginScreen = true;
  });

  // Each tab keeps its own scroll position. The subscriber runs synchronously
  // on activeTab.set(), before Svelte swaps the view, so window.scrollY still
  // belongs to the tab being left. After the new view renders, restore its
  // saved position (or the top on first visit).
  const scrollByTab = {};
  let currentTab;
  onMount(() => activeTab.subscribe(async tab => {
    if (currentTab === undefined) { currentTab = tab; return; }
    if (tab === currentTab) return;
    scrollByTab[currentTab] = window.scrollY;
    currentTab = tab;
    await tick();
    window.scrollTo(0, scrollByTab[tab] ?? 0);
  }));

  $: if (typeof document !== 'undefined') {
    document.body.classList.toggle('no-scroll', $sheet.open);
  }
</script>

<div class="glow"></div>

{#if $saveError}
  <div class="save-error" role="alert">
    <span>{$saveError}</span>
    <button on:click={() => saveError.set('')} aria-label="Dismiss">×</button>
  </div>
{/if}

<div class="top-bar">
  {#if !showLoginScreen}
    <button class="tankard-btn mono" class:active={$activeTab === 'tankard'} on:click={() => activeTab.set('tankard')}>tankard</button>
  {/if}
</div>

{#if $loading}
  <div class="loader">
    <PourLoader />
  </div>
{:else if showLoginScreen}
  <div class="welcome-screen fade">
    <div class="brand-hero">
      <div class="decorative-glass">
        <!-- SVG drawing of a stylized vintage coupe cocktail/beer glass -->
        <svg viewBox="0 0 100 100" class="glass-art">
          <!-- Stand/Base -->
          <path d="M 35 90 L 65 90" stroke="var(--amber)" stroke-width="2" stroke-linecap="round"/>
          <!-- Stem -->
          <path d="M 50 65 L 50 90" stroke="var(--amber)" stroke-width="2"/>
          <!-- Bowl -->
          <path d="M 25 35 Q 25 65 50 65 Q 75 65 75 35 Z" fill="none" stroke="var(--ink)" stroke-width="2"/>
          <!-- Liquid reflection/gradient line -->
          <path d="M 29 45 Q 50 50 71 45" stroke="var(--gold)" stroke-width="3" fill="none" stroke-linecap="round"/>
          <path d="M 33 55 Q 50 58 67 55" stroke="var(--amber)" stroke-width="2.5" fill="none" opacity="0.8" stroke-linecap="round"/>
          <!-- Decorative bubbles -->
          <circle cx="48" cy="40" r="1.5" fill="var(--gold)"/>
          <circle cx="53" cy="43" r="1" fill="var(--gold)"/>
          <circle cx="44" cy="48" r="1.2" fill="var(--gold)"/>
          <circle cx="56" cy="47" r="1.5" fill="var(--gold)"/>
        </svg>
      </div>
      <span class="eyebrow welcome-eyebrow">THE TASTING JOURNAL</span>
      <h1 class="newsreader welcome-title">Last orders</h1>
      <p class="welcome-desc">
        A personal log for your pours, measures, and tasting notes.
        Track weekly units and keep a detailed catalog of your collection.
      </p>
    </div>

    <div class="action-section">
      <a href="/login" class="login-btn newsreader">
        Sign in with Google
        <svg viewBox="0 0 24 24" class="arrow-icon">
          <path d="M5 12h14M12 5l7 7-7 7" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none"/>
        </svg>
      </a>
      <span class="mono note">Authorized access only</span>
    </div>
  </div>
{:else if $activeTab === 'home'}
  <Home />
{:else if $activeTab === 'history'}
  <History />
{:else if $activeTab === 'stats'}
  <Stats />
{:else if $activeTab === 'catalog'}
  <Catalog />
{:else if $activeTab === 'tankard'}
  <Tankard />
{/if}

{#if !showLoginScreen}
  <BottomNav />
  <LogSheet />
{/if}

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

.save-error {
  position: fixed;
  top: 12px;
  left: 50%;
  transform: translateX(-50%);
  width: calc(100% - 32px);
  max-width: 420px;
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 11px 14px;
  background: var(--card);
  border: 1px solid var(--card-edge);
  border-radius: 12px;
  box-shadow: var(--card-shadow);
  color: var(--ink);
  font-size: 13px;
  z-index: 100;
}
.save-error span { flex: 1; }
.save-error button {
  background: none;
  border: none;
  cursor: pointer;
  color: var(--ink-3);
  font-size: 18px;
  line-height: 1;
}

.tankard-btn {
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
.tankard-btn:hover, .tankard-btn.active { color: var(--amber); }

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

/* Welcome Screen */
.welcome-screen {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  align-items: center;
  flex: 1;
  padding: 60px 24px 80px;
  text-align: center;
}

.brand-hero {
  display: flex;
  flex-direction: column;
  align-items: center;
  margin-top: 20px;
}

.decorative-glass {
  position: relative;
  width: 140px;
  height: 140px;
  background: var(--card);
  border: 1px solid var(--card-edge);
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 32px;
  box-shadow: var(--card-shadow);
}

.glass-art {
  width: 70px;
  height: 70px;
}

.welcome-eyebrow {
  margin-bottom: 12px;
  letter-spacing: .35em;
  font-size: 11px;
}

.welcome-title {
  font-size: 40px;
  font-weight: 600;
  color: var(--ink);
  margin-bottom: 16px;
  line-height: 1.1;
}

.welcome-desc {
  font-size: 14.5px;
  line-height: 1.6;
  color: var(--ink-2);
  max-width: 280px;
}

.action-section {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 16px;
  width: 100%;
}

.login-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
  width: 100%;
  max-width: 260px;
  padding: 16px 24px;
  background: linear-gradient(135deg, var(--gold), var(--amber));
  color: var(--stout);
  text-decoration: none;
  font-size: 17px;
  font-weight: 500;
  border-radius: 12px;
  box-shadow: 0 4px 20px -6px rgba(176,100,15,.4);
  transition: transform 0.2s cubic-bezier(0.34, 1.56, 0.64, 1), box-shadow 0.2s ease;
}

.login-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 24px -6px rgba(176,100,15,.6);
}

.login-btn:active {
  transform: translateY(0);
}

.arrow-icon {
  width: 18px;
  height: 18px;
  transition: transform 0.2s ease;
}

.login-btn:hover .arrow-icon {
  transform: translateX(4px);
}

.note {
  font-size: 10px;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: var(--ink-3);
}

.fade {
  animation: settle .4s ease forwards;
}

@keyframes settle {
  from { opacity: .85; transform: translateY(8px); }
  to { opacity: 1; transform: translateY(0); }
}
</style>
