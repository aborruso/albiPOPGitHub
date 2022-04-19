#!/bin/bash

### requisiti ###
# mlr https://github.com/johnkerl/miller
# xmlstarlet http://xmlstar.sourceforge.net/
# jq https://github.com/stedolan/jq
### requisiti ###

set -x
set -e
set -u
set -o pipefail

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

git pull

### anagrafica albo
titolo="AlboPOP del comune di Bagheria"
descrizione="L'albo pretorio POP è una versione dell'albo pretorio del tuo comune, che puoi seguire in modo più comodo."
nomecomune="Bagheria"
webMaster="aborruso@gmail.com (Andrea Borruso)"
type="Comune"
municipality="Bagheria"
province="Palermo"
region="Sicilia"
latitude="38.07989977565112"
longitude="13.50949051096456"
country="Italia"
name="Comune di Bagheria"
uid="istat:082006"
docs="https://albopop.it/comune/bagheria/"
selflink="https://aborruso.github.io/albiPOPGitHub/c_a546/feed.xml"
### anagrafica albo

iPA="c_a546"

#http://web11.immediaspa.com/barcellona/mc/mc_p_dettaglio.php?id_pubbl=567&x=&sto=&pag=&mittente=&oggetto=&numero=&tipo_atto=&data_dal=&data_al=&datap_dal=&datap_al=&ordin=&servizio=

# crea cartelle di servizio
mkdir -p "$folder"/rawdata
mkdir -p "$folder"/processing
mkdir -p "$folder"/../docs/"$iPA"

# imposta la cartella di output esposta sul web
output="$folder"/../docs/"$iPA"

# URL di test risposta sito albo
URLBase="https://comune.bagheria.pa.it/albo-pretorio/albo-pretorio-online/?ap_page=1"
URL="https://comune.bagheria.pa.it/albo-pretorio/albo-pretorio-online/?ap_page="

# estrai codici di risposta HTTP dell'albo
code=$(curl -s -L -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:85.0) Gecko/20100101 Firefox/85.0' -o /dev/null -w "%{http_code}" "$URLBase")

# se il server risponde fai partire lo script
if [ $code -eq 200 ]; then

  if [ -f "$folder"/rawdata/albi.json ]; then
    rm "$folder"/rawdata/albi.json
  fi

  for i in {1..4}; do
    curl -kL ''"$URL"''"$i"'' | \
     scrape -be '//table[@class="ap-table"]//tr[td]' | xq -c '.html.body.tr[]|{des:.td[3].a["#text"],inizio:.td[4],tipo:.td[6],url:.td[3].a["@href"],id:.td[0]["#text"]}'>>"$folder"/rawdata/albi.json
  done

  #html.body.tr[0]["@data-id"]
  #  # converti lista in TSV
    jq <"$folder"/rawdata/albi.json | sed -r 's/\\r\\n/ /g' | mlr --j2t unsparsify then clean-whitespace then put '$rssDate = strftime(strptime($inizio, "%d/%m/%Y"),"%a, %d %b %Y %H:%M:%S %z")' \
      then put '$dataISO = strftime(strptime($inizio, "%d/%m/%Y"),"%Y-%m-%d")' \
      then put '$des=gsub($des,"<","&lt")' \
      then put '$des=gsub($des,">","&gt;")' \
      then put '$des=gsub($des,"&","&amp;")' \
      then put '$des=gsub($des,"'\''","&apos;")' \
      then put '$des=gsub($des,"\"","&quot;")' \
      then put '$url=gsub($url,"&","&amp;")' \
      then put '$url=gsub($url,"ap_page=[0-9]+&amp;","")' \
      then sort -r dataISO then  clean-whitespace | tail -n +2 >"$folder"/rawdata/albi.tsv

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
  while IFS=$'\t' read -r oggetto data categoria URL id rssData isoData; do
    newcounter=$(expr $newcounter + 1)
    titolo="$id | $categoria"
    xmlstarlet ed -L --subnode "//channel" --type elem -n item -v "" \
      --subnode "//item[$newcounter]" --type elem -n title -v "$titolo" \
      --subnode "//item[$newcounter]" --type elem -n description -v "$oggetto" \
      --subnode "//item[$newcounter]" --type elem -n link -v "$URL" \
      --subnode "//item[$newcounter]" --type elem -n pubDate -v "$rssData" \
      --subnode "//item[$newcounter]" --type elem -n guid -v "$URL" \
      "$folder"/processing/feed.xml
  done <"$folder"/rawdata/albi.tsv

  cp "$folder"/processing/feed.xml "$output"
  exit 0

fi
