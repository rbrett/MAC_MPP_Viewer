#!/usr/bin/env bash
#
# mpp-to-projectlibre.sh
#
# Converts a Microsoft Project (.mpp) file to a temporary MSPDI XML file
# using MPXJ, then opens that XML file in ProjectLibre.
#
# Why the XML round-trip: ProjectLibre's own MPP parser is an old, unmaintained
# fork of MPXJ and chokes (hangs) on current M365 .mpp files. MSPDI XML is
# Microsoft's own plain-text interchange format, converted by current MPXJ,
# and ProjectLibre reads it far more reliably than the native binary format.
#
# Usage:
#   ./mpp-to-projectlibre.sh /path/to/plan.mpp
#
# Requires:
#   - MPXJ built from source and its mpxj-convert.sh wrapper
#     (see install-mpxj.sh from earlier — default location: ~/dev/mpxj)
#   - ProjectLibre installed as a macOS app (default: /Applications/ProjectLibre.app)
#
# Env overrides:
#   MPXJ_CONVERTER    path to mpxj-convert.sh
#                      (default: ~/dev/mpxj/mpxj-convert.sh)
#   PROJECTLIBRE_APP  app name or path passed to `open -a`
#                      (default: ProjectLibre)

set -euo pipefail

log() { printf '\n[mpp-to-projectlibre] %s\n' "$1"; }
die() { printf '\n[mpp-to-projectlibre] ERROR: %s\n' "$1" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || die "This script uses macOS's 'open' command and targets macOS only."

MPP_FILE="${1:-}"
[[ -n "$MPP_FILE" ]] || die "Usage: $0 <file.mpp>"
[[ -f "$MPP_FILE" ]] || die "File not found: $MPP_FILE"
[[ -r "$MPP_FILE" ]] || die "File not readable: $MPP_FILE"

MPXJ_CONVERTER="${MPXJ_CONVERTER:-$HOME/dev/mpxj/mpxj-convert.sh}"
PROJECTLIBRE_APP="${PROJECTLIBRE_APP:-ProjectLibre}"

[[ -x "$MPXJ_CONVERTER" ]] || die "MPXJ converter not found or not executable: $MPXJ_CONVERTER
Run install-mpxj.sh first, or set MPXJ_CONVERTER to point at your build's mpxj-convert.sh."

# Build the temp filename with mktemp's template form so the .xml suffix is
# part of the atomic file creation, not appended afterwards to a different
# path than the one mktemp actually created.
BASE_NAME="$(basename "${MPP_FILE%.*}")"
TMP_XML="$(mktemp "${TMPDIR:-/tmp}/mpxj-${BASE_NAME}.XXXXXXXX.xml")"

log "Converting: $MPP_FILE -> $TMP_XML"
"$MPXJ_CONVERTER" "$MPP_FILE" "$TMP_XML"

[[ -s "$TMP_XML" ]] || die "Conversion produced an empty or missing file: $TMP_XML"

log "Opening in ProjectLibre: $TMP_XML"
if ! open -a "$PROJECTLIBRE_APP" "$TMP_XML"; then
  die "Could not open '$TMP_XML' with app '$PROJECTLIBRE_APP'.
Check the exact app name under /Applications (Get Info -> name), or set
PROJECTLIBRE_APP=/Applications/ProjectLibre.app and re-run."
fi

log "Done."
echo "  Temp XML left at: $TMP_XML"
echo "  'open' hands off to ProjectLibre asynchronously, so this script can't"
echo "  safely auto-delete the file without risking a race against the app"
echo "  still reading it. It lives under \$TMPDIR, which macOS clears"
echo "  periodically / on reboot — delete it sooner yourself if you want:"
echo "  rm \"$TMP_XML\""
