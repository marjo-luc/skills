#!/usr/bin/env bash
# Run the same two validation gates as the GitHub Action:
#   cwltool --validate --strict   (CWL syntax and schema)
#   ap-validator --detail all     (OGC best-practice conformance)
#
# Usage: validate_cwl.sh <path-to-cwl> [--ref 1.1.0] [--json]
set -uo pipefail

REF="1.1.0"
JSON=0
CWL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ref)  REF="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) CWL="$1"; shift ;;
  esac
done

if [[ -z "$CWL" ]]; then
  echo "Usage: validate_cwl.sh <path-to-cwl> [--ref REF] [--json]" >&2
  exit 2
fi
if [[ ! -f "$CWL" ]]; then
  echo "ERROR: CWL file not found: $CWL" >&2
  exit 1
fi

CACHE_ROOT="${OGC_APP_PACK_CACHE:-$HOME/.cache/ogc-app-pack}"
VENV_BIN="$CACHE_ROOT/venv-$REF/bin"

if [[ ! -x "$VENV_BIN/cwltool" ]]; then
  echo "ERROR: validator venv not found at $CACHE_ROOT/venv-$REF." >&2
  echo "Run scripts/fetch_generator.sh first." >&2
  exit 1
fi

STATUS=0

echo "== cwltool --validate --strict =="
"$VENV_BIN/cwltool" --validate --strict --verbose "$CWL" || STATUS=1

echo
echo "== ap-validator (OGC) =="
if [[ $JSON -eq 1 ]]; then
  "$VENV_BIN/ap-validator" --format json "$CWL" || STATUS=1
else
  "$VENV_BIN/ap-validator" --detail all "$CWL" || STATUS=1
fi

echo
if [[ $STATUS -eq 0 ]]; then
  echo "Both validators passed."
else
  echo "Validation failed. Fix algorithm_config.yml and regenerate -- do not edit the CWL." >&2
  echo "See references/validate-and-run.md for how to decode the failure." >&2
fi
exit $STATUS
