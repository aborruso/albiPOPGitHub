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

# Solo righe degli atti: esclude intestazioni e tabelle di impaginazione.
# Le prime colonne sono nascoste: ID=1, oggetto=5, inizio pubblicazione=8.
<"$folder"/tmp.html scrape -be '//tr[td/input[contains(@id, "tab_risultati_table_hidden_row_")]]' |
  xq -c '
    def testo: if type == "object" then ."#text" // "" else . // "" end;
    (.html.body.tr // []) | if type == "array" then . else [.] end | .[] | {
      id: (.td[1] | testo),
      titolo: (.td[5] | testo),
      data: (.td[8] | testo)
    }' >"$folder"/rawdata/"$iPA"_temp.json

if [ ! -s "$folder"/rawdata/"$iPA"_temp.json ]; then
  echo "Errore: nessun atto estratto, non aggiorno il feed" >&2
  exit 1
fi

# Normalizza e deduplica per identificativo dell'atto
jq -s 'flatten | map(select(. != null)) | unique_by(.id)' "$folder"/rawdata/"$iPA"_temp.json >"$folder"/rawdata/"$iPA".json || echo "[]" >"$folder"/rawdata/"$iPA".json

# Converti JSON in CSV con mlr per ulteriori trasformazioni
mlr --j2c cat "$folder"/rawdata/"$iPA".json >"$folder"/rawdata/"$iPA".csv || true


# Debug temporaneo: stampa le date estratte
echo "Date estratte (prime 10):"
head -n 10 "$folder"/rawdata/"$iPA".csv | cut -d, -f3

# Ultimi 30 atti, non ultimi 30 giorni: a parità di data viene prima l'ID maggiore.
# Il limite si applica prima delle richieste alle pagine di dettaglio.
mlr --c2j clean-whitespace \
  then put 'if (is_present($data) && $data =~ "^[0-9]{2}/[0-9]{2}/[0-9]{4}$") { $pubDate = strftime(strptime($data, "%d/%m/%Y"), "%a, %d %b %Y 00:00:00 +0000"); $timestamp = strptime($data, "%d/%m/%Y") } else { $pubDate = ""; $timestamp = 0 }' \
  then filter '$timestamp > 0' \
  then sort -nr timestamp,id \
  then head -n 30 \
  "$folder"/rawdata/"$iPA".csv > "$folder"/rawdata/"$iPA"_temp.json

# Recupera i link condivisibili dal portale e verifica ogni nuovo dettaglio senza cookie.
# Un errore ferma lo script prima di modificare il feed pubblicato.
python3 "$folder"/resolve_links.py "$folder"/rawdata/"$iPA"_temp.json \
  "$output"/feed.xml >"$folder"/processing/atti_con_link.json

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
jq -c '.[]' "$folder"/processing/atti_con_link.json | while read -r line; do
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

  # xmlstarlet ed interpreta le entità: un '&' non escapato svuota il titolo.
  title=$(printf '%s' "$title" | xmlstarlet esc)
  link=$(printf '%s' "$link" | xmlstarlet esc)
  newcounter=$(expr $newcounter + 1)
  xmlstarlet ed -L --subnode "//channel" --type elem -n item -v "" \
    --subnode "//item[$newcounter]" --type elem -n title -v "$title" \
    --subnode "//item[$newcounter]" --type elem -n link -v "$link" \
    --subnode "//item[$newcounter]" --type elem -n pubDate -v "$pubDate" \
    --subnode "//item[$newcounter]" --type elem -n guid -v "$guid" \
    --insert "//item[$newcounter]/guid" --type attr -n isPermaLink -v false \
    "$folder"/processing/feed.xml
done

if [ "$(xmlstarlet sel -t -v 'count(//item)' "$folder"/processing/feed.xml)" -eq 0 ]; then
  echo "Errore: feed senza item, non lo pubblico" >&2
  exit 1
fi

cp "$folder"/processing/feed.xml "$output"
