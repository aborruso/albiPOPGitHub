#!/bin/bash

### requisiti ###
# mlr https://github.com/johnkerl/miller
# xmlstarlet http://xmlstar.sourceforge.net/
# jq https://github.com/stedolan/jq
# scrape https://github.com/aborruso/scrape-cli
# xq (from yq package)
### requisiti ###

set -x
set -e
set -u
set -o pipefail

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

git pull

### anagrafica albo
titolo="AlboPOP del comune di Terlizzi"
descrizione="L'albo pretorio POP è una versione dell'albo pretorio del tuo comune, che puoi seguire in modo più comodo."
nomecomune="Terlizzi"
webMaster="andrea.borruso@gmail.com (Andrea Borruso)"
type="Comune"
municipality="Terlizzi"
province="Bari"
region="Puglia"
latitude="41.1269"
longitude="16.5464"
country="Italia"
name="Comune di Terlizzi"
uid="istat:c_l109"
docs="https://albopop.it/comune/terlizzi/"
selflink="https://aborruso.github.io/albiPOPGitHub/c_l109/feed.xml"
### anagrafica albo

iPA="c_l109"

# crea cartelle di servizio
mkdir -p "$folder"/rawdata
mkdir -p "$folder"/processing
mkdir -p "$folder"/../docs/"$iPA"

# imposta la cartella di output esposta sul web
output="$folder"/../docs/"$iPA"

# Nuovo Halley: sessione POST, tre pagine, massimo 30 atti.
# Ogni nuovo documento viene verificato senza cookie prima di aggiornare il feed.
python3 "$folder"/fetch_halley.py "$output"/feed.xml >"$folder"/rawdata/"$iPA".json

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

# leggi in loop i dati del file JSON e usali per creare nuovi item nel file XML
newcounter=0
jq -c '.[]' "$folder"/rawdata/"$iPA".json | while read -r line; do
  link=$(printf '%s' "$line" | jq -r .link | xmlstarlet esc)
  title=$(printf '%s' "$line" | jq -r .titolo | xmlstarlet esc)
  pubDate=$(printf '%s' "$line" | jq -r .pubDate)
  guid=$(printf '%s' "$line" | jq -r .guid)
  description=$(printf '%s' "$line" | jq -r .description | xmlstarlet esc)
  newcounter=$(expr $newcounter + 1)
  xmlstarlet ed -L --subnode "//channel" --type elem -n item -v "" \
    --subnode "//item[$newcounter]" --type elem -n title -v "$title" \
    --subnode "//item[$newcounter]" --type elem -n link -v "$link" \
    --subnode "//item[$newcounter]" --type elem -n pubDate -v "$pubDate" \
    --subnode "//item[$newcounter]" --type elem -n guid -v "$guid" \
    --insert "//item[$newcounter]/guid" --type attr -n isPermaLink -v false \
    --subnode "//item[$newcounter]" --type elem -n description -v "$description" \
    "$folder"/processing/feed.xml
done

xmlstarlet val --well-formed "$folder"/processing/feed.xml
items=$(xmlstarlet sel -t -v 'count(//item)' "$folder"/processing/feed.xml)
expected=$(jq length "$folder"/rawdata/"$iPA".json)
if [ "$items" -eq 0 ] || [ "$items" -ne "$expected" ] || [ "$items" -gt 30 ]; then
  echo "Errore: numero di item inatteso, non aggiorno il feed" >&2
  exit 1
fi
cp "$folder"/processing/feed.xml "$output"
