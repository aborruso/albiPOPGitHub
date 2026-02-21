#!/bin/bash

### requisiti ###
# mlr https://github.com/johnkerl/miller
# xmlstarlet http://xmlstar.sourceforge.net/
# jq https://github.com/stedolan/jq
# scrape-cli per estrazione HTML
### requisiti ###

set -x
#set -e
#set -u
#set -o pipefail

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

# URL base per l'albo pretorio di Giovinazzo
URL_BASE="https://servizi.comune.giovinazzo.ba.it/openweb/albo/albo_pretorio.php"
# Opzioni HTTP robuste per ridurre errori transienti lato server/proxy
curl_user_agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36"
curl_common_opts=(-k -s -L --http1.1 -A "$curl_user_agent" --connect-timeout 20 --max-time 60 --retry 4 --retry-delay 2 --retry-connrefused --retry-all-errors)

# crea cartelle di servizio
mkdir -p "$folder"/rawdata
mkdir -p "$folder"/processing
mkdir -p "$folder"/../docs/"$iPA"

# imposta la cartella di output esposta sul web
output="$folder"/../docs/"$iPA"

# scarica dati delle pagine con parametri semplificati (senza token CSRF)
allData=""
# Pagina 1 (default), poi pagine 2, 3, 4, 5 con parametri page e start
for page_info in "1:0" "2:16" "3:31" "4:46" "5:61"; do
  page_num=$(echo $page_info | cut -d':' -f1)
  start_val=$(echo $page_info | cut -d':' -f2)

  if [ $page_num -eq 1 ]; then
    page_url="$URL_BASE"
  else
    page_url="${URL_BASE}?tabella_albo%5Bpage%5D=${page_num}&tabella_albo%5Bstart%5D=${start_val}"
  fi

  echo "Scaricando pagina $page_num: $page_url"

  # Temporary workaround: source certificate expired (remove -k once cert is renewed)
  code=$(curl "${curl_common_opts[@]}" -w "%{http_code}" "$page_url" -o "$folder"/rawdata/pagina_${page_num}.html)

  # se il server risponde elabora la pagina
  if [ $code -eq 200 ]; then
    echo "Pagina $page_num scaricata correttamente"
    
    # verifica che il file non sia vuoto
    if [ ! -s "$folder"/rawdata/pagina_${page_num}.html ]; then
      echo "ERRORE: File pagina_${page_num}.html vuoto o non esistente"
      continue
    fi
    
    # conta elementi nella pagina per debug
    elem_count=$(grep -c 'paginated_element' "$folder"/rawdata/pagina_${page_num}.html || echo "0")
    echo "Elementi 'paginated_element' trovati in pagina $page_num: $elem_count"

    # converti HTML in JSON ed estrai dati (senza redirect errori per debug)
    pageData=$(scrape -be '//tbody/tr[@class="paginated_element"]' < "$folder"/rawdata/pagina_${page_num}.html | \
      xq -c '.html.body.tr[]? | {
        numero: .td[0].a."#text",
        titolo: .td[1],
        atto: .td[2],
        data_affissione: .td[3],
        fine_pubblicazione: .td[4],
        url: .td[0].a."@href"
      }')

    if [ ! -z "$pageData" ]; then
      allData="$allData$pageData"$'\n'
      echo "Dati estratti da pagina $page_num"
    else
      echo "ATTENZIONE: Nessun dato estratto da pagina $page_num"
    fi
  else
    echo "Errore nel download pagina $page_num: codice $code"
  fi
done

# salva tutti i dati estratti, garantendo che sia un array valido
echo "$allData" | tr '\n' ' ' | jq -s '. | map(select(. != null)) | unique_by(.url)' > "$folder"/rawdata/elenco.json

# verifica che ci siano dati
if [ ! -s "$folder"/rawdata/elenco.json ]; then
  echo "Nessun dato estratto, uscita"
  exit 1
fi

fileContent=$(cat "$folder"/rawdata/elenco.json)
if [ "$fileContent" = "[]" ]; then
  echo "Array vuoto, nessun dato estratto"
  exit 1
fi

# converti in TSV con mlr e normalizza dati
jq -c '.[]' "$folder"/rawdata/elenco.json | \
mlr --ijson --otsv clean-whitespace then \
  put 'if ($data_affissione =~ "^[0-9]{2}/[0-9]{2}/[0-9]{4}") {
    $date = $data_affissione
  } else {
    $date = $data_affissione
  }' then \
  put '$rssDate = strftime(strptime($date, "%d/%m/%Y"),"%a, %d %b %Y %H:%M:%S %z")' then \
  put '$titolo = $numero . " - " . $titolo' then \
  put '$titolo=gsub($titolo,"<","&lt;")' then \
  put '$titolo=gsub($titolo,">","&gt;")' then \
  put '$titolo=gsub($titolo,"&","&amp;")' then \
  put '$titolo=gsub($titolo,"'\''","&apos;")' then \
  put '$titolo=gsub($titolo,"\"","&quot;")' then \
  put '$titolo=gsub($titolo,"°","&#176;")' then \
  put '$titolo=gsub($titolo,"–","&#8211;")' then \
  put 'if ($url =~ "^/") {$url = "https://servizi.comune.giovinazzo.ba.it" . $url} else {$url = $url}' then \
  put 'if ($url =~ "^/") {$url = "https://servizi.comune.giovinazzo.ba.it" . $url} else {$url = $url}' then \
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

# leggi in loop i dati del file TSV e usali per creare nuovi item nel file XML
newcounter=0
while IFS=$'\t' read -r numero titolo atto data_affissione fine_pubblicazione url date rssDate; do
  # salta la riga di intestazione
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

# copia il feed nella cartella docs per pubblicazione
cp "$folder"/processing/feed.xml "$output"

# pulizia file temporanei
rm -f "$folder"/rawdata/pagina_*.html

echo "Feed RSS creato con successo: $output/feed.xml"
echo "Numero di item generati: $newcounter"

git pull origin master
