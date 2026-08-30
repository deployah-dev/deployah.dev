#!/usr/bin/env bash
# Render demos/tapes/*/demo.tape to demos/out/.
# nix run .#demo sets INTER_FONTDIR and ZSH_SYNTAX_HIGHLIGHTING.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$root" ] || [ ! -d "$root/demos/tapes" ]; then
  echo "run from the deployah.dev repo root (demos/tapes not found)" >&2
  exit 1
fi
cd "$root"
export STARSHIP_CONFIG="$root/demos/tapes/starship.toml"
export STARSHIP_CACHE="$root/demos/out/.starship-cache"
if [ ! -f "$STARSHIP_CONFIG" ] || [ ! -f "${ZSH_SYNTAX_HIGHLIGHTING:-}" ]; then
  echo "STARSHIP_CONFIG or ZSH_SYNTAX_HIGHLIGHTING missing" >&2
  exit 1
fi
if [ ! -d "${INTER_FONTDIR:-}" ]; then
  echo "INTER_FONTDIR missing" >&2
  exit 1
fi

mkdir -p demos/out

shopt -s nullglob
all_tapes=(demos/tapes/*/demo.tape)
if [ ${#all_tapes[@]} -eq 0 ]; then
  echo "no demos/tapes/*/demo.tape files" >&2
  exit 1
fi
# Wells first, hero last. Logs/shell used to share project nginx and
# overwrite the Ingress the browser shot needs.
tapes=()
heroes=()
for tape in "${all_tapes[@]}"; do
  if grep -q '_hero.tape' "$tape"; then
    heroes+=("$tape")
  else
    tapes+=("$tape")
  fi
done
tapes+=("${heroes[@]}")

for tape in "${tapes[@]}"; do
  name="$(basename "$(dirname "$tape")")"
  fixture="demos/${name}"
  browser_yaml="demos/tapes/${name}/browser.yaml"
  captions="demos/tapes/${name}/captions.yaml"
  mp4="demos/out/${name}.mp4"

  hero=false
  if grep -q '_hero.tape' "$tape"; then
    hero=true
  fi

  if [ "$hero" = true ] && [ -f "$browser_yaml" ] && [ -d "$fixture" ]; then
    echo "Ensuring local cluster for $name ..."
    (cd "$fixture" && deployah cluster up)
  fi

  echo "Rendering $tape ..."
  vhs "$tape"

  if [ ! -f "$mp4" ]; then
    echo "VHS did not write $mp4 (set Output demos/out/${name}.mp4 in the tape)" >&2
    exit 1
  fi

  browser_offset=""
  if [ "$hero" = true ] && [ -f "$browser_yaml" ]; then
    # VHS runs in its own sandbox. Chromium on the host needs the
    # release on the host Kind cluster, so deploy again after the tape.
    echo "Deploying $name on the host cluster for the browser shot ..."
    (cd "$fixture" && deployah deploy local --yes)
    url=""
    for _ in $(seq 1 45); do
      url="$(deployah cluster status -o json | jq -r '[.access[]? | select(.kind == "Ingress" and (.url // "") != "")] | .[0].url // empty')"
      if [ -n "$url" ]; then
        break
      fi
      sleep 1
    done
    if [ -z "$url" ]; then
      echo "no Ingress URL from deployah cluster status after host deploy" >&2
      deployah cluster status -o json >&2 || true
      exit 1
    fi
    hold="$(yq -r '.duration // 5' "$browser_yaml")"
    vhs_mp4="demos/out/${name}-vhs.mp4"
    browser_mp4="demos/out/${name}-browser.mp4"
    mv "$mp4" "$vhs_mp4"
    echo "Recording browser opening $url ..."
    xvfb-run -a -s "-screen 0 1920x1080x24" bash nix/record-browser.sh "$browser_mp4" "$url" "$hold"
    echo "Writing browser poster ..."
    ffmpeg -y -hide_banner -loglevel error \
      -sseof -0.5 -i "$browser_mp4" -frames:v 1 -q:v 4 \
      "demos/out/${name}-browser.jpg"
    echo "Concatenating terminal + browser ..."
    ffmpeg -y -hide_banner -loglevel error \
      -i "$vhs_mp4" -i "$browser_mp4" \
      -filter_complex "[0:v]fps=30,scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,format=yuv420p,setsar=1[v0];[1:v]fps=30,scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,format=yuv420p,setsar=1[v1];[v0][v1]concat=n=2:v=1:a=0[v]" \
      -map "[v]" -c:v libx264 -crf 18 -movflags +faststart \
      "$mp4"
    browser_offset="$(ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 "$vhs_mp4")"
  fi

  poster="demos/out/${name}.jpg"
  if [ "$hero" != true ]; then
    dur="$(ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 "$mp4")"
    poster_t="$(awk -v d="$dur" 'BEGIN { printf "%.3f", d * 0.6 }')"
    echo "Writing $poster at ${poster_t}s ..."
    ffmpeg -y -hide_banner -loglevel error -i "$mp4" -ss "$poster_t" -frames:v 1 -q:v 4 "$poster"
    continue
  fi

  srt="demos/out/${name}.srt"
  captioned="demos/out/${name}-captioned.mp4"
  if [ -f "$captions" ]; then
    bash nix/captions-to-srt.sh "$captions" "$srt" "$browser_offset"
    if [ -s "$srt" ]; then
      echo "Burning captions into $captioned ..."
      # SRT import is PlayRes 384x288. Pin to the 1080p frame so
      # FontSize and margins are pixels.
      ass="${srt%.srt}.ass"
      ffmpeg -y -hide_banner -loglevel error -i "$srt" "$ass"
      sed -i \
        -e 's/^PlayResX: .*/PlayResX: 1920/' \
        -e 's/^PlayResY: .*/PlayResY: 1080/' \
        "$ass"
      # White text on a dark box. ASS is &HAABBGGRR; alpha is inverted
      # (00=opaque). BorderStyle=4 uses BackColour as the box and Outline
      # as padding. FontSize 48 still reads on the 1400x700 GIF.
      ffmpeg -y -i "$mp4" \
        -vf "subtitles=$ass:fontsdir=${INTER_FONTDIR}:force_style='FontName=Inter,FontSize=48,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,BackColour=&H40000000,BorderStyle=4,Outline=10,Shadow=0,Alignment=2,MarginL=96,MarginR=96,MarginV=100'" \
        -c:v libx264 -pix_fmt yuv420p -crf 18 -movflags +faststart \
        "$captioned"
    else
      cp "$mp4" "$captioned"
    fi
  else
    cp "$mp4" "$captioned"
  fi

  bed="demos/audio/vastness.mp3"
  if [ -f "$bed" ]; then
    echo "Mixing $bed under $captioned ..."
    dur="$(ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 "$captioned")"
    fade_out="$(awk -v d="$dur" 'BEGIN { s = d - 2; if (s < 0) s = 0; printf "%.3f", s }')"
    mixed="${captioned%.mp4}-mixed.mp4"
    ffmpeg -y -hide_banner -loglevel error \
      -i "$captioned" -i "$bed" \
      -filter_complex "[1:a]afade=t=in:st=0:d=1,afade=t=out:st=${fade_out}:d=2,volume=0.40[a]" \
      -map 0:v -map "[a]" -c:v copy -c:a aac -b:a 160k -shortest -movflags +faststart \
      "$mixed"
    mv "$mixed" "$captioned"
  fi

  poster_t=""
  if [ -f "$captions" ]; then
    # Poster is 1.5s into the Deployed caption, not the last frame.
    deployed_start="$(yq -r '
      [.captions[]? | select(.text | test("(?i)Deployed"))] | .[0].start
    ' "$captions")"
    if [ -n "$deployed_start" ] && [ "$deployed_start" != "null" ]; then
      poster_t="$(awk -v s="$deployed_start" 'BEGIN { printf "%.3f", s + 1.5 }')"
    fi
  fi
  if [ -z "$poster_t" ] || [ "$poster_t" = "null" ]; then
    dur="$(ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 "$captioned")"
    poster_t="$(awk -v d="$dur" 'BEGIN { printf "%.3f", d * 0.6 }')"
  fi
  echo "Writing $poster at ${poster_t}s ..."
  ffmpeg -y -hide_banner -loglevel error -i "$captioned" -ss "$poster_t" -frames:v 1 -q:v 4 "$poster"

  gif="demos/out/${name}.gif"
  echo "Writing $gif ..."
  ffmpeg -y -i "$captioned" \
    -vf "fps=12,scale=1400:700:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
    "$gif"
  gifsicle -O3 --lossy=40 --colors 128 "$gif" -o "$gif"
done

echo "Done. Files are under demos/out/"
