# AlboPOP - Comune di Terlizzi (c_l109)

Feed RSS dell'albo pretorio del Comune di Terlizzi.

## Informazioni

- **Comune**: Terlizzi
- **Provincia**: Bari
- **Regione**: Puglia
- **Codice iPA**: c_l109
- **URL fonte**: https://www.comune.terlizzi.ba.it/terlizzi/mc/mc_p_ricerca.php
- **Feed RSS**: https://aborruso.github.io/albiPOPGitHub/c_l109/feed.xml

## Requisiti

- bash
- curl (con supporto SSL -k per certificati non validi)
- [scrape](https://github.com/aborruso/scrape-cli) - Scraping HTML con XPath
- [xq](https://github.com/kislyuk/yq) - Conversione XML/HTML a JSON
- [jq](https://github.com/stedolan/jq) - Parser JSON
- [mlr](https://github.com/johnkerl/miller) - Elaborazione dati tabulari
- [xmlstarlet](http://xmlstar.sourceforge.net/) - Manipolazione XML

## Utilizzo

Per generare il feed RSS:

```bash
./c_l109.sh
```

Il feed generato sarà disponibile in `../docs/c_l109/feed.xml`

## Note tecniche

Il sito del comune di Terlizzi presenta un certificato SSL non valido, quindi lo script usa `curl -k` per ignorare gli errori di certificato.

La struttura della pagina utilizza una tabella HTML con elementi `<tbody>` e `<tr>`. Lo script:

1. Scarica la pagina HTML con curl (ignorando errori SSL)
2. Estrae le righe della tabella usando XPath (`//tbody/tr`)
3. Converte l'HTML in JSON usando xq
4. Processa i dati con mlr per formattarli
5. Genera il feed RSS usando xmlstarlet

## Struttura dati estratti

- **Titolo**: `.td[1].a.div."#text"` - Oggetto della pubblicazione
- **Link**: `.td[1].a."@href"` - URL dettaglio (relativo, viene convertito in assoluto)
- **Data**: `.td[4].div[0]` - Data inizio pubblicazione (formato dd/mm/yyyy)
