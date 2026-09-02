#!/usr/bin/env bash
# Installs or updates Oma Tab itself (the Fcitx addon, Ollama, and a model).
# The bar widget runs this in a floating terminal when a person presses
# Install or Update; nothing runs it on its own.
#
# Oma Tab is fetched from its repository and pinned to one exact commit,
# checked out detached, so each release of this widget installs a known
# version. Bump OMATAB_COMMIT to ship a newer Oma Tab.
set -euo pipefail

repo_url=https://github.com/r3dbars/omatab.git
OMATAB_COMMIT=cc005563b186ae9757a6d32080365ea7c9837a5c
source_dir=${OMATAB_SOURCE_DIR:-$HOME/.local/src/omatab}

if [[ ! -d $source_dir/.git ]]; then
  echo "Downloading Oma Tab to $source_dir"
  mkdir -p "$(dirname "$source_dir")"
  git clone --no-checkout "$repo_url" "$source_dir"
fi

echo "Checking out Oma Tab ${OMATAB_COMMIT:0:12}"
git -C "$source_dir" fetch --quiet origin "$OMATAB_COMMIT"
git -C "$source_dir" checkout --quiet --detach "$OMATAB_COMMIT"

exec "$source_dir/scripts/bootstrap.sh" "$@"
