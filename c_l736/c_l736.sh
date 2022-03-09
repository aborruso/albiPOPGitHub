#!/bin/bash

### requisiti ###
# mlr https://github.com/johnkerl/miller
# xmlstarlet http://xmlstar.sourceforge.net/
# jq https://github.com/stedolan/jq
### requisiti ###

set -x

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

### anagrafica albo
titolo="AlboPOP del comune di Venezia"
descrizione="L'albo pretorio POP è una versione dell'albo pretorio del tuo comune, che puoi seguire in modo più comodo."
nomecomune="Venezia"
webMaster="fabrizio.puce82@gmail.com (Fabrizio Puce)"
type="Comune"
municipality="Venezia"
province="Venezia"
region="Veneto"
latitude="45.496144"
longitude="12.244231"
country="Italia"
name="Comune di Venezia"
uid="istat:027042"
docs="http://albopop.it/comune/venezia/"
selflink="https://aborruso.github.io/albiPOPGitHub/c_l736/feed.xml"
### anagrafica albo

iPA="c_l736"

# crea cartelle di servizio
mkdir -p "$folder"/rawdata
mkdir -p "$folder"/processing
mkdir -p "$folder"/../docs/"$iPA"

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# imposta la cartella di output esposta sul web
output="$folder"/../docs/"$iPA"

# URL di test risposta sito albo
URLBase="https://portale.comune.venezia.it/sites/all/modules/yui_venis/albo.php?tipo=JSON"

# estrai codici di risposta HTTP dell'albo
code=$(curl -s -L -o /dev/null -w "%{http_code}" "$URLBase")

# se il server risponde fai partire lo script
if [ $code -eq 200 ]; then

  # scarica lista pubblicazioni in albo
  #curl -skL "$URLBase" | iconv -f WINDOWS-1252 -t UTF-8 | jq . >"$folder"/rawdata/albo.json
  curl -skL "$URLBase" | jq . >"$folder"/rawdata/albo.json

  # converti lista in TSV
  jq <"$folder"/rawdata/albo.json '.atti[]' | mlr --j2t unsparsify | tail -n +2 | head -n 30 >"$folder"/rawdata/albo.tsv

  # cancella lista esistente dei dettagli delle pubblicazioni in albo
  rm "$folder"/rawdata/dettagli.json

  # a partire dalla lista delle pubbblicazioni, scarica dettagli di ogni pubblicazione in albo
  while IFS=$'\t' read -r anno numero dataInizio dataFine esibente oggetto sede; do
    curl -skL "https://portale.comune.venezia.it/sites/all/modules/yui_venis/alboDetail.php?tipo=JSON&anno=$anno&numero=$numero&sede=$sede" | iconv -f WINDOWS-1252 -t UTF-8 >>"$folder"/rawdata/dettagli.json
    echo -e "\n" >>"$folder"/rawdata/dettagli.json
  done <"$folder"/rawdata/albo.tsv

  # genera CSV dei dettagli
  mlr <"$folder"/rawdata/dettagli.json --j2c unsparsify >"$folder"/rawdata/dettagli.csv

  # tieni i dati sul primo allegato, aggiungi campo con data in formato RSS e estrai i soli campi utili
  mlr --c2t cut -x -r -f "files:[^0].+" \
    then put -S '$dataInizio = strftime(strptime($dataInizio, "%Y%m%d"),"%a, %d %b %Y %H:%M:%S %z");$URL=${files:0:path}.${files:0:alias}' \
    then cut -f numero,dataInizio,oggetto,naturaValore,URL "$folder"/rawdata/dettagli.csv | tail -n +2 >"$folder"/rawdata/dettagli.tsv

  # crea copia del template del feed
  cp "$folder"/../risorse/feedTemplate.xml "$folder"/processing/feed.xml

  # inserisci gli attributi anagrafici nel feed
  xmlstarlet ed -L --subnode "//channel" --type elem -n title -v "$titolo" "$folder"/processing/feed.xml
  xmlstarlet ed -L --subnode "//channel" --type elem -n description -v "$descrizione" "$folder"/processing/feed.xml
  xmlstarlet ed -L --subnode "//channel" --type elem -n link -v "$selflink" "$folder"/processing/feed.xml
  xmlstarlet ed -L --subnode "//channel" --type elem -n "atom:link" -v "" -i "//*[name()='atom:link']" -t "attr" -n "rel" -v "self" -i "//*[name()='atom:link']" -t "attr" -n "href" -v "$selflink" -i "//*[name()='atom:link']" -t "attr" -n "type" -v "application/rss+xml" "$folder"/processing/feed.xml
  xmlstarlet ed -L --subnode "//channel" --type elem -n docs -v "$docs" "$folder"/processing/feed.xml
  xmlstarlet ed -L --subnode "//channel" --type elem -n category -v "$type" -i "//channel/category[1]" -t "attr" -n "domain" -v "http://albopop.it/specs#channel-category-type" "$folder"/processing/feed.xml
  xmlstarlet ed -L --subnode "//channel" --type elem -n category -v "$municipality" -i "//channel/category[2]" -t "attr" -n "domain" -v "http://albopop.it/specs#channel-category-municipality" "$folder"/processing/feed.xml
  xmlstarlet ed -L --subnode "//channel" --type elem -n category -v "$province" -i "//channel/category[3]" -t "attr" -n "domain" -v "http://albopop.it/specs#channel-category-province" "$folder"/processing/feed.xml
  xmlstarlet ed -L --subnode "//channel" --type elem -n category -v "$region" -i "//channel/category[4]" -t "attr" -n "domain" -v "http://albopop.it/specs#channel-category-region" "$folder"/processing/feed.xml
  xmlstarlet ed -L --subnode "//channel" --type elem -n category -v "$latitude" -i "//channel/category[5]" -t "attr" -n "domain" -v "http://albopop.it/specs#channel-category-latitude" "$folder"/processing/feed.xml
  xmlstarlet ed -L --subnode "//channel" --type elem -n category -v "$longitude" -i "//channel/category[6]" -t "attr" -n "domain" -v "http://albopop.it/specs#channel-category-longitude" "$folder"/processing/feed.xml
  xmlstarlet ed -L --subnode "//channel" --type elem -n category -v "$country" -i "//channel/category[7]" -t "attr" -n "domain" -v "http://albopop.it/specs#channel-category-country" "$folder"/processing/feed.xml
  xmlstarlet ed -L --subnode "//channel" --type elem -n category -v "$name" -i "//channel/category[8]" -t "attr" -n "domain" -v "http://albopop.it/specs#channel-category-name" "$folder"/processing/feed.xml
  xmlstarlet ed -L --subnode "//channel" --type elem -n category -v "$uid" -i "//channel/category[9]" -t "attr" -n "domain" -v "http://albopop.it/specs#channel-category-uid" "$folder"/processing/feed.xml

  # leggi in loop i dati del file TSV e usali per creare nuovi item nel file XML
  newcounter=0
  while IFS=$'\t' read -r numero dataInizio oggetto naturaValore URL; do
    newcounter=$(expr $newcounter + 1)
    xmlstarlet ed -L --subnode "//channel" --type elem -n item -v "" \
      --subnode "//item[$newcounter]" --type elem -n title -v "#$naturaValore | Pubblicazione numero $numero" \
      --subnode "//item[$newcounter]" --type elem -n description -v "$oggetto" \
      --subnode "//item[$newcounter]" --type elem -n link -v "$URL" \
      --subnode "//item[$newcounter]" --type elem -n pubDate -v "$dataInizio" \
      --subnode "//item[$newcounter]" --type elem -n guid -v "$URL" \
      "$folder"/processing/feed.xml
  done <"$folder"/rawdata/dettagli.tsv

  cp "$folder"/processing/feed.xml "$output"

fi
