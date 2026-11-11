c_f284 - Comune di Molfetta

Script per generare il feed RSS dell'Albo Pretorio del Comune di Molfetta.

File principali:
- c_f284.sh: estrae con `scrape` i 30 atti più recenti, ordinati per data e ID, e genera `docs/c_f284/feed.xml`.
- resolve_links.py: recupera dal postback del portale il permalink `IDALBO` di ogni nuovo atto e verifica senza cookie che apra il dettaglio corretto. Riusa dal feed precedente i link già recuperati: senza nuovi atti non interroga i dettagli.
- test_resolve_links.py: test automatici del recupero, della cache e dei percorsi di errore. Eseguire dalla cartella `c_f284` con `python3 -m unittest -v test_resolve_links`.

Requisiti:
- mlr (miller)
- xmlstarlet
- jq
- scrape-cli
- xq (pacchetto yq)
- python3 (solo libreria standard per i permalink)

I file di output vengono scritti in `docs/c_f284/feed.xml` per la pubblicazione. La prima esecuzione recupera e verifica fino a 30 permalink; quelle successive interrogano soltanto gli atti nuovi. Se la fonte non restituisce atti o un nuovo permalink non è verificabile, lo script fallisce senza sovrascrivere il feed precedente.
