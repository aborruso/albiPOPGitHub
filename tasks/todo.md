# Terlizzi: migrazione nuovo Halley — 2026-11-11

- [x] Verificare homepage, elenco, tre pagine e dettaglio reale con agent-browser e richieste HTTP.
- [x] Identificare il blocco della vecchia rotta PHP e i comandi POST del nuovo Halley.
- [x] Adattare lo scraper ai 30 atti più recenti con metadati e link ufficiali ai documenti, senza inventare permalink di scheda.
- [x] Verificare tutti i link senza sessione, cache dei documenti già recuperati e conservazione del feed su errore.
- [x] Testare feed, ordinamento, casi di errore e aprire documenti a campione con agent-browser.

## Review

Completato localmente: 30 atti, 64 documenti ufficiali verificati senza cookie e feed in `docs/c_l109/feed.xml`. Il link principale apre il documento, non una scheda HTML: la scheda del portale dipende dalla sessione (`MC02`). Descrizione RSS con metadati e tutti gli allegati; GUID anno/numero indipendenti dagli URL generati da Halley.
11 test unitari passano; test pipeline in `tmp/test_terlizzi_pipeline.py`: XML valido, GUID univoci, seconda esecuzione live in 15,2 s con zero dettagli recuperati, verifica HEAD dei documenti e feed byte-identico; errore del recupero conserva il feed precedente. Tre link campione verificati con agent-browser (HTTP 200).
Particolarità riprodotte e coperte dai test: ritorno `MC08` prima della paginazione, allegati HTML legittimi, header Range rifiutato (403), link documentali scaduti da rigenerare. Anche gli 8 test di Molfetta passano. Nessuna ulteriore issue creata dopo l'indicazione dell'utente.
Domande aperte: nessuna per il funzionamento locale. Correzione collegata alla chiusura della issue #19; la verifica dal runner GitHub resta separata dai test locali.

---

# Molfetta: correzione estrazione — 2026-11-11

- [x] Individuare il repository esistente con `esearch` e controllare la pagina con `agent-browser`.
- [x] Identificare colonne reali: ID `td[1]`, oggetto `td[5]`, pubblicazione `td[8]` (indici da zero).
- [x] Correggere soltanto lo scraper di Molfetta e impedire la pubblicazione di feed vuoti.
- [x] Confrontare prima/dopo sulla stessa pagina e verificare XML, titoli, date e identificativi.
- [x] Recuperare gli URL `IDALBO` dal postback reale del portale, senza inventare link `#id`.
- [x] Verificare ogni nuovo permalink con una richiesta senza cookie e preservare il feed in caso di errore.
- [x] Limitare il feed ai 30 atti più recenti, prima delle richieste ai dettagli, e riusare i link del feed precedente.
- [x] Rigenerare il feed completo e verificare i dettagli con `agent-browser`.

## Review

Prima: 0 item con exit 0. Dopo: 30 atti ordinati per data/ID, titoli non vuoti anche con `&`, date parsabili, GUID univoci con `isPermaLink=false` e link reali `IDALBO`. Tutti i 30 nuovi link verificati via HTTP senza cookie; primo, quindicesimo e ultimo aperti con `agent-browser` in sessioni nuove, con dettaglio e allegato corretti. CSV del portale verificato: non include permalink.
Prima generazione con verifiche live: 55,4 s. Seconda: 1,2 s, zero richieste ai dettagli e feed byte-identico; ultima ripetizione a cache calda 0,8 s. Verificati fonte senza atti (exit 1, feed precedente intatto) e singola riga (1 item). Otto test unitari passano, inclusi errore persistente, risposta temporaneamente incompleta e link a un atto diverso; `bash -n`, validazione XML e `git diff --check` passano. Smoke test ripetibile con `python3 tmp/test_molfetta.py`; fixture in `c_f284/tmp.html` (file ignorati).
Feed completo in `docs/c_f284/feed.xml`; correzione tracciata nella issue [#18](https://github.com/aborruso/albiPOPGitHub/issues/18). La prova GitHub sul codice precedente è terminata con `startup_failure`: la verifica CI della correzione resta separata dalla pubblicazione.

---

# Workflow in errore: analisi e correzioni del 2026-08-02

Quattro comuni con workflow rosso o feed non aggiornato. Ognuno si è rivelato un problema diverso, con una causa diversa. Il racconto completo di ogni intervento sta in `LOG.md`; qui restano il quadro d'insieme e ciò che è rimasto aperto.

## Stato

| comune | problema | soluzione | issue |
|---|---|---|---|
| c_a070 Agira | la fonte rifiuta le connessioni da parte degli IP dei runner, in modo intermittente | fallback via proxy (`PROXY_URL`), con il valore del secret tenuto fuori da `docs/` e dalla history | [#12](https://github.com/aborruso/albiPOPGitHub/issues/12) |
| c_h933 San Giuseppe Jato | dal rinnovo del 27/07 il server non invia il certificato intermedio; inoltre le date degli item erano lette dalla colonna sbagliata | download con `curl -k` passato a `scrape` da file; data presa da `td[4]`; fail-fast al posto dell'`if` silenzioso | [#13](https://github.com/aborruso/albiPOPGitHub/issues/13) |
| c_a638 Barcellona P.G. | la fonte blocca per IP: l'esito dipende dal runner assegnato, non dall'ora | job `ritenta` su un runner nuovo, unico modo di cambiare IP; rimosso il retry interno, che era inutile | [#14](https://github.com/aborruso/albiPOPGitHub/issues/14) |
| c_a546 Bagheria | token di sessione `p_auth` nei link: i lettori RSS riproponevano come nuovi tutti gli atti a ogni aggiornamento | token rimosso dal feed dopo la generazione | [#15](https://github.com/aborruso/albiPOPGitHub/issues/15) |

Tutti e quattro verificati con un run forzato su GitHub, verde, e con il feed su Pages controllato (validità, numero di item, contenuto).

## Cosa si è imparato

- **Ogni comune va diagnosticato per conto suo.** Quattro workflow rossi con lo stesso sintomo apparente («la fonte non risponde») avevano quattro cause diverse. La ricetta di un comune non si copia sull'altro senza verificarne i presupposti: per c_a638 il proxy non arriva alla fonte, e comunque gli href relativi renderebbero i link del feed sbagliati.
- **Ritentare sullo stesso runner non serve** quando il blocco è per IP. Va cambiato runner.
- **Mai svuotare o sovrascrivere un feed buono**: ora tutti e quattro gli script si fermano prima di pubblicare se il risultato è vuoto o malformato. Era già la regola scritta per c_e036 il 2026-07-08.

## Resta aperto

- Il ramo proxy di c_a070 **non è ancora stato esercitato in CI**: il blocco è intermittente e i run di verifica sono passati dal percorso diretto. Alla prossima volta il marcatore `fetch: via proxy` nel log lo renderà evidente.
- Gli iscritti al feed di Bagheria vedranno **un'ultima ondata** di item «nuovi» al primo aggiornamento dopo la correzione: cambiando i guid è inevitabile, non è una regressione.
- `rsspls` risolve l'`output` del `feeds.toml` rispetto alla **directory corrente**, non al file di configurazione. In CI non si nota, perché i workflow fanno `cd` prima di eseguire; in locale invece il feed finisce fuori dal repo. Sistemato in `c_a546.sh` con un `cd "$folder"`; `c_a070.sh` e `c_a638.sh` hanno ancora la stessa fragilità, innocua in produzione.
- Fuori dal repo, in `/home/aborruso/git/progetti/docs/`, restano `c_a965` e `c_l109`: feed finiti lì per la stessa ragione, da sessioni di gennaio e ottobre. Da eliminare se non servono.
- Questo file è tracciato in git, in un repo pubblico dove `tasks/` prima non esisteva. Se preferisci tenerlo fuori dalla history, va aggiunto a `.gitignore`.

---

# c_f158 Messina: fallimento intermittente e feed troncato silenzioso — 2026-08-14

Issue [#16](https://github.com/aborruso/albiPOPGitHub/issues/16). Il racconto completo sta in `LOG.md`.

## Cosa è stato fatto

- [x] Diagnosi: `curl` senza timeout né controllo HTTP → fonte appesa → pagine senza righe → `add` restituisce `null` → jq esplode. Confermato dalle durate dei job (13 e 22 minuti nei run falliti, 30-45 secondi in quelli riusciti) e dal markup ancora valido oggi → verifica: 200 in 1,1s, 40 righe `master-detail-list-line`
- [x] `fetch_page` con `--connect-timeout 20 --max-time 60 --retry 3` e verifica del codice HTTP → verifica: 404 e host appeso danno entrambi messaggio leggibile ed `exit 1`
- [x] Controllo per pagina sul numero di righe, non sul totale unito → verifica: pagina senza righe ferma lo script alla pagina 1
- [x] Retry `for i in 1 2 3` nel workflow → verifica: se tutti e tre i tentativi falliscono il ciclo esce non-zero e lo step resta rosso
- [x] Feed pubblicato mai toccato dai percorsi di errore → verifica: `md5sum` invariato dopo i tre test
- [x] Run reale → verifica: `xmlstarlet val` valido, 60 item, link senza token di sessione
- [x] Run forzato su GitHub verde → verifica: [run 31805760338](https://github.com/aborruso/albiPOPGitHub/actions/runs/31805760338) in 33 secondi, feed su Pages con 60 item

## Cosa si è imparato

- **Il guard va messo dove il dato entra, non dove viene consumato.** Controllare il risultato unito delle tre pagine avrebbe lasciato passare il caso peggiore: due pagine buone e una vuota producono un feed troncato, che non fallisce e viene pubblicato. `add` è neutro rispetto ai `null`, quindi nasconde proprio la perdita parziale.
- **Un job lento è un sintomo diagnostico.** La differenza fra 45 secondi e 22 minuti ha identificato la causa prima ancora di leggere lo script.
- **`code=$(curl ...)` sotto `set -e` maschera l'errore**: senza `|| true` lo script muore sulla command substitution con un nudo exit 28, prima di poter stampare il messaggio che gli è stato scritto attorno.

## Resta aperto

- `c_f158.yml` è passato a `actions/checkout@v5`, quindi l'avviso Node 20 qui non c'è più. Restano indietro tutti gli altri workflow che usano ancora `checkout@v2`: da fare in un passaggio dedicato, con un solo commit.
