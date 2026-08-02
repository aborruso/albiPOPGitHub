# LOG.md

## 2026-08-02

- c_h933 (San Giuseppe Jato PA): feed fermo dal 28/07 — dal rinnovo del certificato (27/07) il server non invia più l'intermedio Actalis, la catena non si chiude e sia il controllo con curl (exit 60) sia `scrape` si fermano sull'errore TLS. Download spostato su `curl -k` con HTML passato a `scrape` da file. Corretta anche la data degli item, sbagliata da prima: si leggeva `td[3].div[0]`, che è il numero di registro generale e non una data, e tutti e 42 gli item avevano `pubDate(error)`; ora si usa `td[4].div[0]`, la data di inizio pubblicazione. Sostituito l'`if [ $code -eq 200 ]` che usciva 0 in silenzio con un fail-fast, e aggiunte guardie prima della pubblicazione: nessun dato estratto, feed senza item o date non convertite fermano lo script senza toccare il feed buono. Chiude #13
- c_a070 (Agira EN): fallimenti intermittenti del workflow (01/08 e 02/08, in fascia serale) — la fonte non accetta connessioni dagli IP dei runner GitHub (`client error (Connect)`, timeout), mentre da locale risponde 200. Aggiunto fallback via secret `PROXY_URL` sul modello di c_e036, adattato a rsspls: tentativo diretto, poi `feeds.toml` temporaneo fuori dal repo (il workflow fa `git add -A`) con url proxato e output assoluto. Il prefisso proxy viene rimosso dal feed prima della pubblicazione, con guardia `grep -F` che blocca il `cp` se restasse: il valore del secret non entra in `docs/` né nella history. Marcatori `fetch: diretto` / `fetch: via proxy` nel log. Passato `PROXY_URL` all'env del workflow. Chiude #12

## 2026-07-08

- c_e036 (Ginosa TA): feed fermo dal 14/06 — il sito halleyweb blocca gli IP dei runner GitHub (`code=000`) e la vecchia guardia `if [ code -eq 200 ]` saltava tutto in silenzio lasciando il workflow verde. Aggiunta funzione `fetch_url` con fallback via secret `PROXY_URL`, rigenerazione feed solo se ci sono dati (mai svuotarlo) ed `exit 1` in caso di download fallito. Passato `PROXY_URL` all'env del workflow.

## 2026-05-28

- c_a070 (Agira EN): aggiunto nuovo albo — sito JCityGov su `trasparenza-valutazione-merito.it`, stesso pattern `papca/igrid` di Bagheria (c_a546) e Siderno (c_i725); feed generato con rsspls, nessun proxy necessario

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
