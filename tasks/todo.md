# c_a070 (Agira): fallback proxy quando la fonte blocca i runner GitHub

## Problema

Il workflow `crea feed RSS c_a070` fallisce a intermittenza (01/08 11:48 e 20:34, 02/08 20:36) con `client error (Connect) → operation timed out`: gli IP dei runner GitHub non riescono ad aprire la connessione verso `agira.trasparenza-valutazione-merito.it`. Da locale il sito risponde 200 in 1,3s e `rsspls` genera regolarmente un feed di 20 item: non è un problema di selettori.

## Verifiche già fatte

- Gli `href` nell'HTML sorgente sono **assoluti** → passare dal proxy non altera i link degli item.
- Il worker proxy accetta host arbitrari nella forma `<PROXY_URL><url>` (testato: 200, stesso payload).
- Test locale del percorso proxy: feed generato **byte-identico** a quello del percorso diretto, dopo aver rimosso il prefisso proxy dal `<channel><link>`.

## Fase 1 — tracciamento

- [x] Aprire issue GitHub sul fallimento intermittente di c_a070 → #12

## Fase 2 — modifica script `c_a070/c_a070.sh`

- [x] Tentare `rsspls` diretto sul `feeds.toml` versionato (comportamento attuale, invariato in locale)
- [x] Se fallisce e `PROXY_URL` è valorizzato: generare un `feeds.toml` temporaneo con `mktemp` (fuori dal repo, `trap ... EXIT`) con `url` prefissato dal proxy e `output` **assoluto**
- [x] Dopo la generazione via proxy: `sed` per rimuovere il prefisso dal feed, così il valore del secret non finisce mai in `docs/` né nella history git
- [x] Marcatori in log (`fetch: diretto` / `fetch: via proxy`) per rendere diagnosticabile il percorso seguito

## Fase 3 — workflow `.github/workflows/c_a070.yml`

- [x] Aggiungere `PROXY_URL: ${{ secrets.PROXY_URL }}` nel blocco `env` (senza, il ramo proxy è codice morto)

## Fase 4 — verifica e chiusura

- [x] Test locale: percorso diretto invariato, feed in `docs/c_a070/feed.xml` identico
- [x] Commit con `Closes #12` e push
- [x] Run manuale del workflow e lettura log
- [x] Aggiornare `LOG.md`

## Review

Scelte che si sono discostate dal piano iniziale, tutte per non esporre il secret:

- **Non solo toml temporaneo, ma intera generazione fuori dal repo.** `rsspls` scrive dove dice il toml, quindi l'output del ramo proxy va in una dir temporanea; il feed arriva in `docs/` con un `cp` finale solo dopo essere stato ripulito. Così un errore a metà strada non può lasciare in `docs/` un feed con dentro l'URL del proxy.
- **Guardia `grep -F` prima del `cp`.** Se la rimozione del prefisso fallisse, lo script esce 1 e non pubblica nulla, invece di committare il secret.
- **`awk` invece di `sed` per generare il toml.** Nel testo di sostituzione di `sed` il carattere `&` ha significato speciale: se il secret contenesse una query string con `&`, l'URL uscirebbe corrotto. `awk -v` passa il valore alla lettera.
- **`|| true` sulla curl di verifica.** Senza, con proxy irraggiungibile `set -e` uccideva lo script prima del messaggio diagnostico; ora stampa `codice 000` e si capisce cosa è successo.

Test eseguiti in locale, su una copia dello script con il tentativo diretto forzato a fallire:

| scenario | esito |
|---|---|
| percorso diretto | `fetch: diretto`, feed 20 item |
| proxy corretto | `fetch: via proxy`, feed **byte-identico** al diretto, zero tracce del proxy |
| proxy con forma sbagliata | `Errore: anche il proxy fallisce (codice 400)`, feed pubblicato intatto |
| proxy irraggiungibile | `Errore: anche il proxy fallisce (codice 000)`, feed pubblicato intatto |

Dir temporanee rimosse dal `trap` in tutti i casi.

## Resta aperto

- Il ramo proxy **non è ancora stato esercitato in CI**: i blocchi sono intermittenti e il run di verifica è passato dal percorso diretto, come previsto. La prossima volta che la fonte blocca il runner, il marcatore `fetch: via proxy` nel log dirà se ha funzionato.
- La forma del secret `PROXY_URL` resta non verificata direttamente (GitHub non ne espone il valore). Se non fosse un prefisso puro, il log mostrerà `Errore: anche il proxy fallisce` con un codice HTTP invece di fallire in modo opaco.
- Stesso fallback per altri comuni che falliscono (`c_h933`, `c_a638`, `c_a546`): fuori scope, da valutare a parte.
