#!/bin/bash

set -x
set -e
set -u
set -o pipefail

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Retry wrapper for rsspls (handles transient network errors)
retry_rsspls() {
  local max_attempts=3
  local wait_seconds=10
  local attempt=1

  while [ $attempt -le $max_attempts ]; do
    echo "rsspls attempt $attempt of $max_attempts..."
    if rsspls -c "$1"; then
      return 0
    fi

    if [ $attempt -lt $max_attempts ]; then
      echo "Failed. Waiting ${wait_seconds}s before retry..."
      sleep $wait_seconds
    fi
    attempt=$((attempt + 1))
  done

  echo "All $max_attempts rsspls attempts failed."
  return 1
}

retry_rsspls "${folder}"/feeds.toml
