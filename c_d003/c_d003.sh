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
titolo="AlboPOP del comune di Cori"
descrizione="L'albo pretorio POP è una versione dell'albo pretorio del tuo comune, che puoi seguire in modo più comodo."
nomecomune="Cori"
webMaster="antonellamilanini@gmail.com(Antonella Milanini)"
type="Comune"
municipality="Cori"
province="Latina"
region="Lazio"
latitude="41.643171"
longitude="12.915165"
country="Italia"
name="Comune di Cori"
uid="istat:059006"
docs="https://albopop.it/comune/cori/"
selflink="https://aborruso.github.io/albiPOPGitHub/c_d003/feed.xml"
### anagrafica albo

iPA="c_d003"

#http://web11.immediaspa.com/barcellona/mc/mc_p_dettaglio.php?id_pubbl=567&x=&sto=&pag=&mittente=&oggetto=&numero=&tipo_atto=&data_dal=&data_al=&datap_dal=&datap_al=&ordin=&servizio=

# crea cartelle di servizio
mkdir -p "$folder"/rawdata
mkdir -p "$folder"/processing
mkdir -p "$folder"/../docs/"$iPA"

# imposta la cartella di output esposta sul web
output="$folder"/../docs/"$iPA"

# URL di test risposta sito albo
URLBase="https://cloud.urbi.it/urbi/progs/urp/ur1ME001.sto?DB_NAME=n1233954"

# estrai codici di risposta HTTP dell'albo
code=$(curl -s -L -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:85.0) Gecko/20100101 Firefox/85.0' -o /dev/null -w "%{http_code}" "$URLBase")

# se il server risponde fai partire lo script
if [ $code -eq 200 ]; then
  cd "$folder"
  node "$folder"/"$iPA".js

fi

# estrai soltanto le righe
scrape <"$folder"/tmp.html -be '//tbody/tr[contains(@class, "riga")]' | xq . >"$folder"/tmp.json
# estrai titolo, data e id e converti in csv
jq <"$folder"/tmp.json '.html.body.tr[]|{titolo:.td[1].div[1].strong["#text"],id:.td[2].a["@href"],data:.td[1].div[2]["#text"]}' | mlr --j2c put -S '$id=regextract($id,"[0-9]+")' >"$folder"/rawdata/"$iPA".csv

# Link dettaglio di esempio
# https://cloud.urbi.it/urbi/progs/urp/ur1ME001.sto?StwEvent=102&DB_NAME=n1233954&IdMePubblica=37

URLdettaglioPath="https://cloud.urbi.it/urbi/progs/urp/ur1ME001.sto?StwEvent=102&DB_NAME=n1233954&IdMePubblica="

mlr <"$folder"/rawdata/"$iPA".csv --c2j clean-whitespace \
  then filter -S '$data=~"dal ([0-9]{2}-[0-9]{2}-[0-9]{4})"' \
  then put -S '$pubDate=strftime(strptime(regextract(regextract($data,"dal [0-9]{2}-[0-9]{2}-[0-9]{4}"),"[0-9]{2}-[0-9]{2}-[0-9]{4}"), "%d-%m-%Y"),"%a, %d %b %Y %H:%M:%S %z");$date=strftime(strptime(regextract(regextract($data,"dal [0-9]{2}-[0-9]{2}-[0-9]{4}"),"[0-9]{2}-[0-9]{2}-[0-9]{4}"), "%d-%m-%Y"),"%Y-%m-%d");$link="'"$URLdettaglioPath"'".$id' \
  then put '$titolo=gsub($titolo,">","&gt;")' \
  then put '$titolo=gsub($titolo,"&","&amp;")' \
  then put '$titolo=gsub($titolo,"'\''","&apos;")' \
  then put '$titolo=gsub($titolo,"\"","&quot;")' \
  then put '$link=gsub($link,"&","&amp;")' >"$folder"/rawdata/"$iPA".json

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
cat "$folder"/rawdata/"$iPA".json| while read line; do
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
