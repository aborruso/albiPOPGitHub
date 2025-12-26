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
titolo="AlboPOP del comune di Terre del Reno"
descrizione="L'albo pretorio POP è una versione dell'albo pretorio del tuo comune, che puoi seguire in modo più comodo."
nomecomune="Terre del Reno"
webMaster="andrea.borruso@gmail.com (Andrea Borruso)"
type="Comune"
municipality="Terre del Reno"
province="Ferrara"
region="Emilia-Romagna"
latitude="44.79362049063872"
longitude="11.39038755537125"
country="Italia"
name="Comune di Terre del Reno"
uid="istat:038028"
docs="https://albopop.it/comune/terre-del-reno/"
selflink="https://aborruso.github.io/albiPOPGitHub/cdtdr/feed.xml"
### anagrafica albo

iPA="cdtdr"

# crea cartelle di servizio
mkdir -p "$folder"/rawdata
mkdir -p "$folder"/processing
mkdir -p "$folder"/../docs/"$iPA"

# imposta la cartella di output esposta sul web
output="$folder"/../docs/"$iPA"

# Scarica le prime 3 pagine per catturare più pubblicazioni
for page in 0 1 2; do
  URLPaginata="https://servizionline.comune.terredelreno.fe.it/mc/mc_p_ricerca.php?&pag=$page"

  # estrai codici di risposta HTTP dell'albo per ogni pagina
  code=$(curl -s -k -L --retry 5 --retry-delay 10 --retry-all-errors -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:126.0) Gecko/20100101 Firefox/126.0' -o /dev/null -w "%{http_code}" "$URLPaginata")

  # se il server risponde scarica la pagina
  if [ $code -eq 200 ]; then
    echo "Scaricando pagina $page..."
    curl -kL --retry 5 --retry-delay 10 --retry-all-errors "$URLPaginata" >"$folder"/tmp_page_$page.html

    # Estrai i dati da questa pagina e aggiungi al file temporaneo
    if [ -s "$folder"/tmp_page_$page.html ]; then
      <"$folder"/tmp_page_$page.html scrape -be '//tbody/tr' | xq -c '.html.body.tr[]|{titolo:.td[1].a.div."#text",url:.td[1].a."@href",data:.td[4].div[0]}' >>"$folder"/rawdata/"$iPA"_temp_page_$page.json 2>/dev/null || true
    fi
  else
    echo "Pagina $page non raggiungibile (codice: $code)"
  fi
done

# Combina tutti i file JSON delle pagine in un unico file
cat "$folder"/rawdata/"$iPA"_temp_page_*.json 2>/dev/null | jq -s 'flatten | unique_by(.url)' >"$folder"/rawdata/"$iPA"_temp.json 2>/dev/null || echo "[]" >"$folder"/rawdata/"$iPA"_temp.json

# Pulizia file temporanei
rm -f "$folder"/tmp_page_*.html "$folder"/rawdata/"$iPA"_temp_page_*.json

# Processa il JSON con mlr per creare il feed
mlr <"$folder"/rawdata/"$iPA"_temp.json --j2c \
  put '$pubDate=strftime(strptime($data,"%d/%m/%Y"),"%a, %d %b %Y %H:%M:%S %z")' \
  then put '$link="https://servizionline.comune.terredelreno.fe.it".$url' >"$folder"/rawdata/"$iPA".csv

# Converti in JSON pulito
mlr <"$folder"/rawdata/"$iPA".csv --c2j clean-whitespace \
  then put '$titolo=gsub($titolo,">","&gt;")' \
  then put '$titolo=gsub($titolo,"&","&amp;")' \
  then put '$titolo=gsub($titolo,"'\''","&apos;")' \
  then put '$titolo=gsub($titolo,"\"","&quot;")' \
  then put '$titolo=gsub($titolo,"°","&#176;")' \
  then put '$link=gsub($link,"&","&amp;")' >"$folder"/rawdata/"$iPA"_temp.json

# Sostituisci apostrofo curvo con entità HTML
sed "s/'/\&apos;/g" "$folder"/rawdata/"$iPA"_temp.json >"$folder"/rawdata/"$iPA".json

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
jq -c '.[]' "$folder"/rawdata/"$iPA".json | while read line; do
  link=$(echo $line | jq -r .link)
  title=$(echo $line | jq -r .titolo)
  pubDate=$(echo $line | jq -r .pubDate)
  newcounter=$(expr $newcounter + 1)
  xmlstarlet ed -L --subnode "//channel" --type elem -n item -v "" \
    --subnode "//item[$newcounter]" --type elem -n title -v "$title" \
    --subnode "//item[$newcounter]" --type elem -n link -v "$link" \
    --subnode "//item[$newcounter]" --type elem -n pubDate -v "$pubDate" \
    --subnode "//item[$newcounter]" --type elem -n guid -v "$link" \
    "$folder"/processing/feed.xml
done

cp "$folder"/processing/feed.xml "$output"
