#!/bin/bash
# deploy.sh — Sync skills from GitHub to OpenClaw on the VPS
#
# Usage:
#   ./deploy.sh              # deploy all skills
#   ./deploy.sh odoo-requirement-analyst   # deploy one specific skill

set -e

GITHUB_RAW="https://raw.githubusercontent.com/jgarcia1982/odoo-ai-analyst/main"
OPENCLAW_SKILLS="$HOME/.openclaw/skills"

# ── Helpers ──────────────────────────────────────────────────────────────────

fetch() {
  local remote="$1"
  local local_path="$2"
  mkdir -p "$(dirname "$local_path")"
  curl -fsSL "$remote" -o "$local_path"
  echo "  ✓ $local_path"
}

deploy_skill() {
  local skill="$1"
  echo "→ Deploying $skill..."

  # Always fetch SKILL.md
  fetch "$GITHUB_RAW/skills/$skill/SKILL.md" \
        "$OPENCLAW_SKILLS/$skill/SKILL.md"

  # Fetch all files inside references/ if the folder exists in the remote
  # We maintain a manifest per skill to know which reference files to pull
  local manifest="$GITHUB_RAW/skills/$skill/.files"
  local manifest_tmp
  manifest_tmp=$(mktemp)

  if curl -fsSL "$manifest" -o "$manifest_tmp" 2>/dev/null; then
    while IFS= read -r file; do
      [[ -z "$file" || "$file" == \#* ]] && continue
      fetch "$GITHUB_RAW/skills/$skill/$file" \
            "$OPENCLAW_SKILLS/$skill/$file"
    done < "$manifest_tmp"
  fi

  rm -f "$manifest_tmp"
  echo "  Done."
}

# ── Main ─────────────────────────────────────────────────────────────────────

if [[ -n "$1" ]]; then
  deploy_skill "$1"
else
  echo "Deploying all skills..."
  for skill_dir in skills/*/; do
    skill=$(basename "$skill_dir")
    # Only deploy folder-based skills (those with a SKILL.md)
    if [[ -f "$skill_dir/SKILL.md" ]]; then
      deploy_skill "$skill"
    fi
  done
fi

echo ""
echo "Deploy complete."
