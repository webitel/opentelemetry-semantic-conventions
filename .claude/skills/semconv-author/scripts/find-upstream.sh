#!/usr/bin/env bash
# Search the upstream semantic conventions this registry depends on for a name.
#
# usage: find-upstream.sh [--genai] <regex>
#   <regex>   extended regex matched against attribute ids, metric names,
#             span/event names and enum member values, e.g. 'queue|dead.?letter'
#   --genai   search open-telemetry/semantic-conventions-genai (main) instead of
#             the core registry pinned in model/manifest.yaml
#
# The pinned version is read from model/manifest.yaml, so the answer matches what
# `weaver registry check` resolves. Clones are cached under
# ${XDG_CACHE_HOME:-~/.cache}/semconv-author.

set -euo pipefail

repo=open-telemetry/semantic-conventions
ref=""
if [ "${1:-}" = "--genai" ]; then
  repo=open-telemetry/semantic-conventions-genai
  ref=main
  shift
fi

pattern="${1:?usage: find-upstream.sh [--genai] <regex>}"
root="$(git rev-parse --show-toplevel)"

if [ -z "$ref" ]; then
  ref="$(grep -oE 'semantic-conventions\.git@v[0-9]+\.[0-9]+\.[0-9]+' "$root/model/manifest.yaml" | head -n1 | sed 's/.*@//')"
  if [ -z "$ref" ]; then
    echo "no core semantic-conventions dependency pinned in model/manifest.yaml; pass --genai or check the manifest" >&2
    exit 1
  fi
fi

cache="${XDG_CACHE_HOME:-$HOME/.cache}/semconv-author/${repo##*/}-${ref}"
if [ ! -d "$cache/model" ]; then
  rm -rf "$cache"
  git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$ref" --filter=blob:none --sparse "https://github.com/$repo.git" "$cache"
  git -C "$cache" sparse-checkout set model docs >/dev/null
fi

echo "# $repo@$ref"
grep -rnE "^\s*(- )?(id|metric_name|name|value|ref):\s*['\"]?[a-z0-9_.]*(${pattern})" "$cache/model" \
  | sed "s|$cache/||" \
  | grep -v '/deprecated/' || echo "(no match)"
