#!/bin/bash

### requisiti ###
# mlr https://github.com/johnkerl/miller
# xmlstarlet http://xmlstar.sourceforge.net/
# jq https://github.com/stedolan/jq
### requisiti ###

set -x

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

### anagrafica albo
titolo="AlboPOP del comune di Barcellona Pozzo di Gotto"
descrizione="L'albo pretorio POP è una versione dell'albo pretorio del tuo comune, che puoi seguire in modo più comodo."
nomecomune="Barcellona Pozzo di Gotto"
webMaster="salvatorebonaceto@gmail.com (Salvatore Bonaceto)"
type="Comune"
municipality="Barcellona Pozzo di Gotto"
province="Messina"
region="Sicilia"
latitude="38.145437"
longitude="15.213394"
country="Italia"
name="Comune di Barcellona Pozzo di Gotto"
uid="istat:083005"
docs="https://albopop.it/comune/barcellona_pozzo_di_gotto/"
selflink="https://aborruso.github.io/albiPOPGitHub/c_a638/feed.xml"
### anagrafica albo

iPA="c_a638"

#http://web11.immediaspa.com/barcellona/mc/mc_p_dettaglio.php?id_pubbl=567&x=&sto=&pag=&mittente=&oggetto=&numero=&tipo_atto=&data_dal=&data_al=&datap_dal=&datap_al=&ordin=&servizio=

# crea cartelle di servizio
mkdir -p "$folder"/rawdata
mkdir -p "$folder"/processing
mkdir -p "$folder"/../docs/"$iPA"

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# imposta la cartella di output esposta sul web
output="$folder"/../docs/"$iPA"

# URL di test risposta sito albo
URLBase="http://web11.immediaspa.com/barcellona/mc/mc_p_ricerca.php?multiente=barcellona&pag=0"

# estrai codici di risposta HTTP dell'albo
code=$(curl -s -L -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:85.0) Gecko/20100101 Firefox/85.0' -o /dev/null -w "%{http_code}" "$URLBase")

# se il server risponde fai partire lo script
if [ $code -eq 200 ]; then

  rm "$folder"/rawdata/albi.json
  for i in {0..3}; do
    curl -kL 'http://web11.immediaspa.com/barcellona/mc/mc_p_ricerca.php?multiente=barcellona&pag='"$i"'' \
      -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:85.0) Gecko/20100101 Firefox/85.0' \
      -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8' \
      -H 'Accept-Language: it,en-US;q=0.7,en;q=0.3' --compressed \
      -H 'Upgrade-Insecure-Requests: 1' \
      -H 'Pragma: no-cache' \
      -H 'Cache-Control: no-cache' | scrape -be '//table[@id="table-albo-pretorio"]//tr[@data-id]' | xq -c '.html.body.tr[]|{id:.td[0]["#text"],mittente:.td[1]["#text"],des:.td[2].a.span,tipo:.td[3]["#text"],inizio:.td[4]["#text"],fine:.td[5]?["#text"]?}' >>"$folder"/rawdata/albi.json
  done

  # converti lista in TSV
  jq <"$folder"/rawdata/albi.json | mlr --j2t unsparsify then put -S '$rssDate = strftime(strptime($inizio, "%d/%m/%Y"),"%a, %d %b %Y %H:%M:%S %z")' then put '$des=gsub($des,"<","&lt")' \
    then put '$des=gsub($des,">","&gt;")' \
    then put '$des=gsub($des,"&","&amp;")' \
    then put '$des=gsub($des,"'\''","&apos;")' \
    then put '$des=gsub($des,"\"","&quot;")' then cut -x -f fine then sort -nr id | tail -n +2 >"$folder"/rawdata/albi.tsv

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
  while IFS=$'\t' read -r numero mittente oggetto tipo dataInizio rssData; do
    URL="http://web11.immediaspa.com/barcellona/mc/mc_p_dettaglio.php?id_pubbl=$numero"
    newcounter=$(expr $newcounter + 1)
    xmlstarlet ed -L --subnode "//channel" --type elem -n item -v "" \
      --subnode "//item[$newcounter]" --type elem -n title -v "$tipo | Pubblicazione numero $numero" \
      --subnode "//item[$newcounter]" --type elem -n description -v "$oggetto" \
      --subnode "//item[$newcounter]" --type elem -n link -v "$URL" \
      --subnode "//item[$newcounter]" --type elem -n pubDate -v "$rssData" \
      --subnode "//item[$newcounter]" --type elem -n guid -v "$URL" \
      "$folder"/processing/feed.xml
  done <"$folder"/rawdata/albi.tsv

  cp "$folder"/processing/feed.xml "$output"

fi
