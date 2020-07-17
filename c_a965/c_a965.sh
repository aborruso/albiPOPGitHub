#!/bin/bash

set -x

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

iPA="c_a965"

mkdir -p "$folder"/rawdata
mkdir -p "$folder"/processing
mkdir -p "$folder"/../docs/"$iPA"

# imposto la cartella di output esposta sul web
output="$folder"/../docs/"$iPA"

#### Download, clean e merge dei dati ####

curl -s -A "Mozilla/5.0 (iPhone; U; CPU iPhone OS 4_3_3 like Mac OS X; en-us) AppleWebKit/533.17.9 (KHTML, like Gecko) Version/5.0.2 Mobile/8J2 Safari/6533.18.5" "http://sac2.halleysac.it/c038003/mc/mc_p_ricerca.php?multiente=c038003&pag=0" | scrape -be '//table[@id="table-albo-pretorio"]/tbody/tr' | xq '[.html.body.tr[]|{"pubDate":.td[4]["#text"],"title":.td[2].a.span["#text"],"id":.td[2].a["@data-id"]}]' | mlr --j2c clean-whitespace >"$folder"/rawdata/01.csv
curl -s -A "Mozilla/5.0 (iPhone; U; CPU iPhone OS 4_3_3 like Mac OS X; en-us) AppleWebKit/533.17.9 (KHTML, like Gecko) Version/5.0.2 Mobile/8J2 Safari/6533.18.5" "http://sac2.halleysac.it/c038003/mc/mc_p_ricerca.php?multiente=c038003&pag=1" | scrape -be '//table[@id="table-albo-pretorio"]/tbody/tr' | xq '[.html.body.tr[]|{"pubDate":.td[4]["#text"],"title":.td[2].a.span["#text"],"id":.td[2].a["@data-id"]}]' | mlr --j2c clean-whitespace >"$folder"/rawdata/02.csv
curl -s -A "Mozilla/5.0 (iPhone; U; CPU iPhone OS 4_3_3 like Mac OS X; en-us) AppleWebKit/533.17.9 (KHTML, like Gecko) Version/5.0.2 Mobile/8J2 Safari/6533.18.5" "http://sac2.halleysac.it/c038003/mc/mc_p_ricerca.php?multiente=c038003&pag=2" | scrape -be '//table[@id="table-albo-pretorio"]/tbody/tr' | xq '[.html.body.tr[]|{"pubDate":.td[4]["#text"],"title":.td[2].a.span["#text"],"id":.td[2].a["@data-id"]}]' | mlr --j2c clean-whitespace >"$folder"/rawdata/03.csv
curl -s -A "Mozilla/5.0 (iPhone; U; CPU iPhone OS 4_3_3 like Mac OS X; en-us) AppleWebKit/533.17.9 (KHTML, like Gecko) Version/5.0.2 Mobile/8J2 Safari/6533.18.5" "http://sac2.halleysac.it/c038003/mc/mc_p_ricerca.php?multiente=c038003&pag=3" | scrape -be '//table[@id="table-albo-pretorio"]/tbody/tr' | xq '[.html.body.tr[]|{"pubDate":.td[4]["#text"],"title":.td[2].a.span["#text"],"id":.td[2].a["@data-id"]}]' | mlr --j2c clean-whitespace >"$folder"/rawdata/04.csv

mlr --csv --ofs "|" cat "$folder"/rawdata/0*.csv >"$folder"/processing/input.csv

#### Costruisco il feed RSS ####

# variabili per la costruzione del feed RSS
nomeFeed="Albo Pretorio Comune di Bondeno"
descrizioneFeed="Il feed RSS dell'Albo Pretorio Comune di Bondeno"
PageSource="https://aborruso.github.io/albiPOPGitHub/$iPA/feed_rss.xml"

intestazioneRSS="<rss version=\"2.0\"><channel><title>$nomeFeed</title><description>$descrizioneFeed</description><link>$PageSource</link>"

chiusuraRSS="</channel></rss>"
# variabili per la costruzione del feed RSS

#cancello file, in modo che l'output del feed sia riempito sempre a partire da file "vuoti"
rm "$folder"/processing/out.xml
rm "$folder"/processing/feed.xml

#rimuovo intestazione dal file csv
sed -e '1d' "$folder"/processing/input.csv >"$folder"/processing/input_nohead.csv

# ciclo per ogni riga del csv per creare il corpo del file RSS
INPUT="$folder"/processing/input_nohead.csv
OLDIFS=$IFS
IFS="|"
[ ! -f $INPUT ] && {
  echo "$INPUT file not found"
  exit 99
}
while read pubDate title id; do

  # riformatto la data in formato compatibile RSS, ovvero RFC 822, altrimenti il feed RSS non passa la validazione
  OLD_IFS="$IFS"
  IFS="/"
  STR_ARRAY=($pubDate)
  IFS="$OLD_IFS"
  anno=${STR_ARRAY[2]}
  mese=${STR_ARRAY[1]}
  giorno=${STR_ARRAY[0]}
  dataok=$(LANG=en_EN date -Rd "$anno-$mese-$giorno")

  URLINT="http://sac2.halleysac.it/c038003/mc/mc_p_dettaglio.php?id_pubbl="

  # creo il corpo del feed RSS
  echo "<item><title>$title</title><link>$URLINT$id</link><pubDate>$dataok</pubDate></item>" >>"$folder"/processing/out.xml

done <$INPUT
IFS=$OLDIFS

# creo il feed RSS, facendo il merge di intestazione, corpo e piede
echo "$intestazioneRSS" >>"$folder"/processing/feed.xml
cat "$folder"/processing/out.xml >>"$folder"/processing/feed.xml
echo "$chiusuraRSS" >>"$folder"/processing/feed.xml

cat "$folder"/processing/feed.xml >"$output"/feed_rss.xml
