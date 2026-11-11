#!/usr/bin/env bash
# Scans a tar stream from stdin with ClamAV.
# Exit codes: 0 clean, 1 malware found, 2 scan error.
#
# Signatures are updated with freshclam first. If that fails, the scan uses the
# signatures bundled in the image and logs a warning.
#
# Optional: FRESHCLAM_OPTS adds arguments to freshclam (the self-test uses it).
set -euo pipefail

docker run --rm -i -e FRESHCLAM_OPTS --entrypoint sh clamav/clamav:1.5.4-debian -c '
  mkdir /scan && tar -xf - -C /scan &&
  { freshclam --stdout $FRESHCLAM_OPTS || echo "::warning::freshclam failed, scanning with bundled signatures"; } &&
  clamscan --version &&
  clamscan -r -i --alert-exceeds-max=yes --max-filesize=500M --max-scansize=2000M /scan'
