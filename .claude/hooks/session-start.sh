#!/usr/bin/env bash
# SessionStart hook: surface repo state AND self-heal the skill environment.
# The remote container is reprovisioned periodically, wiping ~/.claude (skills,
# CLAUDE.md, creative-profile). This hook detects the wipe and restores from
# DefinitelyScott/Scott-Workspace automatically — no manual steps.

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || true

echo "## Repository state"
echo
echo "Branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'not a git repo')"
git log --oneline -3 2>/dev/null || true
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  echo "Uncommitted changes present:"
  git status --short | head -10
fi
echo

# ── Self-healing skill restore ────────────────────────────────────────────────
SKILLS_DIR="$HOME/.claude/skills"
SKILL_COUNT=$(ls "$SKILLS_DIR" 2>/dev/null | wc -l)

if [ "$SKILL_COUNT" -lt 50 ]; then
  echo "## ⚠ Skill library missing ($SKILL_COUNT skills found) — container was likely reprovisioned"
  RESTORE_DIR="$(mktemp -d)"
  if git clone --depth 1 --quiet https://github.com/DefinitelyScott/Scott-Workspace.git "$RESTORE_DIR" 2>/dev/null; then
    KIT="$RESTORE_DIR/claude-setup"
    mkdir -p "$SKILLS_DIR"
    # Fast path: memory files + custom skills (seconds)
    [ -f "$KIT/CLAUDE.md" ]           && cp "$KIT/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
    [ -f "$KIT/creative-profile.md" ] && cp "$KIT/creative-profile.md" "$HOME/.claude/creative-profile.md"
    [ -d "$KIT/skills" ]              && cp -rn "$KIT/skills/"* "$SKILLS_DIR/" 2>/dev/null
    # Slow path: full ~320-skill install from upstream sources, in background
    if [ -x "$KIT/install-skills.sh" ]; then
      nohup bash "$KIT/install-skills.sh" > /tmp/skill-restore.log 2>&1 &
      echo "Restored CLAUDE.md, creative-profile.md, and custom skills."
      echo "Full skill install running in background (log: /tmp/skill-restore.log)."
      echo "Newly installed skills load on the NEXT session start."
    fi
  else
    echo "Could not clone Scott-Workspace (repo may not be in this session's authorized set)."
    echo "ACTION FOR CLAUDE: call add_repo for DefinitelyScott/Scott-Workspace, then run"
    echo "claude-setup/install-skills.sh from it and copy CLAUDE.md + creative-profile.md to ~/.claude/."
  fi
  echo
else
  echo "Skill library present: $SKILL_COUNT skills."
  echo
fi

# ── Stack detection ───────────────────────────────────────────────────────────
if [ -f package.json ]; then
  echo "Stack: Node.js (package.json present)"
elif [ -f pyproject.toml ] || [ -f requirements.txt ]; then
  echo "Stack: Python"
else
  echo "No stack detected — project not yet scaffolded."
fi
