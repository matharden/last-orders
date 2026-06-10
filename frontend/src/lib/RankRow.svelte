<script>
  export let index = 1;
  export let name = '';
  export let count = 0;
  export let max = 1;
</script>

<div class="row">
  <span class="idx mono">{index}</span>
  <span class="name">{name}</span>
  <div class="track">
    <div class="fill" style="width:{Math.round((count/max)*100)}%"></div>
  </div>
  <span class="count mono">{Math.ceil(count)}</span>
</div>

<style>
.row {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 7px 0;
}
.idx {
  font-size: 10px;
  color: var(--ink-3);
  width: 14px;
  text-align: right;
  flex-shrink: 0;
}
.name {
  font-size: 13.5px;
  color: var(--ink);
  width: 118px;
  flex-shrink: 0;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.track {
  flex: 1;
  height: 8px;
  border-radius: 4px;
  background: var(--paper-2);
  box-shadow: inset 0 0 0 1px var(--card-edge);
  overflow: hidden;
}
.fill {
  height: 100%;
  border-radius: 4px;
  background: linear-gradient(to right, var(--gold), var(--amber));
  box-shadow: 0 0 18px -3px rgba(224,146,47,.5);
  min-width: 4px;
}
.count {
  font-size: 11px;
  color: var(--ink-2);
  width: 28px;
  text-align: right;
  flex-shrink: 0;
}
</style>
