<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

# Repository Guidelines

## Project Structure & Module Organization
- Municipal scrapers live in folders named after the iPA code (e.g., `c_l109/`, `c_e047/`). Each contains the script that builds that municipality’s RSS feed plus working dirs such as `rawdata/` and `processing/`.
- Generated feeds are published under `docs/<ipa>/feed.xml`, served via GitHub Pages. Keep outputs confined there.
- Shared assets are in `risorse/` (e.g., `feedTemplate.xml` and archive lists). Reuse these instead of duplicating templates.
- Utility binaries (miller, rsspls, scrape) sit in `bin/`; prefer these pinned versions over system-wide tools to avoid regressions.

## Build, Test, and Development Commands
- Generate a single feed locally: `cd c_l109 && chmod +x ./c_l109.sh && ./c_l109.sh` (outputs to `docs/c_l109/feed.xml`).
- Refresh all dependencies used in CI (Ubuntu): `sudo apt-get install xmlstarlet && pip install --user yq==3.4.3 xmltodict==0.13.0 && uv tool install scrape-cli` (mirrors workflow steps).
- Quick XML sanity check: `xmlstarlet val --well-formed docs/c_l109/feed.xml`.
- Optional: dry-run rsspls config in `test/feeds.toml` with `./bin/rsspls --config test/feeds.toml` to verify parser compatibility.

## Coding Style & Naming Conventions
- Bash scripts should start with `#!/bin/bash` and `set -euo pipefail`; keep commands pipe-safe and quote variables.
- Name new municipality folders and scripts with the lowercase iPA code (`c_xxxx`), and write outputs to the matching `docs/<ipa>/` directory.
- Prefer lowercase variable names for paths, uppercase for constants/metadata (see existing scripts). Avoid hard-coding secrets or absolute local paths.
- Keep data cleaning steps explicit (mlr/jq/xq pipelines) and add brief inline comments only where the flow is non-obvious.

## Testing Guidelines
- After running a scraper, confirm the feed renders and dates are parsed: open `docs/<ipa>/feed.xml` in a reader or run the `xmlstarlet` well-formedness check above.
- If you alter selectors/XPath, capture at least one sample page in `rawdata/` and compare item counts before/after (`wc -l rawdata/<ipa>_temp.json`).
- No formal coverage target exists; prioritize smoke checks that the item list is non-empty and GUID/link fields are absolute URLs.

## Commit & Pull Request Guidelines
- Use concise, action-focused subjects that include the iPA code; common patterns: `feat: c_l109 add pagination handling`, `fix: c_e047 pin scrape user-agent`, or timestamped data bumps (`c_l109, Terlizzi: 2025-11-28T05:30:00Z`).
- In PRs, describe the data source change, the exact page/selector adjusted, and how you validated the resulting feed (command output or screenshot). Link related issue or municipality request when available.
- Avoid committing generated feeds unrelated to your change set; limit diff noise to the municipalities you touched.
- When a useful issue is discovered and solved, follow this order for traceability: open a GitHub issue first, then commit and push with a closing keyword (for example `Closes #123`) so the issue is closed by the fix commit.

## Security & Configuration Tips
- Secrets such as IFTTT tokens are injected via GitHub Actions (`SUPER_SECRET`); never hard-code them in scripts or configs.
- When adding new workflows, mirror existing ones under `.github/workflows/`, reusing the dependency install block to keep tool versions aligned.
- When creating issues from CLI, avoid shell interpolation bugs: do not pass Markdown with backticks directly in double quotes to `--body`. Prefer `--body-file` or a single-quoted heredoc.
- Safe pattern example:
  `cat <<'EOF' > /tmp/issue.md`
  `...markdown with backticks...`
  `EOF`
  `gh issue create --title "..." --body-file /tmp/issue.md`
