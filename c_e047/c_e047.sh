#!/bin/bash

### requisiti ###
# mlr https://github.com/johnkerl/miller
# xmlstarlet http://xmlstar.sourceforge.net/
# jq https://github.com/stedolan/jq
# scrape-cli per estrazione HTML
### requisiti ###

set -x
set -e
set -u
set -o pipefail

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

git pull

### anagrafica albo ###
titolo="AlboPOP del comune di Giovinazzo"
descrizione="L'albo pretorio POP è una versione dell'albo pretorio del tuo comune, che puoi seguire in modo più comodo."
type="Comune"
municipality="Giovinazzo"
province="Bari"
region="Puglia"
latitude="41.1888"
longitude="16.6894"
country="Italia"
name="Comune di Giovinazzo"
uid="istat:072029"
docs="https://albopop.it/comune/giovinazzo/"
selflink="https://aborruso.github.io/albiPOPGitHub/c_e047/feed.xml"
### anagrafica albo ###

iPA="c_e047"

URL_BASE="https://servizi.comune.giovinazzo.ba.it/openweb/albo/albo_pretorio.php"
curl_user_agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36"
cookie_jar="$folder/rawdata/cookies.txt"

mkdir -p "$folder"/rawdata
mkdir -p "$folder"/processing
mkdir -p "$folder"/../docs/"$iPA"

output="$folder"/../docs/"$iPA"

# scarica la pagina con cookie jar (necessario per la sessione)
code=$(curl -k -s -L --http1.1 -A "$curl_user_agent" \
  --connect-timeout 20 --max-time 60 --retry 4 --retry-delay 2 --retry-connrefused --retry-all-errors \
  -c "$cookie_jar" -b "$cookie_jar" \
  -w "%{http_code}" \
  "$URL_BASE" -o "$folder"/rawdata/albo.html)

if [ "$code" -ne 200 ]; then
  echo "Errore nel download: codice $code"
  exit 1
fi

# estrai dati dalla tabella
scrape -be '//tbody/tr[@class="paginated_element"]' < "$folder"/rawdata/albo.html | \
  xq -c '[.html.body.tr[] | {
    numero: .td[0].a["#text"],
    titolo: .td[1],
    atto: .td[2],
    data_affissione: .td[3],
    fine_pubblicazione: .td[4],
    url: ("https://servizi.comune.giovinazzo.ba.it" + .td[0].a["@href"])
  }]' > "$folder"/rawdata/elenco.json

fileContent=$(cat "$folder"/rawdata/elenco.json)
if [ "$fileContent" = "[]" ] || [ "$fileContent" = "null" ]; then
  echo "Array vuoto, nessun dato estratto"
  exit 1
fi

# converti in TSV con mlr e normalizza dati
jq -c '.[]' "$folder"/rawdata/elenco.json | \
mlr --ijson --otsv clean-whitespace then \
  put '$titolo = $numero . " - " . $titolo' then \
  put '$titolo=gsub($titolo,"<","&lt;")' then \
  put '$titolo=gsub($titolo,">","&gt;")' then \
  put '$titolo=gsub($titolo,"&","&amp;")' then \
  put '$titolo=gsub($titolo,"'\''","&apos;")' then \
  put '$titolo=gsub($titolo,"\"","&quot;")' then \
  put '$titolo=gsub($titolo,"°","&#176;")' then \
  put '$titolo=gsub($titolo,"–","&#8211;")' then \
  put '$rssDate = strftime(strptime($data_affissione, "%d/%m/%Y"),"%a, %d %b %Y %H:%M:%S %z")' then \
  sort -nr numero > "$folder"/rawdata/albi.tsv

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

# costruisci gli item RSS
newcounter=0
while IFS=$'\t' read -r numero titolo atto data_affissione fine_pubblicazione url rssDate; do
  if [[ "$numero" == "numero" ]]; then
    continue
  fi
  newcounter=$(expr $newcounter + 1)
  xmlstarlet ed -L --subnode "//channel" --type elem -n item -v "" \
    --subnode "//item[$newcounter]" --type elem -n title -v "$titolo" \
    --subnode "//item[$newcounter]" --type elem -n description -v "$atto" \
    --subnode "//item[$newcounter]" --type elem -n link -v "$url" \
    --subnode "//item[$newcounter]" --type elem -n pubDate -v "$rssDate" \
    --subnode "//item[$newcounter]" --type elem -n guid -v "$url" \
    "$folder"/processing/feed.xml
done < "$folder"/rawdata/albi.tsv

cp "$folder"/processing/feed.xml "$output"

rm -f "$folder"/rawdata/albo.html

echo "Feed RSS creato con successo: $output/feed.xml"
echo "Numero di item generati: $newcounter"

git pull origin master
