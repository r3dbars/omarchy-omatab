#!/usr/bin/env bash
# Installs or updates Oma Tab itself (the Fcitx addon, Ollama, and a model).
# The bar widget runs this in a floating terminal when a person presses
# Install or Update; nothing runs it on its own.
#
# Oma Tab is fetched from one fixed repository into one fixed directory and
# pinned to one exact commit, checked out detached, so each release of this
# widget installs a known version. Bump OMATAB_COMMIT to ship a newer Oma Tab.
set -euo pipefail

readonly repo_url=https://github.com/r3dbars/omatab.git
readonly OMATAB_COMMIT=cc005563b186ae9757a6d32080365ea7c9837a5c
readonly source_dir=$HOME/.local/src/omatab

fail() { echo "install.sh: $*" >&2; exit 1; }

[[ $OMATAB_COMMIT =~ ^[0-9a-f]{40}$ ]] || fail "OMATAB_COMMIT is not a full commit id"
command -v git >/dev/null || fail "git is required"

# The destination is fixed under $HOME. Refuse anything that is not a plain
# directory owned by this user, and refuse symlinks anywhere in the path so a
# checkout can never be redirected somewhere else.
home_real=$(realpath -e -- "$HOME") || fail "cannot resolve HOME"
mkdir -p -- "$home_real/.local/src"
for part in "$home_real/.local" "$home_real/.local/src"; do
  [[ -d $part && ! -L $part && -O $part ]] || fail "$part must be a directory owned by you, not a symlink"
done
if [[ -e $source_dir || -L $source_dir ]]; then
  [[ -d $source_dir && ! -L $source_dir && -O $source_dir ]] ||
    fail "$source_dir must be a directory owned by you, not a symlink"
  [[ $(realpath -e -- "$source_dir") == "$home_real/.local/src/omatab" ]] ||
    fail "$source_dir does not resolve to itself"
fi

if [[ ! -d $source_dir/.git ]]; then
  [[ ! -e $source_dir ]] || [[ -z $(ls -A -- "$source_dir") ]] ||
    fail "$source_dir exists but is not an Oma Tab checkout; move it aside"
  echo "Downloading Oma Tab to $source_dir"
  git clone --quiet --no-checkout -- "$repo_url" "$source_dir"
fi

# An existing checkout must be ours: same origin, no other remotes.
[[ -d $source_dir/.git && ! -L $source_dir/.git ]] || fail "$source_dir/.git is not a directory"
origin=$(git -C "$source_dir" remote get-url origin 2>/dev/null || true)
[[ $origin == "$repo_url" ]] || fail "$source_dir has origin '$origin', expected $repo_url"
[[ $(git -C "$source_dir" remote | wc -l) -eq 1 ]] || fail "$source_dir has unexpected extra remotes"

echo "Checking out Oma Tab ${OMATAB_COMMIT:0:12}"
git -C "$source_dir" fetch --quiet -- origin "$OMATAB_COMMIT"
[[ $(git -C "$source_dir" cat-file -t "$OMATAB_COMMIT") == commit ]] || fail "pinned object is not a commit"
git -C "$source_dir" checkout --quiet --detach --force "$OMATAB_COMMIT"
git -C "$source_dir" clean -fdxq -e build
[[ $(git -C "$source_dir" rev-parse HEAD) == "$OMATAB_COMMIT" ]] || fail "checkout did not land on the pinned commit"

bootstrap=$source_dir/scripts/bootstrap.sh
[[ -f $bootstrap && ! -L $bootstrap ]] || fail "$bootstrap is missing from the pinned commit"
exec bash -- "$bootstrap" "$@"
