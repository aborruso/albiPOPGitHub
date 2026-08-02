# LOG.md

## 2026-08-02

- c_a546 (Bagheria PA): i link e i guid degli atti contenevano il token di sessione `p_auth`, che il portale rigenera a ogni richiesta — i lettori RSS riproponevano come nuovi tutti gli atti a ogni aggiornamento, e ogni run produceva un commit inutile (13 in 7 giorni con gli stessi atti). Il token viene ora rimosso dal feed dopo la generazione: il dettaglio resta raggiungibile senza. Due run consecutivi producono feed byte-identici. Aggiunta la guardia sul numero di item e un `cd "$folder"` iniziale, perché rsspls risolve l'output rispetto alla directory corrente e non al `feeds.toml` (in CI non si notava, il workflow fa `cd` prima di eseguire; in locale il feed finiva fuori dal repo). Non introdotto il fallback proxy: qui i fallimenti sono 1 su 40 e si riassorbono allo schedule dopo. Chiude #15
- c_a638 (Barcellona Pozzo di Gotto ME): feed aggiornato solo nel 30% dei run (21 fallimenti su 30 dal 20/07) — la fonte rifiuta le connessioni da parte degli IP dei runner. Quattro run lanciati nella stessa finestra di 15 secondi hanno dato 2 successi e 1 fallimento: l'esito dipende dal runner assegnato, non dall'orario, quindi il retry dentro lo script (3 tentativi da 10s, stesso IP) era inutile e non ha mai salvato un run. Rimosso, e aggiunto al workflow un job `ritenta` che rifà il tentativo su un runner nuovo: il job principale non blocca più il workflow e il feed si aggiorna nel ~51% degli schedule. Escluse le altre strade: il proxy Cloudflare va in timeout su questo host (mentre Agira dallo stesso worker risponde in 1,3s), `halleyweb.com/c083005` è un'installazione SUAP in anteprima e non l'albo, lo user-agent è irrilevante perché il fallimento è in fase di connessione. Da ricordare: qui gli href sono relativi, quindi la ricetta proxy di c_a070 non sarebbe comunque copiabile senza riscrivere i link. Chiude #14
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
