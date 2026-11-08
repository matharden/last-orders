<script>
  import { activeTab, sheet } from './stores.js';

  const tabs = [
    { id: 'home',    label: 'Cellar',  icon: 'home' },
    { id: 'history', label: 'Bar tab', icon: 'list' },
    { id: 'stats',   label: 'Stats',   icon: 'bar' },
    { id: 'catalog', label: 'Beers',   icon: 'search' },
  ];

  // Crown-cap skirt: 21 rounded flutes around a 100×100 viewBox.
  const FLUTES = 21;
  const capPath = (() => {
    const pt = (r, a) => `${(50 + r * Math.sin(a)).toFixed(2)} ${(50 - r * Math.cos(a)).toFixed(2)}`;
    const step = (2 * Math.PI) / FLUTES;
    let d = `M ${pt(42.5, 0)}`;
    for (let i = 0; i < FLUTES; i++) {
      d += ` Q ${pt(51.5, (i + 0.5) * step)} ${pt(42.5, (i + 1) * step)}`;
    }
    return d + ' Z';
  })();
  const flutes = Array.from({ length: FLUTES }, (_, i) => ((i + 0.5) * 360) / FLUTES);

  // Let the cap pop up at the bottom edge before the sheet slides up.
  let flipping = false;
  function openSheet() {
    if (flipping) return;
    flipping = true;
    setTimeout(() => sheet.update(s => ({ ...s, open: true })), 160);
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
      <path d="M5 8v11a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2V8"/>
      <path d="M15 10h2a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2h-2"/>
      <path d="M5 8a2 2 0 0 1 .5-4 3 3 0 0 1 5-1 2.5 2.5 0 0 1 4.5 2 1.5 1.5 0 0 1 0 3z"/>
      <path d="M9 12v5M12 12v5"/>
    </svg>
    <span class="mono">Bar tab</span>
  </button>

  <button class="fab" class:flipping on:click={openSheet} on:animationend={() => (flipping = false)} aria-label="Put on tab">
    <svg viewBox="0 0 100 100" aria-hidden="true">
      <defs>
        <radialGradient id="cap-metal" cx="38%" cy="32%" r="75%">
          <stop offset="0%" stop-color="#fff3d2"/>
          <stop offset="28%" stop-color="var(--gold)"/>
          <stop offset="75%" stop-color="var(--amber)"/>
          <stop offset="100%" stop-color="var(--amber-2)"/>
        </radialGradient>
        <path id="cap-arc-top" d="M 27.5 50 A 22.5 22.5 0 0 1 72.5 50"/>
      </defs>

      <!-- crimped skirt -->
      <path d={capPath} fill="url(#cap-metal)" stroke="var(--amber-2)" stroke-width=".8" stroke-linejoin="round"/>
      {#each flutes as deg}
        <line x1="50" y1="6" x2="50" y2="12" transform="rotate({deg} 50 50)"
              stroke="#fff6dc" stroke-opacity=".3" stroke-width="1.2" stroke-linecap="round"/>
      {/each}
      <!-- fold where the skirt meets the crown -->
      <circle cx="50" cy="50" r="38.5" fill="none" stroke="var(--amber-2)" stroke-opacity=".55" stroke-width="1.2"/>

      <!-- printed crown -->
      <circle cx="50" cy="50" r="36" fill="#3a1f10"/>
      <circle cx="50" cy="50" r="32.5" fill="none" stroke="var(--gold)" stroke-width="1"/>
      <circle cx="50" cy="50" r="31" fill="none" stroke="var(--gold)" stroke-width=".4"/>

      <text class="cap-arc" fill="var(--gold)">
        <textPath href="#cap-arc-top" startOffset="50%" text-anchor="middle">PUT ON</textPath>
      </text>
      <path d="M 33 47 H 67 M 33 64 H 67" stroke="var(--gold)" stroke-width=".6"/>
      <text class="cap-word" x="50" y="61.5" text-anchor="middle" fill="#f6e7c4">Tab</text>
      <text class="cap-stars" x="50" y="75" text-anchor="middle" fill="var(--gold)">★ ★ ★</text>
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
      <ellipse cx="12" cy="5" rx="6" ry="1.5" />
      <path d="M6 5c-2 3-2 11 0 14" />
      <path d="M18 5c2 3 2 11 0 14" />
      <path d="M6 19c1 1.5 3.5 2 6 2s5-.5 6-2" />
      <path d="M4.5 10c2.5 1 5.5 1.5 7.5 1.5s5-.5 7.5-1.5" />
      <path d="M4.5 14c2.5 1 5.5 1.5 7.5 1.5s5-.5 7.5-1.5" />
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
  width: 62px;
  height: 62px;
  padding: 0;
  border-radius: 50%;
  border: none;
  background: none;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: var(--fab-shadow);
  flex-shrink: 0;
  margin-bottom: 8px;
  transition: transform .2s;
}
.fab:active:not(.flipping) { transform: scale(.94); }
/* pops up at the bottom edge, hinged on the top, then settles back */
.fab.flipping { animation: cap-pop .42s cubic-bezier(.3,.7,.4,1); transform-origin: 50% 8%; }
@keyframes cap-pop {
  0%   { transform: perspective(200px) rotateX(0); }
  35%  { transform: perspective(200px) rotateX(30deg); }
  100% { transform: perspective(200px) rotateX(0); }
}

.fab svg { width: 100%; height: 100%; display: block; overflow: visible; }
.cap-arc {
  font-family: 'Spline Sans Mono', monospace;
  font-size: 9.5px;
  font-weight: 600;
  letter-spacing: .12em;
}
.cap-word {
  font-family: 'Newsreader', serif;
  font-size: 19px;
  font-weight: 600;
  letter-spacing: -.01em;
}
.cap-stars { font-size: 5px; letter-spacing: .3em; }
</style>
