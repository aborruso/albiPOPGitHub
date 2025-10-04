#!/bin/bash

### requisiti ###
# mlr https://github.com/johnkerl/miller
# xmlstarlet http://xmlstar.sourceforge.net/
# jq https://github.com/stedolan/jq
# scrape https://github.com/aborruso/scrape-cli
### requisiti ###

set -x
set -e
set -u
set -o pipefail

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

git pull

### anagrafica albo
titolo="AlboPOP del comune di Molfetta"
descrizione="L'albo pretorio POP è una versione dell'albo pretorio del tuo comune, che puoi seguire in modo più comodo."
nomecomune="Molfetta"
webMaster="maintainer@example.com"
type="Comune"
municipality="Molfetta"
province="Bari"
region="Puglia"
latitude="41.1782"
longitude="16.5207"
country="Italia"
name="Comune di Molfetta"
uid="istat:c_f284"
docs="https://albopop.it/comune/molfetta/"
selflink="https://aborruso.github.io/albiPOPGitHub/c_f284/feed.xml"
### anagrafica albo

iPA="c_f284"

URLBase="https://servizionline.comune.molfetta.ba.it/cmsmolfetta/portale/albopretorio/albopretorioconsultazione.aspx?P=400"

# crea cartelle di servizio
mkdir -p "$folder"/rawdata
mkdir -p "$folder"/processing
mkdir -p "$folder"/../docs/"$iPA"

# imposta la cartella di output esposta sul web
output="$folder"/../docs/"$iPA"

# scarica la pagina e verifica raggiungibilità
code=$(curl -s -L -H 'User-Agent: Mozilla/5.0' -o /dev/null -w "%{http_code}" "$URLBase")
if [ "$code" -ne 200 ]; then
  echo "Sito non raggiungibile, codice: $code"
  exit 1
fi

curl -kL "$URLBase" >"$folder"/tmp.html

# Estrai le righe della tabella; la struttura mostra colonne: id | titolo | data
# Proviamo a estrarre td elements delle righe della tabella principale dei risultati
<"$folder"/tmp.html scrape -be '//table//tr' |
  xq -c '.html.body.tr[]? | {
    id: (.td[0]."#text" // ""),
    titolo: (.td[4]."#text" // ""),
    data: (.td[7]."#text" // ""),
    link: ("https://servizionline.comune.molfetta.ba.it/cmsmolfetta/portale/albopretorio/albopretorioconsultazione.aspx?P=400#" + ((.td[0]."#text" // "") | tostring))
  }' >"$folder"/rawdata/"$iPA"_temp.json 2>/dev/null || true

# Se non ci sono risultati, crea file vuoto
if [ ! -s "$folder"/rawdata/"$iPA"_temp.json ]; then
  echo "[]" >"$folder"/rawdata/"$iPA"_temp.json
fi

# Normalizza e deduplica: unisci, rimuovi duplicati per titolo/link
jq -s 'flatten | map(select(. != null)) | unique_by(.link, .titolo)' "$folder"/rawdata/"$iPA"_temp.json >"$folder"/rawdata/"$iPA".json || echo "[]" >"$folder"/rawdata/"$iPA".json

# Converti JSON in CSV con mlr per ulteriori trasformazioni
mlr --j2c cat "$folder"/rawdata/"$iPA".json >"$folder"/rawdata/"$iPA".csv || true


# Debug temporaneo: stampa le date estratte
echo "Date estratte (prime 10):"
head -n 10 "$folder"/rawdata/"$iPA".csv | cut -d, -f3

# Normalizza la data: solo se valida, la converte in formato RSS, altrimenti lascia vuoto
# Aggiungi anche un campo per l'ordinamento (timestamp) e ordina per data decrescente
# Filtra solo gli item degli ultimi 30 giorni (2592000 secondi = 30 giorni)
mlr --c2j clean-whitespace \
  then put 'if (is_present($data) && $data =~ "^[0-9]{2}/[0-9]{2}/[0-9]{4}$") { $pubDate = strftime(strptime($data, "%d/%m/%Y"), "%a, %d %b %Y 00:00:00 +0000"); $timestamp = strptime($data, "%d/%m/%Y") } else { $pubDate = ""; $timestamp = 0 }' \
  then put '$link = gsub($link, "&", "&amp;")' \
  then put '$now = systime(); $age_days = ($now - $timestamp) / 86400' \
  then filter '$timestamp > 0 && $age_days <= 30' \
  then sort -nr timestamp \
  "$folder"/rawdata/"$iPA".csv > "$folder"/rawdata/"$iPA"_temp.json || true

# Se mlr non è riuscito a generare il file temporaneo, usa il JSON originale
if [ ! -s "$folder"/rawdata/"$iPA"_temp.json ]; then
  cp "$folder"/rawdata/"$iPA".json "$folder"/rawdata/"$iPA"_temp.json || true
fi

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
jq -c '.[]' "$folder"/rawdata/"$iPA"_temp.json | while read -r line; do
  link=$(echo "$line" | jq -r '.link // empty')
  title=$(echo "$line" | jq -r '.titolo // empty')
  guid=$(echo "$line" | jq -r '.id // empty')

  # Salta i record con id o titolo vuoti
  if [ -z "$guid" ] || [ -z "$title" ]; then
    continue
  fi

  pubDate=$(echo "$line" | jq -r '.pubDate // empty')
  # Se pubDate non è presente, lascia vuoto (NON usare più .data)
  if [ -z "$pubDate" ]; then
    pubDate=""
  fi

  newcounter=$(expr $newcounter + 1)
  xmlstarlet ed -L --subnode "//channel" --type elem -n item -v "" \
    --subnode "//item[$newcounter]" --type elem -n title -v "$title" \
    --subnode "//item[$newcounter]" --type elem -n link -v "$link" \
    --subnode "//item[$newcounter]" --type elem -n pubDate -v "$pubDate" \
    --subnode "//item[$newcounter]" --type elem -n guid -v "$guid" \
    "$folder"/processing/feed.xml
done

cp "$folder"/processing/feed.xml "$output"
