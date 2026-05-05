# LOG.md

## 2026-05-05

- Audit workflow: identificati 2 workflow in fallimento continuo (c_a965, c_e047) e 1 intermittente (c_a638)
- c_a965 (Bondeno FE): risolto errore TLS `UnknownIssuer` — aggiornato `bin/rsspls` buildato da `main` di wezm/rsspls (post-merge branch `disable-cert-verify`) e aggiunta opzione `insecure_disable_certificate_verification = true` in `feeds.toml`
- c_e047 (Giovinazzo BA): riscritto scraper — eliminata paginazione (ora 15 item su pagina singola), aggiunto cookie jar; server blocca IP GitHub Actions, routing via Cloudflare Worker `mio-proxy` in corso di ottimizzazione (Smart Placement abilitato, in attesa di adattamento geografico)
- c_a638 (Barcellona PdG ME): URL invariato, problema di timeout intermittenti lato server comunale (nessuna modifica necessaria)
- mio-proxy Worker: deployata versione aggiornata con endpoint `/normattiva` (doppia richiesta init+target per sessione PHP) e Smart Placement abilitato

## 2026-01-08

- c_a638: aggiunto retry logic a rsspls (3 tentativi, delay 10s) per gestire errori di timeout transitori
- CLAUDE.md: aggiunta sezione Git operations con best practice per pull --rebase

## 2026-01-05

- c_a965: aggiunto retry logic a rsspls (3 tentativi, delay 10s) per gestire errori di timeout transitori

## 2025-12-26

- cdtdr: migliorati retry automatici curl (5 tentativi, delay 10s, flag --retry-all-errors) per connection reset e errori di rete transitori

## 2025-12-24

- Valutazione complessiva progetto salvata in `project/evaluation.md`

## 2025-07-12

- Creazione del file di log
- Aggiunta comune San Giuseppe Jato, codice iPA `c_h933`
