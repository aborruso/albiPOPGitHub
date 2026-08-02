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

mkdir -p "${folder}"/../docs/c_h933
mkdir -p "${folder}"/tmp

git pull

### anagrafica albo
titolo="AlboPOP del comune di San Giuseppe Jato"
descrizione="L'albo pretorio POP è una versione dell'albo pretorio del tuo comune, che puoi seguire in modo più comodo."
nomecomune="San Giuseppe Jato"
webMaster="giuragu@gmail.com (Giuseppe Ragusa)"
type="Comune"
municipality="San Giuseppe Jato"
province="Palermo"
region="Sicilia"
latitude="37.97204893237417"
longitude="13.18512860910005"
country="Italia"
name="Comune di San Giuseppe Jato"
uid="istat:082064"
docs="https://albopop.it/comune/sangiuseppejato/"
selflink="https://aborruso.github.io/albiPOPGitHub/c_h933/feed.xml"
### anagrafica albo

iPA="c_h933"

# crea cartelle di servizio
mkdir -p "$folder"/rawdata
mkdir -p "$folder"/processing
mkdir -p "$folder"/../docs/"$iPA"

# imposta la cartella di output esposta sul web
output="$folder"/../docs/"$iPA"

# URL delle pagine dell'albo, da completare con il numero di pagina
URLPag="https://servizi.comune.sangiuseppejato.pa.it/sgjato/mc/mc_p_ricerca.php?multiente=sgjato&multiente=sgjato&multiente=sgjato&pag="

# Verifica la raggiungibilità del sito dell'albo. Serve -k perché dal
# rinnovo del 27/07/2026 il server non invia il certificato intermedio
# (Actalis) e la catena non si chiude
code=$(curl -s -L -k --connect-timeout 20 --max-time 60 \
  -o /dev/null -w "%{http_code}" "${URLPag}0" || true)

if [ "$code" != "200" ]; then
  echo "Errore: sito dell'albo non raggiungibile (codice $code)" >&2
  exit 1
fi

# Crea una copia del template XML del feed
cp "$folder"/../risorse/feedTemplate.xml "$folder"/processing/feed.xml

# Inserisci i metadati anagrafici nel feed RSS
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

# Rimuovi eventuali dati temporanei precedenti
if [ -f "${folder}"/tmp/albo.jsonl ]; then
  rm "${folder}"/tmp/albo.jsonl
fi

# Scraping delle pagine dell'albo: estrai i dati tabellari per ogni pagina.
# Il download passa da curl perché scrape non sa saltare la verifica del
# certificato, che qui è incompleta lato server. La data è quella di inizio
# pubblicazione: td[3] contiene il numero di registro generale, non una data
for i in {0..5}; do
  code=$(curl -s -L -k --connect-timeout 20 --max-time 60 \
    -o "$folder"/rawdata/albo_"$i".html -w "%{http_code}" "${URLPag}${i}" || true)
  if [ "$code" != "200" ]; then
    echo "Errore: download della pagina $i fallito (codice $code)" >&2
    exit 1
  fi
  scrape -be "table tbody tr" <"$folder"/rawdata/albo_"$i".html | xq -c '.html.body.tr[] |{title: .td[1].a.div["#text"],href: .td[1].a["@href"], date: .td[4].div[0],tipo:.td[0].div[2]}' >>"${folder}"/tmp/albo.jsonl
done

# Mai svuotare il feed: se non è stato estratto nulla, meglio fallire
if [ ! -s "${folder}"/tmp/albo.jsonl ]; then
  echo "Errore: nessun dato estratto dall'albo, non aggiorno il feed" >&2
  exit 1
fi

# Normalizza i dati estratti e convertili in TSV
mlr --ijsonl --otsv unsparsify then put '$href="https://servizi.comune.sangiuseppejato.pa.it".$href;$date = strftime(strptime($date, "%d/%m/%Y"),"%a, %d %b %Y %H:%M:%S %z");$id=regextract($href,"\d+")' "${folder}"/tmp/albo.jsonl | tail -n +2 >"${folder}"/tmp/albo.tsv

# Genera gli item RSS per ogni pubblicazione trovata
newcounter=0
while IFS=$'\t' read -r oggetto URL dataInizio naturaValore numero; do
  newcounter=$(expr $newcounter + 1)
  xmlstarlet ed -L --subnode "//channel" --type elem -n item -v "" \
    --subnode "//item[$newcounter]" --type elem -n title -v "#$naturaValore | Pubblicazione numero $numero" \
    --subnode "//item[$newcounter]" --type elem -n description -v "$oggetto" \
    --subnode "//item[$newcounter]" --type elem -n link -v "$URL" \
    --subnode "//item[$newcounter]" --type elem -n pubDate -v "$dataInizio" \
    --subnode "//item[$newcounter]" --type elem -n guid -v "$URL" \
    "$folder"/processing/feed.xml
done <"${folder}"/tmp/albo.tsv

# Controlla il feed prima di pubblicarlo: niente item o date non convertite
# significano che la pagina è cambiata sotto i piedi
items=$(xmlstarlet sel -t -v "count(//item)" -n "$folder"/processing/feed.xml)
if [ "$items" -eq 0 ]; then
  echo "Errore: feed senza item, non lo pubblico" >&2
  exit 1
fi
if grep -qF "(error)" "$folder"/processing/feed.xml; then
  echo "Errore: date non convertite nel feed, non lo pubblico" >&2
  exit 1
fi

# Copia il feed generato nella cartella pubblica
cp "$folder"/processing/feed.xml "$output"

# Pulisci i file temporanei
rm -f "$folder"/tmp/albo.jsonl "$folder"/tmp/albo.tsv

