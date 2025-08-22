#!/bin/bash

set -eu

#
# c_b645
#

#
# init
#

cd "$(dirname "$0")"

#
# clean
#

rm -f \
  ../docs/c_b645/feed.xml

#
# feeds
#

python3 ./extract_feed.py > ../docs/c_b645/feed.xml

#
# docs
#

mkdir -p ../docs/c_b645


