<script>
  export let value = '';
  export let label = '';
</script>

<div class="tile">
  <span class="val newsreader">{value}</span>
  <span class="lbl mono">{label}</span>
</div>

<style>
.tile {
  background: var(--card);
  border: 1px solid var(--card-edge);
  border-radius: 13px;
  padding: 14px 12px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  box-shadow: var(--card-shadow);
}
.val {
  font-size: 27px;
  font-weight: 500;
  color: var(--ink);
  line-height: 1;
}
.lbl {
  font-size: 9.5px;
  font-weight: 500;
  letter-spacing: .18em;
  text-transform: uppercase;
  color: var(--ink-3);
}
</style>
