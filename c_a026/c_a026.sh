#!/bin/bash

### requisiti ###
# mlr https://github.com/johnkerl/miller
# xmlstarlet http://xmlstar.sourceforge.net/
# jq https://github.com/stedolan/jq
### requisiti ###

set -x

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

git pull

### anagrafica albo
titolo="AlboPOP del comune di Aci Castello"
descrizione="L'albo pretorio POP è una versione dell'albo pretorio del tuo comune, che puoi seguire in modo più comodo."
nomecomune="Aci Castello"
webMaster="undefined"
type="Comune"
municipality="Aci Castello"
province="Catania"
region="Sicilia"
latitude="37.554908"
longitude="15.146427"
country="Italia"
name="Comune di Aci Castello"
uid="istat:087002"
docs="https://albopop.it/comune/aci_castello/"
selflink="https://aborruso.github.io/albiPOPGitHub/c_a026/feed.xml"
### anagrafica albo

iPA="c_a026"

# crea cartelle di servizio
mkdir -p "$folder"/rawdata
mkdir -p "$folder"/processing
mkdir -p "$folder"/../docs/"$iPA"

# imposta la cartella di output esposta sul web
output="$folder"/../docs/"$iPA"

# myip=$(curl --socks5-hostname localhost:9050 ifconfig.me)
# curl https://ipapi.co/"$myip"/json/

# URL di test risposta sito albo
URLBase="http://trasparenza.comune.acicastello.ct.it/web/trasparenza/albo-pretorio"
#URLBase="https://web.archive.org/web/20220319161659/http://trasparenza.comune.acicastello.ct.it/web/trasparenza/albo-pretorio"

# estrai codici di risposta HTTP dell'albo
code=$(curl --socks5-hostname localhost:9050 -s -kL -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:85.0) Gecko/20100101 Firefox/85.0' -o "$folder"/rawdata/tmp.html -w "%{http_code}" "$URLBase")

# se il server risponde fai partire lo script
if [ $code -eq 200 ]; then

  <"$folder"/rawdata/tmp.html scrape -be '//table//tr[contains(@class, "master-detail-list-line")]' | xq -c '.html.body.tr[]|{id:.["@data-id"],atto:.td[1]["#text"],des:.td[3]["#text"],tipo:"b",date:.td[4]["#text"]}' >"$folder"/rawdata/albi.json

  # converti lista in TSV
  jq <"$folder"/rawdata/albi.json | mlr --j2t unsparsify \
    then clean-whitespace \
    then put -S '$inizio=sub($date,"^([^ ]+) ([^ ]+)$","\1");$fine=sub($date,"^([^ ]+) ([^ ]+)$","\1")' \
    then put -S '$rssDate = strftime(strptime($inizio, "%d/%m/%Y"),"%a, %d %b %Y %H:%M:%S %z")' then put '$des=gsub($des,"<","&lt")' \
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
  while IFS=$'\t' read -r numero atto des tipo date inizio rssData; do
    URL="http://trasparenza.comune.acicastello.ct.it/web/trasparenza/albo-pretorio/-/papca/display/$numero"
    newcounter=$(expr $newcounter + 1)
    xmlstarlet ed -L --subnode "//channel" --type elem -n item -v "" \
      --subnode "//item[$newcounter]" --type elem -n title -v "Atto numero $atto" \
      --subnode "//item[$newcounter]" --type elem -n description -v "$des" \
      --subnode "//item[$newcounter]" --type elem -n link -v "$URL" \
      --subnode "//item[$newcounter]" --type elem -n pubDate -v "$rssData" \
      --subnode "//item[$newcounter]" --type elem -n guid -v "$URL" \
      "$folder"/processing/feed.xml
  done <"$folder"/rawdata/albi.tsv

  cp "$folder"/processing/feed.xml "$output"

fi

git pull origin master
