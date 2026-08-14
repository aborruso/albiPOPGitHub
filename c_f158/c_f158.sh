#!/bin/bash

# Estrae l'albo di Messina e genera un feed RSS solo con CLI (curl, scrape, xq, jq, xmlstarlet).

set -euo pipefail

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
output_dir="$folder/../docs/c_f158"
raw_dir="$folder/rawdata"
processing_dir="$folder/processing"
mkdir -p "$output_dir" "$raw_dir" "$processing_dir"

src_url="https://amministrazione-trasparente.comune.messina.it/web/trasparenza/papca-ap/-/papca/igrid/495/189"
json_tmp="$raw_dir/messina.json"
feed_tmp="$processing_dir/feed.xml"
feed_out="$output_dir/feed.xml"
cookie_file="$processing_dir/cookies.txt"

# 0) Pulisci temporanei
rm -f "$cookie_file" "$raw_dir"/page_*.json

# scarica una pagina mantenendo la sessione: la fonte a volte resta appesa,
# quindi timeout e retry, e si controlla il codice HTTP
fetch_page() {
  local url="$1" out="$2" code
  code=$(curl -ksL -c "$cookie_file" -b "$cookie_file" \
    --connect-timeout 20 --max-time 60 \
    --retry 3 --retry-delay 3 --retry-connrefused --retry-all-errors \
    -w "%{http_code}" -o "$out" "$url" || true)
  if [ "$code" != "200" ]; then
    echo "Errore download ($code): $url" >&2
    return 1
  fi
}

# 1) Scarica le prime 3 pagine mantenendo la sessione (cookie)
pagination_next="https://amministrazione-trasparente.comune.messina.it/web/trasparenza/papca-ap?p_p_id=jcitygovalbopubblicazioni_WAR_jcitygovalbiportlet&p_p_lifecycle=0&p_p_state=pop_up&p_p_mode=view&_jcitygovalbopubblicazioni_WAR_jcitygovalbiportlet_paginationAction=NEXT&_jcitygovalbopubblicazioni_WAR_jcitygovalbiportlet_action=mostraLista"

page=1
current_url="$src_url"
while [ $page -le 3 ]; do
  html_tmp="$raw_dir/page_${page}.html"
  json_page="$raw_dir/page_${page}.json"
  fetch_page "$current_url" "$html_tmp"
  cat "$html_tmp" \
    | scrape -be "//tr[contains(@class, 'master-detail-list-line')]" \
    | xq . >"$json_page"
  # una pagina vuota significa fonte non pronta: fermarsi qui, perché
  # proseguire pubblicherebbe un feed troncato senza segnalare nulla
  righe=$(jq '[.html.body.tr] | flatten | map(select(. != null)) | length' "$json_page" 2>/dev/null || true)
  if [ "${righe:-0}" -eq 0 ]; then
    echo "Errore: nessuna riga estratta dalla pagina $page, non aggiorno il feed" >&2
    exit 1
  fi
  current_url="$pagination_next"
  page=$((page+1))
done

# 1b) Unisci tutte le righe in un unico JSON
jq -s '{html:{body:{tr:(map(.html.body.tr) | add)}}}' "$raw_dir"/page_*.json >"$json_tmp"

# 2) Crea feed di base dal template
cp "$folder"/../risorse/feedTemplate.xml "$feed_tmp"
xmlstarlet ed -L \
  --subnode "//channel" --type elem -n title -v "AlboPOP del comune di Messina" \
  --subnode "//channel" --type elem -n link -v "$src_url" \
  --subnode "//channel" --type elem -n description -v "Pubblicazioni dall'albo pretorio di Messina" \
  "$feed_tmp"

# 3) Estrai righe utili (titolo, link, periodo) e appendi item
idx=0
jq -r '.html.body.tr[]
 | [
     (.td[3]."#text"),          # descrizione (oggetto)
     (.td[6].a[-1]."@href"),
     (.td[4]."#text"),
     (.td[0]."#text"),          # numero/registro come title
     (
       .td[4]."#text"
       | split(" ")
       | map(select(length>0))
       | .[0]
       | try (strptime("%d/%m/%Y") | mktime | strftime("%a, %d %b %Y 00:00:00 %z")) catch ""
     )
   ] | @tsv' "$json_tmp" \
| while IFS=$'\t' read -r descr link period title pubdate; do
    idx=$((idx+1))
    xmlstarlet ed -L \
      --subnode "//channel" --type elem -n item -v "" \
      --subnode "//item[$idx]" --type elem -n title -v "$title" \
      --subnode "//item[$idx]" --type elem -n link -v "$link" \
      --subnode "//item[$idx]" --type elem -n guid -v "$link" \
      --subnode "//item[$idx]" --type elem -n description -v "$descr" \
      ${pubdate:+--subnode "//item[$idx]" --type elem -n pubDate -v "$pubdate"} \
      "$feed_tmp"
  done

cp "$feed_tmp" "$feed_out"
echo "Feed scritto in $feed_out"
