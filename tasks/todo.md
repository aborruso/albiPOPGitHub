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
- [ ] Run forzato su GitHub verde

## Cosa si è imparato

- **Il guard va messo dove il dato entra, non dove viene consumato.** Controllare il risultato unito delle tre pagine avrebbe lasciato passare il caso peggiore: due pagine buone e una vuota producono un feed troncato, che non fallisce e viene pubblicato. `add` è neutro rispetto ai `null`, quindi nasconde proprio la perdita parziale.
- **Un job lento è un sintomo diagnostico.** La differenza fra 45 secondi e 22 minuti ha identificato la causa prima ancora di leggere lo script.
- **`code=$(curl ...)` sotto `set -e` maschera l'errore**: senza `|| true` lo script muore sulla command substitution con un nudo exit 28, prima di poter stampare il messaggio che gli è stato scritto attorno.

## Resta aperto

- `.github/workflows/c_f158.yml` usa ancora `actions/checkout@v2` e genera l'avviso di deprecazione Node 20, già risolto altrove con `checkout@v5` (commit `da7e33ead`). Fuori dallo scopo di questa correzione, da fare in un passaggio dedicato su tutti i workflow rimasti indietro.
