#!/bin/bash
# Stop hook: blocks ending the turn when one side of a paired front-end file
# changed (vs HEAD) but its counterpart didn't. Pairs are the strict
# line-for-line ports listed in .claude/agents/frontend-sync.md.

input=$(cat)

# Avoid an infinite block loop: if this stop is already a continuation caused
# by this hook, let it through.
if echo "$input" | jq -e '.stop_hook_active == true' >/dev/null 2>&1; then
  exit 0
fi

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root" || exit 0

# Tracked modifications plus untracked files (a not-yet-committed counterpart
# still counts as "changed").
changed=$(
  git diff --name-only HEAD 2>/dev/null
  git ls-files --others --exclude-standard 2>/dev/null
)
[ -z "$changed" ] && exit 0

messages=""
check_pair() {
  local a="$1" b="$2"
  local a_hit b_hit
  a_hit=$(printf '%s\n' "$changed" | grep -Fx "$a")
  b_hit=$(printf '%s\n' "$changed" | grep -Fx "$b")
  if [ -n "$a_hit" ] && [ -z "$b_hit" ]; then
    messages="${messages}${a} changed but its counterpart ${b} did not. "
  elif [ -n "$b_hit" ] && [ -z "$a_hit" ]; then
    messages="${messages}${b} changed but its counterpart ${a} did not. "
  fi
}

# Strict pairs: add a line per pairing that must never diverge.
check_pair "frontend/src/lib/units.js" "ios/LastOrders/Units.swift"

if [ -n "$messages" ]; then
  jq -n --arg reason "Front-end sync check failed: ${messages}Port the change to the counterpart file (mapping in .claude/agents/frontend-sync.md), or if no port is genuinely needed, tell the user why before finishing." \
    '{decision: "block", reason: $reason}'
fi
exit 0
