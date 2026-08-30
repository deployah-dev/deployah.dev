#!/usr/bin/env bash
# Turn demos/tapes/<name>/captions.yaml into SRT.
# Usage: captions-to-srt.sh captions.yaml out.srt [browser_offset_seconds]
set -euo pipefail

src="${1:?captions.yaml}"
dest="${2:?out.srt}"
offset="${3:-}"

ts_awk='
function ts(s,   ms, h, m, sec) {
  ms = int(s * 1000 + 0.5)
  h = int(ms / 3600000); ms %= 3600000
  m = int(ms / 60000);   ms %= 60000
  sec = int(ms / 1000);  ms %= 1000
  return sprintf("%02d:%02d:%02d,%03d", h, m, sec, ms)
}
BEGIN { FS = "\t"; OFS = "\n" }
NF >= 3 {
  print NR, ts($1) " --> " ts($2), $3, ""
}
'

mkdir -p "$(dirname "$dest")"
{
  if [ -n "$offset" ]; then
    # Terminal cues are relative to VHS. Clip them to the concat cut so a
    # stale end time cannot sit on top of browser_captions.
    OFFSET="$offset" yq -r '
      (.captions // [])[]
      | select(.start < (env(OFFSET) | tonumber))
      | [
          .start,
          ([.end, (env(OFFSET) | tonumber)] | min),
          .text
        ]
      | @tsv
    ' "$src"
    OFFSET="$offset" yq -r '
      (.browser_captions // [])[]
      | [(.start + (env(OFFSET) | tonumber)),
         (.end   + (env(OFFSET) | tonumber)),
         .text]
      | @tsv
    ' "$src"
  else
    yq -r '(.captions // [])[] | [.start, .end, .text] | @tsv' "$src"
  fi
} | awk "$ts_awk" > "$dest"
