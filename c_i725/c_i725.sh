#!/bin/bash

set -x
set -e
set -u
set -o pipefail

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# rsspls -c "$folder"/feeds.toml

google-chrome-stable --headless --disable-gpu --print-to-stdout --virtual-time-budget=10000 --dump-dom "https://siderno.trasparenza-valutazione-merito.it/web/trasparenza/papca-ap/-/papca/igrid/1074/770" >"${folder}"/../docs/c_i725/index.html
