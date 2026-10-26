#!/bin/bash

set -e
set -u
set -o pipefail

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src_dir="$(cd "${folder}/.." && pwd)"

# Fonte. Gli IP dei runner GitHub sono geoblocati dalla PA: la connessione
# diretta fallisce sempre con "client error (Connect)". Per aggirarlo
# scarichiamo la pagina via Tor, con uscita forzata dall'Italia
# (ExitNodes {it}, impostato nel workflow), come c_a893.
# Si scarica il file con curl, lo si dà a rsspls in locale
# (file_urls = true) e si riparano i link.

BASE="https://servizi.comune.barcellonapozzodigotto.me.it"
RELROOT="/barcellona"
URL="${BASE}${RELROOT}/mc/mc_p_ricerca.php"
OUT="${src_dir}/docs/c_a638"

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

raw="${work}/albo.html"
html="${work}/albo_utf8.html"
conf="${work}/feeds.toml"

# 1) scarica la pagina via Tor; i tentativi coprono anche l'avvio di Tor
curl -fsS -m 90 --retry 3 --retry-delay 10 --retry-all-errors \
  --socks5-hostname localhost:9050 \
  "${URL}" -o "${raw}"

# 2) rsspls richiede UTF-8; la pagina arriva in iso-8859-1
iconv -f iso-8859-1 -t utf-8 "${raw}" -o "${html}"

# 3) config temporanea: abilita i file locale e punta il feed alla pagina
#    scaricata, lasciando tutto il resto (selectors, date) invariato
sed -e '/^output =/a file_urls = true' \
    -e "s|^url = .*|url = \"file://${html}\"|" \
    "${folder}/feeds.toml" > "${conf}"

# 4) genera il feed dal file locale
rsspls -c "${conf}" -o "${OUT}"

# 5) con base file:// i link relativi (/barcellona/...) escono come
#    file:///barcellona/... : li riporta in assoluti (link e guid insieme)
sed -i "s|file://${RELROOT}/|${BASE}${RELROOT}/|g" "${OUT}/feed.xml"

# 5b) il <link> di canale è la pagina stessa: da file://... alla fonte reale
sed -i "s|<link>file://${html}</link>|<link>${URL}</link>|" "${OUT}/feed.xml"
