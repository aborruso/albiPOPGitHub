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

# rsspls risolve l'output del feeds.toml rispetto alla directory corrente,
# non al file di configurazione: senza questo cd il feed finirebbe fuori
# posto quando lo script è lanciato da altrove
cd "$folder"

git pull

rsspls -c "$folder"/feeds.toml

feed="$folder"/../docs/c_a546/feed.xml

# Il portale rigenera il token p_auth a ogni richiesta e lo infila nei link
# degli atti: senza rimuoverlo i guid cambierebbero ogni volta e i lettori
# RSS riproporrebbero come nuovi degli atti già visti. Il dettaglio resta
# raggiungibile anche senza token
sed -i -E 's/p_auth=[A-Za-z0-9]+&amp;//g; s/[?&]p_auth=[A-Za-z0-9]+//g' "$feed"

if grep -q "p_auth" "$feed"; then
  echo "Errore: token p_auth ancora presente nel feed" >&2
  exit 1
fi

# Mai svuotare il feed: se non ci sono item la pagina è cambiata
items=$(xmlstarlet sel -t -v "count(//item)" -n "$feed")
if [ "$items" -eq 0 ]; then
  echo "Errore: feed senza item, la pagina è cambiata" >&2
  exit 1
fi
