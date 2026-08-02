#!/bin/bash

set -x
set -e
set -u
set -o pipefail

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Niente retry qui dentro: la fonte blocca per IP e sul runner l'indirizzo
# resta lo stesso, quindi ritentare non cambia esito. Il secondo tentativo
# lo fa il workflow, su un runner nuovo
rsspls -c "${folder}"/feeds.toml
