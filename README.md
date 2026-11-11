# amovah/skills

Personal agent skills in the portable `SKILL.md` format, packaged as a
[Claude Code](https://claude.com/claude-code) plugin.

## Install

### Claude Code

```
/plugin marketplace add amovah/skills
/plugin install amovah@amovah-skills
```

Skills then invoke as `/amovah:<skill-name>`.

### OpenAI Codex CLI

Codex is the one agent that needs more than dropping the files in place —
parallel subagent dispatch sits behind a feature flag. The script does the
install *and* the config:

```sh
curl -fsSL https://raw.githubusercontent.com/amovah/skills/master/install-codex.sh | sh
```

Three steps, in order:

1. **Clones** this repo to `~/.local/share/amovah-skills` — or `git pull`s it if
   the clone already exists.
2. **Symlinks** every skill under `skills/` into `~/.agents/skills/`, the shared
   directory Codex reads. Symlinks rather than copies, so a later `git pull` in
   the clone updates what Codex loads with no reinstall.
3. **Sets** `multi_agent = true` under `[features]` in `~/.codex/config.toml`,
   preserving the rest of the file and backing it up to `config.toml.bak` first.

Re-running updates rather than duplicating. Restart Codex afterwards.

To read the script before running it — a good habit with any `curl | sh`:

```sh
curl -fsSL -O https://raw.githubusercontent.com/amovah/skills/master/install-codex.sh
less install-codex.sh
sh install-codex.sh
```

To run only one half:

| Command | Clone + symlink | Edit config |
|---------|-----------------|-------------|
| `sh install-codex.sh` | yes | yes |
| `sh install-codex.sh --skills-only` | yes | no |
| `sh install-codex.sh --config-only` | no | yes |

`--config-only` never touches git or the network. Also `--uninstall` (removes
the symlinks, leaves the feature flag — other skills may rely on it) and
`--help`. Paths are overridable via `AMOVAH_SKILLS_DIR`, `CODEX_SKILLS_DIR`,
and `CODEX_HOME`.

Doing it by hand instead is two steps — clone and symlink as below, then add to
`~/.codex/config.toml`:

```toml
[features]
multi_agent = true
```

### Every other agent — clone and symlink

Most agents read the shared `~/.agents/skills/` directory, so one clone plus a
symlink per skill covers Codex CLI, Cursor, Gemini CLI, opencode, and Amp at once:

```bash
git clone https://github.com/amovah/skills.git ~/.agent-skills/amovah
mkdir -p ~/.agents/skills
for d in ~/.agent-skills/amovah/skills/*/; do
  ln -s "$d" ~/.agents/skills/"$(basename "$d")"
done
```

For an agent that does not read `~/.agents/skills/`, symlink into its own
directory instead:

| Agent | Global skills directory | Parallel subagents |
|-------|------------------------|--------------------|
| Claude Code | `~/.claude/skills/` (or install the plugin, above) | `Task` / `Agent` tool |
| OpenAI Codex CLI | `~/.agents/skills/` | needs `[features] multi_agent = true` in `~/.codex/config.toml` (see above) — enables `spawn_agent` / `wait_agent` / `close_agent` |
| Cursor (v2.4+) | `~/.cursor/skills/` or `~/.agents/skills/` | background / subagent dispatch |
| Gemini CLI (v0.26.0+) | `~/.gemini/skills/` or `~/.agents/skills/` | `invoke_agent` with `agent_name: "generalist"` |
| Google Antigravity | `~/.gemini/antigravity/global_skills/` | `invoke_subagent` |
| opencode | `~/.config/opencode/skills/` (also reads `~/.claude/skills/` and `~/.agents/skills/`) | subagents via the task tool |
| Amp | `~/.config/agents/skills/` (also reads `~/.claude/skills/`) | subagent dispatch |

Per-project instead of global: use the same layout under the project root —
`.agents/skills/`, `.claude/skills/`, `.cursor/skills/`, `.opencode/skills/`,
or `<workspace>/.agent/skills/` for Antigravity.

Outside Claude Code the skills are invoked by name, without the `amovah:`
prefix.

## Skills

| Skill | What it does |
|-------|--------------|
| `discuss` | Slash-command only. Switches into plan mode for a discussion-first session — explores the code, answers questions, weighs approaches — and writes no plan until you explicitly ask for one. |

## License

MIT — see [LICENSE](LICENSE).
