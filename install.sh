#!/usr/bin/env bash
# Installs or updates Oma Tab itself (the Fcitx addon, Ollama, and a model).
# The bar widget runs this in a floating terminal when a person presses
# Install or Update; nothing runs it on its own.
#
# Every run builds from a throwaway checkout of one exact commit, with Git's
# own configuration, hooks, and non-HTTPS transports switched off, so no
# state left over from a previous install can influence what gets built or
# executed. The verified tree only replaces the installed one after the build
# and install have succeeded.
set -euo pipefail

readonly repo_url=https://github.com/r3dbars/omatab.git
readonly OMATAB_COMMIT=60accc4dfff851fa08b1800bfc49ededcb23e26d
readonly source_root=$HOME/.local/src
readonly source_dir=$source_root/omatab

fail() { echo "install.sh: $*" >&2; exit 1; }

[[ $OMATAB_COMMIT =~ ^[0-9a-f]{40}$ ]] || fail "OMATAB_COMMIT is not a full commit id"
command -v git >/dev/null || fail "git is required"

# Git with nothing configurable left in play: no system, global, or
# repository config to define a filter or alias, no hooks, no protocols but
# HTTPS, and no credential prompts.
git_pinned() {
  GIT_CONFIG_GLOBAL=/dev/null \
  GIT_CONFIG_SYSTEM=/dev/null \
  GIT_CONFIG_NOSYSTEM=1 \
  GIT_TERMINAL_PROMPT=0 \
  GIT_ASKPASS=/bin/false \
  GIT_ATTR_NOSYSTEM=1 \
  git -c core.hooksPath=/dev/null \
      -c core.fsmonitor=false \
      -c core.attributesFile=/dev/null \
      -c protocol.allow=never \
      -c protocol.https.allow=always \
      "$@"
}

# The destination is fixed under $HOME. Refuse anything that is not a plain
# directory owned by this user, and refuse symlinks anywhere in the path so a
# checkout can never be redirected somewhere else.
home_real=$(realpath -e -- "$HOME") || fail "cannot resolve HOME"
[[ $source_root == "$home_real/.local/src" ]] || fail "unexpected source root"
mkdir -p -- "$source_root"
for part in "$home_real/.local" "$source_root"; do
  [[ -d $part && ! -L $part && -O $part ]] || fail "$part must be a directory owned by you, not a symlink"
done
if [[ -e $source_dir || -L $source_dir ]]; then
  [[ -d $source_dir && ! -L $source_dir && -O $source_dir ]] ||
    fail "$source_dir must be a directory owned by you, not a symlink"
  [[ $(realpath -e -- "$source_dir") == "$source_dir" ]] ||
    fail "$source_dir does not resolve to itself"
fi

# A private staging directory per run. Nothing in it survives a failure, and
# nothing from a previous run is ever reused.
staging=$(mktemp -d -- "$source_root/.omatab-staging.XXXXXXXX") ||
  fail "cannot create a staging directory in $source_root"
checkout=$staging/src
template=$staging/empty-template
cleanup() { [[ -n ${staging:-} && -d $staging ]] && rm -rf -- "$staging"; }
trap cleanup EXIT
mkdir -m 700 -- "$template" "$checkout"

# An empty template means the new repository gets no sample hooks at all.
echo "Fetching Oma Tab ${OMATAB_COMMIT:0:12}"
git_pinned init --quiet --template="$template" -- "$checkout"
git_pinned -C "$checkout" remote add origin "$repo_url"
git_pinned -C "$checkout" fetch --quiet --depth=1 --no-tags origin "$OMATAB_COMMIT" ||
  git_pinned -C "$checkout" fetch --quiet --no-tags origin "$OMATAB_COMMIT" ||
  fail "cannot fetch $OMATAB_COMMIT from $repo_url"

[[ $(git_pinned -C "$checkout" cat-file -t "$OMATAB_COMMIT") == commit ]] ||
  fail "the pinned object is not a commit"
git_pinned -C "$checkout" checkout --quiet --detach "$OMATAB_COMMIT"
[[ $(git_pinned -C "$checkout" rev-parse HEAD) == "$OMATAB_COMMIT" ]] ||
  fail "checkout did not land on the pinned commit"
[[ -z $(git_pinned -C "$checkout" status --porcelain) ]] ||
  fail "the checkout does not match the pinned commit"

bootstrap=$checkout/scripts/bootstrap.sh
[[ -f $bootstrap && ! -L $bootstrap ]] || fail "$bootstrap is missing from the pinned commit"

# Build and install from the fresh tree. OMATAB_SOURCE_HOME tells it where
# that tree will live once this succeeds.
OMATAB_SOURCE_HOME=$source_dir bash -- "$bootstrap" "$@"

# Only now replace the installed source tree, build directory and all.
previous=$staging/previous
if [[ -d $source_dir ]]; then
  mv -- "$source_dir" "$previous"
fi
mv -- "$checkout" "$source_dir"
echo "Oma Tab source is now $source_dir at ${OMATAB_COMMIT:0:12}"
