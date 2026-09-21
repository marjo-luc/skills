#!/usr/bin/env bash
# Fetch MAAP-Project/ogc-app-pack-generator at a pinned ref and prepare a venv
# with its dependencies (cwltool, ogc_ap_validator, PyYAML, requests).
#
# Idempotent and cached, so re-running is cheap. Prints the generator directory
# and the venv path.
#
# Usage: fetch_generator.sh [--ref 1.1.0] [--force]
set -euo pipefail

REF="1.1.0"
FORCE=0
REPO="https://github.com/MAAP-Project/ogc-app-pack-generator.git"
CACHE_ROOT="${OGC_APP_PACK_CACHE:-$HOME/.cache/ogc-app-pack}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ref)   REF="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

GEN_DIR="$CACHE_ROOT/generator-$REF"
VENV_DIR="$CACHE_ROOT/venv-$REF"

if [[ $FORCE -eq 1 ]]; then
  rm -rf "$GEN_DIR" "$VENV_DIR"
fi

if [[ ! -d "$GEN_DIR/.git" ]]; then
  echo "Cloning $REPO at $REF ..." >&2
  mkdir -p "$CACHE_ROOT"
  rm -rf "$GEN_DIR"
  # --branch accepts a tag; fall back to a full clone + checkout for a bare SHA.
  if ! git clone --depth 1 --branch "$REF" "$REPO" "$GEN_DIR" 2>/dev/null; then
    git clone "$REPO" "$GEN_DIR"
    git -C "$GEN_DIR" checkout -q "$REF"
  fi
else
  echo "Using cached generator at $GEN_DIR" >&2
fi

if [[ ! -x "$VENV_DIR/bin/python" ]]; then
  echo "Creating venv and installing generator requirements (this takes a minute) ..." >&2
  python3 -m venv "$VENV_DIR"
  "$VENV_DIR/bin/pip" install --quiet --upgrade pip
  "$VENV_DIR/bin/pip" install --quiet -r "$GEN_DIR/requirements.txt" requests
else
  echo "Using cached venv at $VENV_DIR" >&2
fi

echo "GEN_DIR=$GEN_DIR"
echo "VENV_DIR=$VENV_DIR"
echo "PYTHON=$VENV_DIR/bin/python"
