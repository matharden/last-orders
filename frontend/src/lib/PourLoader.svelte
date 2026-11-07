<!-- Pouring pint loading animation (pure CSS). Set --lo-size to scale. -->
<span class="lo-pour" role="img" aria-label="Loading">
  <span class="lo-pour__tap"></span>
  <span class="lo-pour__mug">
    <span class="lo-pour__stream"></span>
    <span class="lo-pour__beer">
      <span class="lo-pour__bubbles"><i></i><i></i><i></i><i></i></span>
      <span class="lo-pour__foam"></span>
    </span>
  </span>
  <span class="lo-pour__handle"></span>
</span>

<style>
.lo-pour {
  --lo-size: 64px;
  --lo-ink: var(--ink);   /* outline / tap */
  --lo-glass: #e9f3f6;    /* empty glass */
  --lo-beer: #f6a623;     /* top of the pint */
  --lo-beer-deep: #d97a12;/* bottom of the pint */
  --lo-foam: #fffaf0;
  --lo-duration: 4.5s;

  position: relative;
  display: inline-block;
  width: 1em;
  height: 1em;
  font-size: var(--lo-size);
  line-height: 0;
}
.lo-pour *,
.lo-pour *::before,
.lo-pour *::after { box-sizing: border-box; }

/* Tap */
.lo-pour__tap {
  position: absolute;
  left: .32em; top: .04em;
  width: .22em; height: .08em;
  background: var(--lo-ink);
  border-radius: .04em;
}
.lo-pour__tap::after {           /* nozzle */
  content: "";
  position: absolute;
  left: .07em; top: .07em;
  width: .065em; height: .06em;
  background: var(--lo-ink);
  border-radius: 0 0 .02em .02em;
}

/* Mug body */
.lo-pour__mug {
  position: absolute;
  left: .18em; top: .3em;
  width: .5em; height: .6em;
  background: var(--lo-glass);
  border: .06em solid var(--lo-ink);
  border-radius: .04em .04em .13em .13em;
}
/* Glass highlight */
.lo-pour__mug::after {
  content: "";
  position: absolute;
  left: .04em; top: .06em;
  width: .04em; height: .3em;
  border-radius: .02em;
  background: rgba(255,255,255,.65);
  z-index: 3;
}

/* Handle */
.lo-pour__handle {
  position: absolute;
  left: .63em; top: .42em;
  width: .21em; height: .32em;
  border: .06em solid var(--lo-ink);
  border-left: 0;
  border-radius: 0 .13em .13em 0;
}

/* Stream (lives inside the mug so the beer can cover it) */
.lo-pour__stream {
  position: absolute;
  left: .165em; top: -.2em; bottom: 0;
  width: .045em;
  background: var(--lo-beer);
  border-radius: .03em;
  z-index: 1;
  clip-path: inset(0 0 100% 0);
  animation: lo-stream var(--lo-duration) ease-in-out infinite;
}

/* Beer */
.lo-pour__beer {
  position: absolute;
  left: 0; right: 0; bottom: 0;
  height: 0;
  background: linear-gradient(to top, var(--lo-beer-deep), var(--lo-beer));
  border-radius: 0 0 .07em .07em;
  z-index: 2;
  animation: lo-fill var(--lo-duration) ease-in-out infinite;
}
.lo-pour__bubbles {
  position: absolute;
  inset: 0;
  overflow: hidden;
  border-radius: inherit;
}
.lo-pour__bubbles i {
  position: absolute;
  bottom: -.04em;
  width: .03em; height: .03em;
  border-radius: 50%;
  background: rgba(255,255,255,.7);
  animation: lo-bubble 1.4s linear infinite;
}
.lo-pour__bubbles i:nth-child(1) { left: 22%; animation-delay: 0s; }
.lo-pour__bubbles i:nth-child(2) { left: 55%; animation-delay: .5s; width: .022em; height: .022em; }
.lo-pour__bubbles i:nth-child(3) { left: 74%; animation-delay: .9s; }
.lo-pour__bubbles i:nth-child(4) { left: 38%; animation-delay: 1.15s; width: .02em; height: .02em; }

/* Foam head – rides on top of the beer */
.lo-pour__foam {
  position: absolute;
  left: -.02em; right: -.02em; top: -.07em;
  height: .1em;
  background: var(--lo-foam);
  border-radius: .05em;
  transform-origin: 50% 100%;
  transform: scaleY(0);
  animation: lo-foam var(--lo-duration) ease-in-out infinite;
}
.lo-pour__foam::before,
.lo-pour__foam::after {
  content: "";
  position: absolute;
  background: var(--lo-foam);
  border-radius: 50%;
}
.lo-pour__foam::before { left: .05em; top: -.05em; width: .14em; height: .12em; }
.lo-pour__foam::after  { left: .19em; top: -.07em; width: .17em; height: .14em; }

/* ---------- Timeline ----------
   0–10%   stream drops
   8–62%   pint fills, head builds
   62–72%  tap shuts, head puffs over the rim
   72–86%  admire it
   86–100% drained… last orders! */
@keyframes lo-stream {
  0%       { clip-path: inset(0 0 100% 0); }
  10%, 62% { clip-path: inset(0 0 0 0); }
  70%, 100%{ clip-path: inset(100% 0 0 0); }
}
@keyframes lo-fill {
  0%, 8%    { height: 0; }
  62%, 86%  { height: 86%; }
  98%, 100% { height: 0; }
}
@keyframes lo-foam {
  0%, 12%   { transform: scaleY(0); }
  30%       { transform: scaleY(.55); }
  62%       { transform: scaleY(.8); }
  72%, 86%  { transform: scaleY(1); }
  96%, 100% { transform: scaleY(0); }
}
@keyframes lo-bubble {
  0%   { transform: translateY(0); opacity: 0; }
  15%  { opacity: 1; }
  100% { transform: translateY(-.45em); opacity: 0; }
}

/* Respect reduced-motion: show a static full pint */
@media (prefers-reduced-motion: reduce) {
  .lo-pour *, .lo-pour *::before, .lo-pour *::after { animation: none !important; }
  .lo-pour__beer   { height: 86%; }
  .lo-pour__foam   { transform: none; }
  .lo-pour__stream { display: none; }
}
:global(:root[data-theme="dark"]) .lo-pour { --lo-glass: #3a2a1c; }
</style>
