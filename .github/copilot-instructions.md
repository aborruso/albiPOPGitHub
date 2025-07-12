# Copilot Instructions for albiPOPGitHub

## Architettura e componenti principali
- Il progetto è organizzato per cartelle, ognuna rappresenta un "albo" o una fonte di dati (es: `c_d003`, `c_a026`, ecc.).
- Ogni cartella contiene uno script principale `.sh` che gestisce il workflow di scraping, normalizzazione e generazione feed RSS/XML.
- Gli script bash spesso invocano script Node.js (es: Puppeteer) per la navigazione headless e scraping, e utilizzano utility CLI come `mlr`, `jq`, `xmlstarlet`, `scrape`.
- I feed generati vengono copiati nella cartella `docs/<nome>/feed.xml` per la pubblicazione.

## Workflow di sviluppo e automazione
- Ogni fonte ha un workflow GitHub Actions dedicato in `.github/workflows/<nome>.yml`.
- Gli script possono essere eseguiti manualmente o tramite `crontab` su server Linux.
- La pubblicazione dei feed avviene tramite copia in `docs/` e pubblicazione HTTP.

## Convenzioni e pattern specifici
- Gli script bash sono il punto di ingresso: eseguono controlli di raggiungibilità, chiamano Node.js per scraping, normalizzano dati e generano feed.
- I file di configurazione per le fonti (es: `feeds.toml`) sono usati per parametri e mapping.
- Utility custom come `scrape` sono posizionate in `bin/` e richiamate dagli script.
- Il `$PATH` deve includere `/home/<utente>/.local/bin` per tool Python come `yq`/`xq`.

## Dipendenze e integrazioni
- Dipendenze principali: `mlr`, `xmlstarlet`, `jq`, `scrape`, `puppeteer`, `chromium-browser`, `yq`.
- Node.js e Python sono usati per scraping e manipolazione dati.
- I feed XML sono pubblicati per automazioni esterne (es: IFTTT).

## Esempi chiave
- Script principale: `c_d003/c_d003.sh` → chiama `c_d003.js` → genera `docs/c_d003/feed.xml`.
- Configurazione: `c_a546/feeds.toml`.
- Workflow GitHub Actions: `.github/workflows/c_d003.yml`.

## Note operative
- Verifica sempre la raggiungibilità delle fonti prima di eseguire scraping.
- Aggiorna le dipendenze di sistema e Node.js secondo le istruzioni in `README.md`.
- I file in `docs/` sono output pubblici, non modificarli manualmente.

---
Per dettagli su una fonte specifica, consulta lo script `.sh` e il relativo workflow YAML.
