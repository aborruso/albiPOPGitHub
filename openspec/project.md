# Project Context

## Purpose

AlbiPOPGitHub generates RSS feeds from Italian municipal bulletin boards (albi pretori). Each municipality's official notices are scraped and converted into standard RSS feeds, making them accessible via feed readers and automation tools like IFTTT. This improves civic transparency by enabling citizens to easily monitor public notices from their municipalities.

## Tech Stack

**Core Technologies:**
- Bash: primary orchestration scripts per municipality
- Node.js: optional Puppeteer automation for JS-heavy sites (currently used in `c_d003/`)
- Python: `yq` package provides `xq` tool for XML/HTML processing

**CLI Tools:**
- `mlr` (Miller): CSV/JSON transformation and cleanup
- `xmlstarlet`: XML edits for RSS channel/items
- `jq`: JSON querying and filtering
- `scrape` (scrape-cli): HTML extraction via XPath/CSS selectors
- `rsspls`: RSS feed generation from CSS selectors (`feeds.toml`)
- `xq`: XML/HTML to JSON conversion (from Python `yq`)

**Pinned binaries (preferred):**
- `bin/` contains project-pinned builds of `mlr`, `rsspls`, `scrape` (use these over system copies)

**Browsers:**
- `chromium-browser`: headless Chrome for Puppeteer (when JS rendering is required)

**Infrastructure:**
- GitHub Actions: scheduled scraping workflows
- GitHub Pages: RSS feed publication via `docs/` directory

## Project Conventions

### Code Style

**Bash scripts:**
- Start with `#!/bin/bash`
- Prefer `set -euo pipefail`; add `set -x` when you need trace/debug output
- Check site availability before scraping: `curl -s -L -o /dev/null -w "%{http_code}"`
- Define municipality metadata as variables at top of script (title, description, coordinates, IPA code, etc.)
- Use `$folder` variable for script's directory: `folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`

**Naming conventions:**
- Municipality folders: `c_XXXXX` where XXXXX is the IPA code (lowercase)
- Main script: `c_XXXXX.sh`
- Puppeteer scripts: `c_XXXXX.js` (only when needed)
- Configuration files: `feeds.toml` (rsspls pattern)
- Output: always `docs/<iPA>/feed.xml`

### Architecture Patterns

**Pattern A - Full Bash Pipeline** (for complex sites requiring JS):
1. HTTP availability check
2. Puppeteer script navigates site, saves HTML to `tmp.html`
3. Bash pipeline extracts data: `scrape` → `xq` → `mlr` → CSV/JSON
4. `xmlstarlet` builds RSS from template (`risorse/feedTemplate.xml`)
5. Insert metadata and items into XML
6. Copy to `docs/<iPA>/feed.xml`

**Pattern B - rsspls** (for simpler sites):
1. Configure CSS selectors in `feeds.toml`
2. Run `rsspls -c feeds.toml`
3. Tool generates feed directly to `docs/<iPA>/feed.xml`

**Folder structure per municipality:**
```
c_XXXXX/
├── c_XXXXX.sh          # Main script (required)
├── c_XXXXX.js          # Puppeteer script (Pattern A only)
├── feeds.toml          # rsspls config (Pattern B only)
├── rawdata/            # Created at runtime
├── processing/         # Created at runtime
└── tmp.html            # Created at runtime (Pattern A)
```

### Testing Strategy

**Local testing:**
1. Run script locally: `cd c_XXXXX && ./c_XXXXX.sh`
2. Validate generated RSS: `xmlstarlet val docs/c_XXXXX/feed.xml`
3. Check feed in feed reader or browser
4. Verify all metadata fields are populated correctly

**Deployment testing:**
1. Test GitHub Actions workflow manually via `workflow_dispatch`
2. Monitor workflow logs for errors
3. Verify feed accessibility on GitHub Pages

### Git Workflow

- Main branch: `master`
- Direct commits to master for most changes
- Update `LOG.md` with date and brief description of changes (most recent at top)
- Commit messages: concise, describing what changed
- OpenSpec workflow for major changes (see `openspec/AGENTS.md`)

## Domain Context

**Italian Public Administration:**
- **Albo Pretorio**: official bulletin board where municipalities publish legal notices, announcements, and administrative acts
- **IPA Code**: Indice delle Pubbliche Amministrazioni - unique identifier for each public administration entity
- **AlboPOP Spec**: RSS feed specification for standardizing Italian municipal bulletin board feeds (http://albopop.it/specs)

**RSS Metadata Categories (AlboPOP spec):**
- `type`: entity type (e.g., "Comune")
- `municipality`: municipality name
- `province`: province name
- `region`: Italian region
- `latitude`/`longitude`: geographic coordinates
- `country`: always "Italia"
- `name`: full official name (e.g., "Comune di Cori")
- `uid`: unique identifier (e.g., "istat:059006")

## Important Constraints

**Technical:**
- Municipality websites must be publicly accessible (HTTP 200 response)
- Scripts must handle pagination, session cookies, and AJAX-loaded content
- RSS feeds limited to recent items (typically 50-100 per feed)
- Tools in `bin/` are pre-compiled binaries (must match architecture)
- `~/.local/bin` must be in PATH for `xq` command

**External dependencies:**
- Municipality websites can change structure without notice
- Some sites require JavaScript (hence Puppeteer)
- Rate limiting may affect scraping frequency
- GitHub Actions has execution time limits

**Data Quality:**
- Titles must be escaped for XML: `&`, `<`, `>`, `'`, `"`
- Dates must parse to RFC 822 format for RSS pubDate
- Links must be absolute URLs (prepend base URL if needed)

## External Dependencies

**Municipality Websites:**
- Each municipality has different CMS/platform
- Common platforms: Urbi (cloud.urbi.it), Halley, various custom systems
- No formal API - scraping is required

**GitHub Services:**
- GitHub Actions: for scheduled execution
- GitHub Pages: for serving generated feeds at `https://aborruso.github.io/albiPOPGitHub/`

**Feed Distribution:**
- AlboPOP.it: aggregator for Italian municipal feeds
- IFTTT/Zapier: users create automations from feeds
- Feed readers: Feedly, Feedbin, etc.
