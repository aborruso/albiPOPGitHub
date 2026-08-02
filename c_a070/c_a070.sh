#!/bin/bash

set -x
set -e
set -u
set -o pipefail

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
iPA="c_a070"

git pull

# proxy opzionale (secret PROXY_URL): fallback quando la fonte blocca gli IP
# dei runner GitHub Actions. Vuoto in locale -> solo richiesta diretta.
PROXY_URL="${PROXY_URL:-}"

# tentativo diretto
if rsspls -c "$folder"/feeds.toml; then
  echo "fetch: diretto"
  exit 0
fi

if [ -z "$PROXY_URL" ]; then
  echo "Errore: fonte non raggiungibile e PROXY_URL non impostato" >&2
  exit 1
fi

url=$(grep -oP '^url = "\K[^"]+' "$folder"/feeds.toml)
output="$folder"/../docs/"$iPA"

# verifica che il proxy risponda, prima di rigenerare il feed
code=$(curl -s -L --connect-timeout 20 --max-time 90 \
  --retry 3 --retry-delay 3 --retry-connrefused --retry-all-errors \
  --compressed -w "%{http_code}" -o /dev/null "${PROXY_URL}${url}" || true)
if [ "$code" != "200" ]; then
  echo "Errore: anche il proxy fallisce (codice $code)" >&2
  exit 1
fi

# si lavora fuori dal repo: il workflow fa "git add -A" e il valore del
# secret non deve mai finire in un commit
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# feeds.toml temporaneo con url proxato e output assoluto (il file non sta
# più accanto a docs/). awk e non sed: il secret può contenere metacaratteri
awk -v out="$tmpdir" -v u="${PROXY_URL}${url}" '
  /^output = / { print "output = \"" out "\""; next }
  /^url = /    { print "url = \"" u "\""; next }
  { print }
' "$folder"/feeds.toml > "$tmpdir"/feeds.toml

rsspls -c "$tmpdir"/feeds.toml
echo "fetch: via proxy"

# il proxy può rispondere 200 con una pagina che non matcha i selettori:
# meglio fallire che pubblicare un feed vuoto al posto di uno buono
if [ ! -s "$tmpdir"/feed.xml ]; then
  echo "Errore: rsspls non ha prodotto il feed via proxy" >&2
  exit 1
fi
items=$(xmlstarlet sel -t -v "count(//item)" -n "$tmpdir"/feed.xml)
if [ "$items" -eq 0 ]; then
  echo "Errore: feed via proxy senza item, non lo pubblico" >&2
  exit 1
fi

# il feed generato riporta l'URL proxato nel link del canale: si ripristina
# l'URL reale, così il secret non finisce in docs/ né nella history git
sed -i "s|${PROXY_URL}||g" "$tmpdir"/feed.xml

if grep -qF "$PROXY_URL" "$tmpdir"/feed.xml; then
  echo "Errore: il feed contiene ancora l'URL del proxy, non lo pubblico" >&2
  exit 1
fi

cp "$tmpdir"/feed.xml "$output"/feed.xml
