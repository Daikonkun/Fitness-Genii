#!/bin/bash
# Auto-compact context when the LLM context window approaches its limit.
# Estimates token usage, compares against a configurable threshold, and when
# exceeded, serializes conversation history into a structured summary while
# preserving system prompt, active requirement IDs, and the last N turns.
# Logs the compaction event for auditability.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/_project-root.sh"
PROJECT_ROOT="$(vibe_resolve_project_root)"
CONFIG_FILE="${PROJECT_ROOT}/.vibe-config.local.json"
if [ ! -f "$CONFIG_FILE" ]; then
  CONFIG_FILE="${PROJECT_ROOT}/.vibe-config.json"
fi
COMPACT_LOG="${PROJECT_ROOT}/logs/compaction.log"

# ── Defaults ──────────────────────────────────────────────────────────────
DEFAULT_CONTEXT_WINDOW_LIMIT=128000
DEFAULT_COMPACTION_THRESHOLD=0.80
DEFAULT_PRESERVED_TURNS=3
DEFAULT_MODEL="default"

# ── Load config ───────────────────────────────────────────────────────────
load_config() {
  if [ -f "$CONFIG_FILE" ]; then
    CONTEXT_WINDOW_LIMIT="$(jq -r '.contextWindowLimit // empty' "$CONFIG_FILE")"
    COMPACTION_THRESHOLD="$(jq -r '.compactionThreshold // empty' "$CONFIG_FILE")"
    PRESERVED_TURNS="$(jq -r '.preservedTurns // empty' "$CONFIG_FILE")"
    MODEL="$(jq -r '.model // empty' "$CONFIG_FILE")"
  fi

  CONTEXT_WINDOW_LIMIT="${CONTEXT_WINDOW_LIMIT:-$DEFAULT_CONTEXT_WINDOW_LIMIT}"
  COMPACTION_THRESHOLD="${COMPACTION_THRESHOLD:-$DEFAULT_COMPACTION_THRESHOLD}"
  PRESERVED_TURNS="${PRESERVED_TURNS:-$DEFAULT_PRESERVED_TURNS}"
  MODEL="${MODEL:-$DEFAULT_MODEL}"

  # Check for model-specific overrides
  if [ -f "$CONFIG_FILE" ]; then
    MODEL_LIMIT="$(jq -r --arg m "$MODEL" '.modelOverrides[$m].contextWindowLimit // empty' "$CONFIG_FILE")"
    MODEL_THRESHOLD="$(jq -r --arg m "$MODEL" '.modelOverrides[$m].compactionThreshold // empty' "$CONFIG_FILE")"
    MODEL_TURNS="$(jq -r --arg m "$MODEL" '.modelOverrides[$m].preservedTurns // empty' "$CONFIG_FILE")"
    CONTEXT_WINDOW_LIMIT="${MODEL_LIMIT:-$CONTEXT_WINDOW_LIMIT}"
    COMPACTION_THRESHOLD="${MODEL_THRESHOLD:-$COMPACTION_THRESHOLD}"
    PRESERVED_TURNS="${MODEL_TURNS:-$PRESERVED_TURNS}"
  fi
}

# ── Token estimation ──────────────────────────────────────────────────────
# Rough heuristic: ~4 characters per token for English text.
# This is intentionally approximate; the threshold includes a safety margin.
estimate_tokens() {
  local text="$1"
  local char_count
  char_count=$(printf '%s' "$text" | wc -c | tr -d ' ')
  echo $(( char_count / 4 ))
}

# ── Compaction routine ───────────────────────────────────────────────────
# Reads the current context from stdin or a file, produces a compacted
# version on stdout.
#
# Input format (JSON):
#   {
#     "systemPrompt": "...",
#     "activeRequirements": ["REQ-123", "REQ-456"],
#     "turns": [
#       { "role": "user", "content": "..." },
#       { "role": "assistant", "content": "..." },
#       { "role": "tool", "content": "..." }
#     ]
#   }
compact() {
  local input="${1:-/dev/stdin}"
  local total_tokens pre_tokens post_tokens threshold_tokens
  local input_text

  input_text="$(cat "$input")"
  total_tokens="$(estimate_tokens "$input_text")"
  threshold_tokens="$(awk "BEGIN {printf \"%d\", $CONTEXT_WINDOW_LIMIT * $COMPACTION_THRESHOLD}")"

  if [ "$total_tokens" -lt "$threshold_tokens" ]; then
    # No compaction needed
    echo "$input_text"
    return 0
  fi

  pre_tokens="$total_tokens"

  # Single-pass jq: extract preserved parts, compact turns, and build summary
  local compact_result
  compact_result="$(echo "$input_text" | jq --argjson n "$PRESERVED_TURNS" '{
    systemPrompt: .systemPrompt,
    activeRequirements: .activeRequirements,
    turns_count: (.turns | length),
    compacted_turns: (.turns | (. | length) as $len | if $len <= $n then . else .[-$n:] end),
    discarded_count: (if (.turns | length) > $n then (.turns | length) - $n else 0 end),
    summary: (if (.turns | length) > $n then "Compacted \((.turns | length) - $n) earlier turns. Key topics: " + (.turns[:-$n] | map(select(.role == "user") | .content[:80]) | join("; ")) else "No turns compacted." end)
  }')"

  local turns_count discarded_count summary compacted_turns
  turns_count="$(echo "$compact_result" | jq '.turns_count')"
  discarded_count="$(echo "$compact_result" | jq '.discarded_count')"
  summary="$(echo "$compact_result" | jq -r '.summary')"
  compacted_turns="$(echo "$compact_result" | jq '.compacted_turns')"

  # Produce compacted output
  local output
  output="$(echo "$input_text" | jq --argjson turns "$compacted_turns" --arg summary "$summary" '{
    systemPrompt: .systemPrompt,
    activeRequirements: .activeRequirements,
    compactionSummary: $summary,
    turns: $turns
  }')"

  post_tokens="$(estimate_tokens "$output")"

  # Log the compaction event
  log_compaction "$pre_tokens" "$post_tokens" "$summary" "$discarded_count"

  # Notify the user
  echo "⚠️  Auto-compaction triggered: ${pre_tokens} → ${post_tokens} tokens (${discarded_count} turns compacted)" >&2
  echo "   Summary: $summary" >&2
  echo "   Review the compaction log: $COMPACT_LOG" >&2

  echo "$output"
  return 0
}

# ── Logging ───────────────────────────────────────────────────────────────
log_compaction() {
  local pre_tokens="$1"
  local post_tokens="$2"
  local summary="$3"
  local discarded_count="$4"
  local timestamp
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  mkdir -p "$(dirname "$COMPACT_LOG")"

  local log_entry
  log_entry="$(jq -n \
    --arg ts "$timestamp" \
    --arg pre "$pre_tokens" \
    --arg post "$post_tokens" \
    --arg summary "$summary" \
    --arg discarded "$discarded_count" \
    --arg model "$MODEL" \
    --arg threshold "$COMPACTION_THRESHOLD" \
    --arg limit "$CONTEXT_WINDOW_LIMIT" \
    '{
      timestamp: $ts,
      preTokenCount: ($pre | tonumber),
      postTokenCount: ($post | tonumber),
      discardedTurns: ($discarded | tonumber),
      summary: $summary,
      model: $model,
      threshold: ($threshold | tonumber),
      contextWindowLimit: ($limit | tonumber)
    }')"

  # Append to log file (one JSON object per line)
  echo "$log_entry" >> "$COMPACT_LOG"
}

# ── Check-only mode ───────────────────────────────────────────────────────
# Returns exit code 0 if compaction is needed, 1 otherwise.
# Useful as a pre-check before LLM calls.
check() {
  local input="${1:-/dev/stdin}"
  local input_text total_tokens threshold_tokens

  input_text="$(cat "$input")"
  total_tokens="$(estimate_tokens "$input_text")"
  threshold_tokens="$(awk "BEGIN {printf \"%d\", $CONTEXT_WINDOW_LIMIT * $COMPACTION_THRESHOLD}")"

  if [ "$total_tokens" -ge "$threshold_tokens" ]; then
    echo "COMPACTION_NEEDED: ${total_tokens}/${threshold_tokens} tokens (threshold: ${COMPACTION_THRESHOLD}×${CONTEXT_WINDOW_LIMIT})"
    return 0
  else
    echo "OK: ${total_tokens}/${threshold_tokens} tokens"
    return 1
  fi
}

# ── Main ──────────────────────────────────────────────────────────────────
load_config

case "${1:-compact}" in
  compact)
    compact "${2:-/dev/stdin}"
    ;;
  check)
    check "${2:-/dev/stdin}"
    ;;
  --help|-h)
    echo "Usage: $0 [compact|check] [input-file]"
    echo ""
    echo "Commands:"
    echo "  compact [file]  Compact context from file (or stdin). Outputs compacted JSON."
    echo "  check [file]    Check if compaction is needed. Exit 0 = needed."
    echo ""
    echo "Config: $CONFIG_FILE"
    echo "  contextWindowLimit  Token limit for the LLM (default: $DEFAULT_CONTEXT_WINDOW_LIMIT)"
    echo "  compactionThreshold  Fraction that triggers compaction (default: $DEFAULT_COMPACTION_THRESHOLD)"
    echo "  preservedTurns       Number of recent turns to keep (default: $DEFAULT_PRESERVED_TURNS)"
    echo "  model                Current model name (for modelOverrides lookup)"
    echo "  modelOverrides.<model>.{contextWindowLimit,compactionThreshold,preservedTurns}"
    ;;
  *)
    echo "Unknown command: $1" >&2
    echo "Use --help for usage." >&2
    exit 1
    ;;
esac
