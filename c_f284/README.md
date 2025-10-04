c_f284 - Comune di Molfetta

Script per generare il feed RSS dell'Albo Pretorio del Comune di Molfetta.

File principali:
- c_f284.sh: script principale che scarica la pagina, estrae le pubblicazioni e genera `docs/c_f284/feed.xml` usando `mlr`, `jq`, `scrape` e `xmlstarlet`.

Requisiti:
- mlr (miller)
- xmlstarlet
- jq
- scrape-cli

I file di output vengono scritti in `docs/c_f284/feed.xml` per la pubblicazione.
