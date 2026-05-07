#!/bin/bash
# Guard: ensure command docs/prompts do not reference nonexistent scripts.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/_project-root.sh"
PROJECT_ROOT="$(vibe_resolve_project_root)"
cd "$PROJECT_ROOT"

if [ ! -d "scripts" ]; then
  echo "Error: scripts/ directory not found." >&2
  exit 1
fi

FILES=(
  "README.md"
  "copilot-instructions.md"
  "docs/COMMAND_MAP.md"
)

for prompt in .github/prompts/*.prompt.md; do
  [ -f "$prompt" ] || continue
  FILES+=("$prompt")
done

missing=0
names_file="$(mktemp)"
prompt_commands_file="$(mktemp)"
command_map_commands_file="$(mktemp)"
instructions_commands_file="$(mktemp)"
documented_commands_file="$(mktemp)"
skill_only_commands_file="$(mktemp)"
command_skill_map_file="$(mktemp)"

SKILL_ONLY_COMMANDS=(
)

cleanup() {
  rm -f "$names_file"
  rm -f "$prompt_commands_file"
  rm -f "$command_map_commands_file"
  rm -f "$instructions_commands_file"
  rm -f "$documented_commands_file"
  rm -f "$skill_only_commands_file"
  rm -f "$command_skill_map_file"
}
trap cleanup EXIT

check_file_refs() {
  local file="$1"
  local refs ref

  refs="$(grep -Eo '(\./)?scripts/[A-Za-z0-9._-]+\.sh' "$file" | sed 's#^\./##' | sort -u || true)"

  if [ -z "$refs" ]; then
    return
  fi

  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    if [ ! -f "$ref" ]; then
      echo "FAIL: $file references missing script entrypoint: $ref" >&2
      missing=1
    fi
  done <<< "$refs"
}

extract_frontmatter_value() {
  local file="$1"
  local key="$2"

  awk -F':' -v wanted="$key" '
    $1 == wanted {
      value = substr($0, index($0, ":") + 1)
      gsub(/^[[:space:]]+/, "", value)
      gsub(/[[:space:]]+$/, "", value)
      gsub(/^"/, "", value)
      gsub(/"$/, "", value)
      print value
      exit
    }
  ' "$file"
}

check_prompt_metadata() {
  local prompt="$1"
  local base field value

  base="$(basename "$prompt" .prompt.md)"

  if ! grep -q '^---$' "$prompt"; then
    echo "FAIL: $prompt is missing YAML frontmatter delimiters (---)." >&2
    missing=1
    return
  fi

  for field in name description agent; do
    if ! grep -q "^${field}:" "$prompt"; then
      echo "FAIL: $prompt is missing required frontmatter field: ${field}" >&2
      missing=1
    fi
  done

  value="$(extract_frontmatter_value "$prompt" "name")"
  if [ -z "$value" ]; then
    echo "FAIL: $prompt has empty or unreadable frontmatter name." >&2
    missing=1
    return
  fi

  if [ "$value" != "$base" ]; then
    echo "FAIL: $prompt frontmatter name ('$value') must match filename command ('$base')." >&2
    missing=1
  fi

  printf '%s\n' "$value" >> "$names_file"
}

collect_commands_from_doc_table() {
  local source_file="$1"
  local output_file="$2"

  awk -F'`' '
    /^\|[[:space:]]*`\/[^`]+`[[:space:]]*\|/ {
      command_text = $2
      sub(/^\/+/, "", command_text)
      split(command_text, parts, /[[:space:]]+/)
      if (parts[1] != "") {
        print parts[1]
      }
    }
  ' "$source_file" | sort -u > "$output_file"
}

collect_command_skill_map_from_command_map() {
  local source_file="$1"
  local output_file="$2"

  awk -F'|' '
    /^\|[[:space:]]*`\/[^`]+`[[:space:]]*\|/ {
      command_text = $2
      gsub(/`/, "", command_text)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", command_text)
      sub(/^\/+/, "", command_text)
      split(command_text, cmd_parts, /[[:space:]]+/)
      command_name = cmd_parts[1]

      skill_text = $5
      gsub(/`/, "", skill_text)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", skill_text)

      if (command_name != "") {
        print command_name "|" skill_text
      }
    }
  ' "$source_file" > "$output_file"
}

check_prompt_documented_in_both_docs() {
  local cmd="$1"

  if ! grep -Fxq "$cmd" "$command_map_commands_file"; then
    echo "FAIL: docs/COMMAND_MAP.md is missing command /${cmd}." >&2
    missing=1
  fi

  if ! grep -Fxq "$cmd" "$instructions_commands_file"; then
    echo "FAIL: copilot-instructions.md is missing command /${cmd}." >&2
    missing=1
  fi
}

check_documented_command_has_entrypoint() {
  local cmd="$1"

  if grep -Fxq "$cmd" "$prompt_commands_file"; then
    return
  fi

  if grep -Fxq "$cmd" "$skill_only_commands_file"; then
    return
  fi

  echo "FAIL: documented command /${cmd} has no prompt file and is not allowlisted as skill-only." >&2
  missing=1
}

check_mapped_skill_exists() {
  local cmd="$1"
  local skill="$2"
  local skill_file skill_name

  if [ -z "$skill" ] || [ "$skill" = "none" ]; then
    return
  fi

  skill_file=".github/skills/${skill}/SKILL.md"
  if [ ! -f "$skill_file" ]; then
    echo "FAIL: docs/COMMAND_MAP.md maps /${cmd} to missing skill file: ${skill_file}" >&2
    missing=1
    return
  fi

  skill_name="$(extract_frontmatter_value "$skill_file" "name")"
  if [ -z "$skill_name" ]; then
    echo "FAIL: $skill_file has empty or unreadable frontmatter name." >&2
    missing=1
    return
  fi

  if [ "$skill_name" != "$skill" ]; then
    echo "FAIL: $skill_file frontmatter name ('$skill_name') must match mapped skill directory ('$skill')." >&2
    missing=1
  fi
}

for file in "${FILES[@]}"; do
  [ -f "$file" ] || continue
  check_file_refs "$file"
done

for prompt in .github/prompts/*.prompt.md; do
  [ -f "$prompt" ] || continue
  check_prompt_metadata "$prompt"
done

duplicate_names="$(sort "$names_file" | uniq -d || true)"
if [ -n "$duplicate_names" ]; then
  echo "FAIL: duplicate prompt frontmatter names detected:" >&2
  echo "$duplicate_names" >&2
  missing=1
fi

sort -u "$names_file" > "$prompt_commands_file"

collect_commands_from_doc_table "docs/COMMAND_MAP.md" "$command_map_commands_file"
collect_commands_from_doc_table "copilot-instructions.md" "$instructions_commands_file"
collect_command_skill_map_from_command_map "docs/COMMAND_MAP.md" "$command_skill_map_file"

cat "$command_map_commands_file" "$instructions_commands_file" | sort -u > "$documented_commands_file"

for skill_only_command in "${SKILL_ONLY_COMMANDS[@]-}"; do
  [ -n "$skill_only_command" ] || continue
  printf '%s\n' "$skill_only_command" >> "$skill_only_commands_file"
done

if [ -s "$skill_only_commands_file" ]; then
  sort -u "$skill_only_commands_file" -o "$skill_only_commands_file"
fi

while IFS= read -r command_name; do
  [ -n "$command_name" ] || continue
  check_prompt_documented_in_both_docs "$command_name"
done < "$prompt_commands_file"

while IFS= read -r documented_command; do
  [ -n "$documented_command" ] || continue
  check_documented_command_has_entrypoint "$documented_command"
done < "$documented_commands_file"

while IFS='|' read -r mapped_command mapped_skill; do
  [ -n "$mapped_command" ] || continue
  check_mapped_skill_exists "$mapped_command" "$mapped_skill"
done < "$command_skill_map_file"

for required_command in add-requirement codex-resume codex-work-on codex-code-review status start-work work-on; do
  if [ ! -f ".github/prompts/${required_command}.prompt.md" ]; then
    echo "FAIL: missing required representative prompt file .github/prompts/${required_command}.prompt.md" >&2
    missing=1
    continue
  fi
  check_prompt_documented_in_both_docs "$required_command"
done

if [ "$missing" -ne 0 ]; then
  echo "" >&2
  echo "Command entrypoint guard failed." >&2
  echo "Fix script references, prompt frontmatter metadata, and command docs so slash-command routing stays consistent." >&2
  exit 1
fi

echo "PASS: Command entrypoints and prompt metadata are valid."
