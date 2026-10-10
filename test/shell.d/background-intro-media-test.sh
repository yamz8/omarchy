#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

if ! command -v ffprobe >/dev/null; then
  skip "packaged theme intros decode everywhere and keep their still's shape (ffprobe missing)"
  exit 0
fi

# Hardware H.264 decoders top out around 4096x2160 (AMD VCN, Intel Quick Sync,
# NVDEC), so a larger frame drops the intro to software decoding.
max_width=4096
max_height=2160

# Prints the requested stream fields in ffprobe's own order, one value per line.
probe() {
  ffprobe -v error -select_streams "$2" -show_entries "stream=$3" -of default=noprint_wrappers=1 "$1"
}

declare -A media
read_media() {
  local key value
  media=()
  while IFS== read -r key value; do
    media[$key]=$value
  done < <(probe "$@")
}

checked=0
for intro in "$ROOT"/themes/*/backgrounds/intros/*.mp4; do
  [[ -f $intro ]] || continue
  backgrounds=${intro%/intros/*}
  stem=${intro##*/}
  stem=${stem%.mp4}
  still=$(compgen -G "$backgrounds/$stem.*" | head -n 1)
  name=${intro#"$ROOT"/}

  read_media "$intro" v:0 codec_name,pix_fmt,width,height
  codec=${media[codec_name]} pix_fmt=${media[pix_fmt]} width=${media[width]} height=${media[height]}
  [[ $codec == "h264" && $pix_fmt == "yuv420p" ]] || fail "$name is H.264 yuv420p" "$codec $pix_fmt"
  (( width <= max_width && height <= max_height )) || fail "$name fits hardware decode limits" "${width}x$height"
  [[ -z $(probe "$intro" a codec_name) ]] || fail "$name has no audio track"

  # The handoff swaps the still for the video at the same screen position, so
  # both must be cropped the same way: same aspect ratio within one percent.
  read_media "$still" v:0 width,height
  still_width=${media[width]} still_height=${media[height]}
  skew=$(( width * still_height - still_width * height ))
  (( 100 * (skew < 0 ? -skew : skew) <= still_width * height )) || fail "$name keeps the shape of its still" "video ${width}x$height, still ${still_width}x$still_height"
  ((++checked))
done
(( checked > 0 )) || fail "no packaged theme intros were found"
pass "packaged theme intros decode everywhere and keep their still's shape"
