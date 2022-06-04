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

# scarica prima pagina e salva codice risposta http
code=$(curl 'https://bagheria.trasparenza-valutazione-merito.it/web/trasparenza/papca-ap?p_p_id=jcitygovalbopubblicazioni_WAR_jcitygovalbiportlet&p_p_lifecycle=1&p_p_state=pop_up&p_p_mode=view&_jcitygovalbopubblicazioni_WAR_jcitygovalbiportlet_action=eseguiPaginazione' -X POST \
  -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:101.0) Gecko/20100101 Firefox/101.0' \
  -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8' \
  -H 'Accept-Language: it,en-US;q=0.7,en;q=0.3' \
  -H 'Accept-Encoding: gzip, deflate, br' \
  -H 'Referer: https://bagheria.trasparenza-valutazione-merito.it/web/trasparenza/papca-ap/-/papca/igrid/39908/24264' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -H 'Origin: https://bagheria.trasparenza-valutazione-merito.it' \
  -H 'DNT: 1' \
  -H 'Connection: keep-alive' \
  -H 'Upgrade-Insecure-Requests: 1' \
  -H 'Sec-Fetch-Dest: document' \
  -H 'Sec-Fetch-Mode: navigate' \
  -H 'Sec-Fetch-Site: same-origin' \
  -H 'Sec-Fetch-User: ?1' \
  -H 'Pragma: no-cache' \
  -H 'Cache-Control: no-cache' --data-raw 'hidden_page_size=50&hidden_page_to=' --compressed -o "$folder"/tmp.html -w "%{http_code}")

# se il server risponde fai partire lo script
if [ $code -eq 200 ]; then

  if [ -f "$folder"/rawdata/albi.json ]; then
    rm "$folder"/rawdata/albi.json
  fi

  scrape <"$folder"/tmp.html -be '//table//tr[position()>1]' | xq -c '.html.body.tr[]|{des:.td[3]."#text",inizio:.td[4]."#text",url:.td[6].a[1]."@href",id:.td[0]."#text"}' >"$folder"/rawdata/albi.json

  #html.body.tr[0]["@data-id"]
  #  # converti lista in TSV
  mlr <"$folder"/rawdata/albi.json --j2t clean-whitespace then \
    put '$inizio=sub($inizio," .+","")' then put '$rssDate = strftime(strptime($inizio, "%d/%m/%Y"),"%a, %d %b %Y %H:%M:%S %z")' \
    then put '$dataISO = strftime(strptime($inizio, "%d/%m/%Y"),"%Y-%m-%d")' \
    then put '$des=gsub($des,"<","&lt")' \
    then put '$des=gsub($des,">","&gt;")' \
    then put '$des=gsub($des,"&","&amp;")' \
    then put '$des=gsub($des,"'\''","&apos;")' \
    then put '$des=gsub($des,"\"","&quot;")' \
    then put '$url=gsub($url,"&","&amp;")' \
    then put '$url=gsub($url,"ap_page=[0-9]+&amp;","")' \
    then sort -r dataISO | tail -n +2 >"$folder"/rawdata/albi.tsv

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
  while IFS=$'\t' read -r oggetto data URL id rssData isoData; do
    newcounter=$(expr $newcounter + 1)
    titolo="$id"
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
else
  echo "sito non raggiungibile"
  exit 1
fi
