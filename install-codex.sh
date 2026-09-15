#!/bin/sh
# Install the amovah skills (batch-plan, batch-run, discuss) for OpenAI Codex CLI.
#
#   curl -fsSL https://raw.githubusercontent.com/amovah/skills/master/install-codex.sh | sh
#
# Codex is the only supported agent that needs configuration beyond dropping the
# skill files in place: parallel subagent dispatch sits behind a feature flag,
# and without it batch-run has nothing to dispatch a batch to. This script does
# both halves — links the skills into ~/.agents/skills and sets
# multi_agent = true in ~/.codex/config.toml.
#
# Safe to re-run. The config file is backed up before any edit.
#
# Flags:
#   --config-only   only set the feature flag, do not install skills
#   --skills-only   only install skills, do not touch the config
#   --uninstall     remove the skill symlinks (leaves the config flag alone)
#   --help          show this message

set -eu

REPO_URL="https://github.com/amovah/skills.git"
SKILLS="batch-plan batch-run discuss"

CLONE_DIR="${AMOVAH_SKILLS_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/amovah-skills}"
SKILLS_DIR="${CODEX_SKILLS_DIR:-$HOME/.agents/skills}"
CODEX_CONFIG="${CODEX_HOME:-$HOME/.codex}/config.toml"

DO_SKILLS=1
DO_CONFIG=1
MODE=install

log()  { printf '  %s\n' "$*"; }
ok()   { printf '\033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Install the amovah skills (batch-plan, batch-run, discuss) for OpenAI Codex CLI.

  curl -fsSL https://raw.githubusercontent.com/amovah/skills/master/install-codex.sh | sh

Links the skills into ~/.agents/skills and sets multi_agent = true in
~/.codex/config.toml, which is what enables the parallel subagent dispatch
batch-run needs. Safe to re-run; the config file is backed up before any edit.

Flags:
  --config-only   only set the feature flag, do not install skills
  --skills-only   only install skills, do not touch the config
  --uninstall     remove the skill symlinks (leaves the config flag alone)
  --help          show this message

Environment:
  AMOVAH_SKILLS_DIR   clone location  (default: ~/.local/share/amovah-skills)
  CODEX_SKILLS_DIR    skills location (default: ~/.agents/skills)
  CODEX_HOME          codex config dir (default: ~/.codex)
EOF
  exit 0
}

for arg in "$@"; do
  case "$arg" in
    --config-only) DO_SKILLS=0 ;;
    --skills-only) DO_CONFIG=0 ;;
    --uninstall)   MODE=uninstall ;;
    --help|-h)     usage ;;
    *)             die "unknown flag: $arg (try --help)" ;;
  esac
done

have() { command -v "$1" >/dev/null 2>&1; }

# --------------------------------------------------------------------- skills

clone_or_update() {
  if [ -d "$CLONE_DIR/.git" ]; then
    log "updating clone at $CLONE_DIR"
    git -C "$CLONE_DIR" pull --ff-only --quiet
  else
    log "cloning into $CLONE_DIR"
    mkdir -p "$(dirname "$CLONE_DIR")"
    git clone --quiet --depth 1 "$REPO_URL" "$CLONE_DIR"
  fi
}

install_skills() {
  have git || die "git is required to install the skills"
  clone_or_update
  mkdir -p "$SKILLS_DIR"

  for skill in $SKILLS; do
    target="$CLONE_DIR/skills/$skill"
    link="$SKILLS_DIR/$skill"

    [ -d "$target" ] || die "missing $target — the clone looks incomplete"

    if [ -L "$link" ]; then
      rm "$link"
    elif [ -e "$link" ]; then
      warn "$link exists and is not a symlink — moving it to $link.bak"
      mv "$link" "$link.bak"
    fi

    ln -s "$target" "$link"
    log "linked $skill"
  done

  ok "skills installed in $SKILLS_DIR"
}

uninstall_skills() {
  for skill in $SKILLS; do
    link="$SKILLS_DIR/$skill"
    if [ -L "$link" ]; then
      rm "$link"
      log "unlinked $skill"
    else
      log "$skill was not linked"
    fi
  done
  ok "skills removed (clone left at $CLONE_DIR, config flag untouched)"
}

# --------------------------------------------------------------------- config
#
# Classify the current state of the multi_agent key inside the [features] table,
# then apply the smallest edit that reaches multi_agent = true.

config_state() {
  [ -f "$CODEX_CONFIG" ] || { echo NO_FILE; return; }

  awk '
    /^[[:space:]]*\[/ { section = $0; sub(/[[:space:]]*#.*$/, "", section); gsub(/[[:space:]]/, "", section) }
    section == "[features]" && /^[[:space:]]*multi_agent[[:space:]]*=/ {
      found = 1
      if ($0 ~ /=[[:space:]]*true/) value = 1
    }
    section == "[features]" { has_section = 1 }
    END {
      if (found && value)  { print "ALREADY_TRUE"; exit }
      if (found)           { print "KEY_FALSE";    exit }
      if (has_section)     { print "NO_KEY";       exit }
      print "NO_SECTION"
    }
  ' "$CODEX_CONFIG"
}

backup_config() {
  cp "$CODEX_CONFIG" "$CODEX_CONFIG.bak"
  log "backed up existing config to $CODEX_CONFIG.bak"
}

configure_codex() {
  mkdir -p "$(dirname "$CODEX_CONFIG")"
  state=$(config_state)

  case "$state" in
    ALREADY_TRUE)
      ok "multi_agent already enabled in $CODEX_CONFIG"
      return
      ;;
    NO_FILE)
      printf '[features]\nmulti_agent = true\n' > "$CODEX_CONFIG"
      log "created $CODEX_CONFIG"
      ;;
    NO_SECTION)
      backup_config
      printf '\n[features]\nmulti_agent = true\n' >> "$CODEX_CONFIG"
      log "appended a [features] table"
      ;;
    NO_KEY)
      backup_config
      awk '
        { print }
        !done && /^[[:space:]]*\[features\]/ {
          print "multi_agent = true"
          done = 1
        }
      ' "$CODEX_CONFIG.bak" > "$CODEX_CONFIG"
      log "added multi_agent to the existing [features] table"
      ;;
    KEY_FALSE)
      backup_config
      awk '
        /^[[:space:]]*\[/ { section = $0; gsub(/[[:space:]]/, "", section) }
        section == "[features]" && /^[[:space:]]*multi_agent[[:space:]]*=/ {
          print "multi_agent = true"
          next
        }
        { print }
      ' "$CODEX_CONFIG.bak" > "$CODEX_CONFIG"
      log "flipped multi_agent to true"
      ;;
    *)
      die "could not read $CODEX_CONFIG"
      ;;
  esac

  ok "multi_agent enabled in $CODEX_CONFIG"
}

# --------------------------------------------------------------------- driver

if [ "$MODE" = uninstall ]; then
  uninstall_skills
  log "to disable the feature flag, edit $CODEX_CONFIG by hand —"
  log "other skills may rely on multi_agent too"
  exit 0
fi

if [ "$DO_SKILLS" = 1 ]; then install_skills; fi
if [ "$DO_CONFIG" = 1 ]; then configure_codex; fi

have codex || warn "codex CLI not found on PATH — install it to use the skills"

printf '\n'
ok "done — restart Codex, then ask it to use batch-plan, batch-run, or discuss"
