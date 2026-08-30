#!/usr/bin/env bash
# Record Chromium: type the Ingress URL, sit on the page.
# Usage: record-browser.sh OUT.mp4 URL HOLD_SECONDS
# Run under xvfb-run (1920x1080).
#
# Launch under dbus-run-session on X11. A later extract dropped that
# wrapper; without it, xdotool type never reaches the omnibox.
#
# Chromium's resolver hangs on nip.io (IPv4-mapped IPv6 / HTTP2 to
# Envoy). MAP the host to 127.0.0.1 and disable HTTP2. Typed Enter
# can still miss if autocomplete steals focus; if the title stays
# blank, a second window opens the URL on argv.
set -euo pipefail

out="${1:?out mp4}"
url="${2:?url}"
hold="${3:-5}"

if [ -z "${DISPLAY:-}" ]; then
  echo "record-browser.sh needs DISPLAY (run under xvfb-run)" >&2
  exit 1
fi

without_scheme="${url#*://}"
host="${without_scheme%%[:/]*}"
if [ -z "$host" ]; then
  echo "could not parse host from $url" >&2
  exit 1
fi

user_data="$(mktemp -d)"
load_data=""
ff_pid=""
wm_pid=""
chrome_pid=""
chrome2_pid=""

cleanup() {
  # Stop the encoder first so the last frames still show the page.
  if [ -n "$ff_pid" ]; then
    kill -INT "$ff_pid" 2>/dev/null || true
    wait "$ff_pid" 2>/dev/null || true
    ff_pid=""
  fi
  if [ -n "$chrome2_pid" ]; then
    kill "$chrome2_pid" 2>/dev/null || true
    wait "$chrome2_pid" 2>/dev/null || true
  fi
  if [ -n "$chrome_pid" ]; then
    kill "$chrome_pid" 2>/dev/null || true
    wait "$chrome_pid" 2>/dev/null || true
  fi
  if [ -n "$wm_pid" ]; then
    kill "$wm_pid" 2>/dev/null || true
    wait "$wm_pid" 2>/dev/null || true
  fi
  rm -rf "$user_data"
  if [ -n "$load_data" ]; then
    rm -rf "$load_data"
  fi
}
trap cleanup EXIT

openbox --sm-disable >/dev/null 2>&1 &
wm_pid=$!
sleep 0.4

ffmpeg -y -hide_banner -loglevel error \
  -f x11grab -draw_mouse 0 -video_size 1920x1080 -framerate 30 -i "$DISPLAY" \
  -c:v libx264 -pix_fmt yuv420p -crf 18 \
  "$out" &
ff_pid=$!
sleep 0.4
if ! kill -0 "$ff_pid" 2>/dev/null; then
  echo "ffmpeg x11grab failed to start (need an ffmpeg built with libxcb)" >&2
  wait "$ff_pid" || true
  exit 1
fi

chrome_log="$user_data/chromium.log"
unset WAYLAND_DISPLAY WAYLAND_SOCKET
export NIXOS_OZONE_PLATFORM=x11
export XDG_SESSION_TYPE=x11
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb
export LIBGL_ALWAYS_SOFTWARE=1

chrome_flags=(
  --ozone-platform=x11
  --enable-features=UseOzonePlatform
  --use-gl=angle
  --use-angle=swiftshader
  --no-first-run
  --no-default-browser-check
  --disable-infobars
  --disable-session-crashed-bubble
  --disable-features=TranslateUI,DialMediaRouteProvider
  --disable-gpu
  --disable-dev-shm-usage
  --no-sandbox
  --test-type
  --ignore-certificate-errors
  --allow-insecure-localhost
  --password-store=basic
  --no-proxy-server
  --disable-quic
  --disable-http2
  --host-resolver-rules="MAP ${host} 127.0.0.1"
  --window-size=1920,1080
  --window-position=0,0
  --start-maximized
)

dbus-run-session -- chromium --user-data-dir="$user_data" "${chrome_flags[@]}" about:blank >"$chrome_log" 2>&1 &
chrome_pid=$!

win=""
for _ in $(seq 1 75); do
  while read -r id; do
    [ -z "$id" ] && continue
    name="$(xdotool getwindowname "$id" 2>/dev/null || true)"
    class="$(xdotool getwindowclassname "$id" 2>/dev/null || true)"
    case "$name" in
      *clipboard*|*Cursor*) continue ;;
    esac
    case "$class $name" in
      *Chromium*|*chromium*|about:blank*)
        win="$id"
        break
        ;;
    esac
  done < <(xdotool search --name . 2>/dev/null || true)
  if [ -n "$win" ]; then
    break
  fi
  sleep 0.2
done
if [ -z "$win" ]; then
  echo "chromium window did not appear on $DISPLAY" >&2
  echo "windows on $DISPLAY:" >&2
  xdotool search --name . 2>/dev/null | while read -r id; do
    echo "  $id $(xdotool getwindowname "$id" 2>/dev/null || true) $(xdotool getwindowclassname "$id" 2>/dev/null || true)" >&2
  done || true
  if [ -f "$chrome_log" ]; then
    cat "$chrome_log" >&2
  fi
  exit 1
fi

xdotool windowmap "$win" 2>/dev/null || true
xdotool windowactivate --sync "$win"
xdotool windowmove "$win" 0 0
xdotool windowsize "$win" 1920 1080
sleep 0.6
xdotool key --clearmodifiers ctrl+l
sleep 0.25
xdotool type --delay 18 -- "$url"
sleep 0.8
# Autocomplete can highlight a host without the port. Escape
# dismisses it; it also blurs the omnibox, so Return is a no-op
# unless we focus the bar again.
xdotool key --clearmodifiers Escape
sleep 0.15
xdotool key --clearmodifiers ctrl+l
sleep 0.2
xdotool key --clearmodifiers Return

page_ready() {
  while read -r id; do
    [ -z "$id" ] && continue
    name="$(xdotool getwindowname "$id" 2>/dev/null || true)"
    case "$name" in
      *Welcome* | *nginx*) return 0 ;;
    esac
  done < <(xdotool search --name . 2>/dev/null || true)
  return 1
}

loaded=false
for _ in $(seq 1 24); do
  if page_ready; then
    loaded=true
    break
  fi
  sleep 0.25
done

if [ "$loaded" != true ]; then
  echo "typed Enter did not load the page; opening $url" >&2
  load_data="$(mktemp -d)"
  dbus-run-session -- chromium --user-data-dir="$load_data" "${chrome_flags[@]}" "$url" >>"$chrome_log" 2>&1 &
  chrome2_pid=$!
  for _ in $(seq 1 50); do
    if page_ready; then
      loaded=true
      break
    fi
    sleep 0.25
  done
  if [ "$loaded" = true ]; then
    while read -r id; do
      [ -z "$id" ] && continue
      name="$(xdotool getwindowname "$id" 2>/dev/null || true)"
      case "$name" in
        *Welcome* | *nginx*)
          xdotool windowactivate --sync "$id" 2>/dev/null || true
          xdotool windowmove "$id" 0 0 2>/dev/null || true
          xdotool windowsize "$id" 1920 1080 2>/dev/null || true
          break
          ;;
      esac
    done < <(xdotool search --name . 2>/dev/null || true)
  fi
fi

if [ "$loaded" != true ]; then
  echo "chromium did not reach the Ingress page" >&2
  echo "window titles:" >&2
  xdotool search --name . 2>/dev/null | while read -r id; do
    echo "  $id $(xdotool getwindowname "$id" 2>/dev/null || true)" >&2
  done || true
  if [ -f "$chrome_log" ]; then
    cat "$chrome_log" >&2
  fi
  exit 1
fi

sleep "$hold"
