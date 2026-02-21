# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

## Project Overview

AlbiPOPGitHub: RSS feed generator for Italian municipal bulletin boards (albi pretori). Each municipality has a dedicated folder (named with IPA code like `c_d003`, `c_a546`) containing scripts that scrape bulletin board data and generate RSS feeds published to `docs/`.

## Architecture

### Per-Municipality Structure

Each municipality folder (`c_XXXXX/`) contains:
- `.sh` script: main entry point, orchestrates scraping and feed generation
- Optional `.js` file: Puppeteer script for headless browser scraping (used when site requires JS interaction)
- Optional `feeds.toml`: configuration for `rsspls` tool (simpler CSS-based scraping)

### Two Scraping Patterns

**Pattern A - Full bash pipeline** (e.g., `c_d003`):
1. HTTP check for site availability
2. Puppeteer script saves HTML to `tmp.html`
3. Bash pipeline: `scrape` → `xq` → `mlr` → extract data to CSV/JSON
4. `xmlstarlet` constructs RSS from `risorse/feedTemplate.xml`
5. Copy final feed to `docs/<iPA>/feed.xml`

**Pattern B - rsspls** (e.g., `c_a546`):
1. `feeds.toml` defines CSS selectors for feed items
2. `rsspls -c feeds.toml` generates feed directly
3. Output configured to `docs/<iPA>/feed.xml`

### Tools Used

CLI utilities in `bin/`:
- `mlr`: Miller, for CSV/JSON data transformation
- `scrape`: HTML scraper using XPath/CSS selectors
- `rsspls`: RSS feed generator from web pages
- Standard: `xmlstarlet`, `jq`, `xq` (from Python `yq` package)

Node.js:
- `puppeteer` for headless Chrome automation
- `chromium-browser` as headless browser

## Common Commands

### Run a single municipality scraper

```bash
cd c_d003
./c_d003.sh
```

### Test with rsspls

```bash
rsspls -c c_a546/feeds.toml
```

### Install dependencies (GitHub Actions pattern)

```bash
mkdir -p ~/bin
cp bin/mlr ~/bin
cp bin/scrape ~/bin
chmod +x ~/bin/mlr ~/bin/scrape
sudo apt-get install xmlstarlet
pip3 install --user yq
```

Ensure `~/.local/bin` is in PATH for `xq` from `yq`.

### Validate feeds

Check that `docs/<iPA>/feed.xml` is valid RSS:

```bash
xmlstarlet val docs/c_d003/feed.xml
```

### Git operations

Always pull with rebase to avoid divergent branches:

```bash
git pull --rebase
```

If there are uncommitted changes, commit them first, then pull and push:

```bash
git add .
git commit -m "message"
git pull --rebase
git push
```

### Traceability workflow for fixes

When you identify a useful problem and implement a fix, follow this order:
1. Open a GitHub issue first to track the problem.
2. Implement the fix and commit.
3. Push using a commit message with a closing keyword (for example `Closes #123`) so the issue is automatically closed.

## Workflows and Automation

- Each municipality has `.github/workflows/<iPA>.yml`
- Workflows triggered by: `workflow_dispatch`, `repository_dispatch`, or scheduled cron
- Workflows copy tools to `~/bin`, install deps, run the municipality script
- Generated feeds in `docs/` are served via GitHub Pages

## Key Files

- `risorse/feedTemplate.xml`: RSS skeleton with Creative Commons license
- `risorse/docs/rsspls.md`: documentation on rsspls usage
- `risorse/prompt_*.md`: AI prompt templates for creating new municipality scrapers
- `LOG.md`: project changelog, most recent entries first (YYYY-MM-DD format)

## Development Notes

- Always check site availability before scraping (`curl -s -L -o /dev/null -w "%{http_code}"`)
- Municipality metadata (title, coordinates, IPA code) is hardcoded at top of `.sh` scripts
- RSS feed metadata uses AlboPOP spec categories (type, municipality, province, region, lat/lon, etc.)
- Scrapers run `git pull` at start to sync latest code
- Output always goes to `docs/<iPA>/` for publication
- Use `set -x -e -u -o pipefail` in bash scripts for debugging and error handling

## Testing Pattern

When adding a new municipality:
1. Identify IPA code (`c_XXXXX`)
2. Choose scraping pattern (Puppeteer pipeline vs rsspls)
3. Create folder and script based on similar existing municipality
4. Test locally to verify feed generation
5. Add GitHub workflow in `.github/workflows/`
6. Update `LOG.md` with entry
