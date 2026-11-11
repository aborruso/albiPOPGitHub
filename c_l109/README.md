# AlboPOP — Comune di Terlizzi (c_l109)

Feed RSS degli ultimi 30 atti dell'albo pretorio del Comune di Terlizzi (Bari, Puglia).

- Fonte: https://www.comune.terlizzi.ba.it/EG0/EGHOMEPAGE.HBL?ss=1&F=MC09&en=e1380&freeze=1&P=
- Feed: https://aborruso.github.io/albiPOPGitHub/c_l109/feed.xml

## Funzionamento

Il nuovo Halley ha sostituito la tabella PHP con una sessione e comandi POST. `fetch_halley.py` apre la sessione, legge tre pagine con `scrape` CLI, recupera i documenti e restituisce i metadati in JSON. `c_l109.sh` costruisce il feed con `xmlstarlet`.

La scheda del portale si apre tramite posizione nella sessione e non espone un permalink verificato. Per questo **il link principale dell'item apre il documento ufficiale**, non una scheda HTML. La descrizione RSS contiene numero, periodo di pubblicazione, mittente, tipo e collegamenti a tutti gli allegati, anche quando sono documenti HTML anziché PDF.

I GUID usano anno e numero di pubblicazione e non cambiano se Halley rigenera il link al documento. I link già presenti nel feed vengono verificati con HEAD e riusati se disponibili; quelli scaduti vengono recuperati nuovamente dal portale. I nuovi documenti sono controllati senza cookie, verificando anche la firma dei PDF. Non si usa l'header Range, rifiutato dal firewall della fonte.

In caso di errori, pagine vuote, dati mancanti o allegati non disponibili, il processo termina senza sovrascrivere il feed precedente.

## Requisiti

- bash, git
- python3 (libreria standard, senza pacchetti aggiuntivi)
- [scrape-cli](https://github.com/aborruso/scrape-cli), con supporto a `--row` e `--field`
- jq
- xmlstarlet

## Utilizzo

Dalla cartella `c_l109`:

```bash
bash c_l109.sh
python3 -m unittest -v test_fetch_halley
```

Output: `../docs/c_l109/feed.xml`. Il comando principale esegue un `git pull` iniziale, come gli altri scraper del progetto.
