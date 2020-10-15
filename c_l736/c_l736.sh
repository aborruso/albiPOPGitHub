#!/bin/bash

set -x

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

iPA="c_l736"

mkdir -p "$folder"/rawdata
mkdir -p "$folder"/processing
mkdir -p "$folder"/../docs/"$iPA"

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# imposta la cartella di output esposta sul web
output="$folder"/../docs/"$iPA"

URLBase="https://portale.comune.venezia.it/sites/all/modules/yui_venis/albo.php?tipo=json"

mkdir -p "$folder"/rawdata
mkdir -p "$folder"/processing

code=$(curl -s -L -o /dev/null -w "%{http_code}" 'http://www.comune.patti.me.it/index.php?option=com_albopretorio&id_Miky=_0')

# download dati
if [ $code -eq 200 ]; then

  # scarica lista
  curl -kL "$URLBase" | jq . >"$folder"/rawdata/albo.json

  # converti lista in TSV
  jq <"$folder"/rawdata/albo.json '.atti[]' | mlr --j2t unsparsify | tail -n +2 | head -n 30 >"$folder"/rawdata/albo.tsv

  rm "$folder"/rawdata/dettagli.json

  # scarica dettagli di ogni atto
  while IFS=$'\t' read -r anno numero dataInizio dataFine esibente oggetto sede; do
    curl -kL "https://portale.comune.venezia.it/sites/all/modules/yui_venis/alboDetail.php?tipo=JSON&anno=$anno&numero=$numero&sede=$sede" >>"$folder"/rawdata/dettagli.json
    echo -e "\n" >>"$folder"/rawdata/dettagli.json
  done <"$folder"/rawdata/albo.tsv

  # genera CSV dei dettagli
  mlr <"$folder"/rawdata/dettagli.json --j2c unsparsify >"$folder"/rawdata/dettagli.csv

fi
