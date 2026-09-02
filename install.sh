#!/usr/bin/env bash
# Installs or updates Oma Tab itself (the Fcitx addon, Ollama, and a model).
# The bar widget runs this in a floating terminal; it also works by hand.
set -euo pipefail

repo_url=${OMATAB_REPO_URL:-https://github.com/r3dbars/tilde-linux.git}
source_dir=${OMATAB_SOURCE_DIR:-$HOME/.local/src/omatab}
state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/omatab

# A checkout recorded by an earlier install wins, so developers who build
# from their own working copy keep updating that copy.
if [[ -s $state_dir/source_dir ]]; then
  recorded=$(<"$state_dir/source_dir")
  [[ -f $recorded/scripts/bootstrap.sh ]] && source_dir=$recorded
fi

if [[ -d $source_dir/.git ]]; then
  echo "Updating $source_dir"
  git -C "$source_dir" pull --ff-only
else
  echo "Downloading Oma Tab to $source_dir"
  mkdir -p "$(dirname "$source_dir")"
  git clone --depth 1 "$repo_url" "$source_dir"
fi

exec "$source_dir/scripts/bootstrap.sh" "$@"
