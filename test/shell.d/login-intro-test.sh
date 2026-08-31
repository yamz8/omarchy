#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

require_command jq
require_command sha256sum

run_node_test <<'JS'
const fs = require('fs')

const background = fs.readFileSync(path.join(root, 'shell/plugins/background/Background.qml'), 'utf8')
const intro = fs.readFileSync(path.join(root, 'shell/plugins/background/LoginIntro.qml'), 'utf8')
const video = fs.readFileSync(path.join(root, 'shell/plugins/background/LoginIntroVideo.qml'), 'utf8')
const launcher = fs.readFileSync(path.join(root, 'bin/omarchy-launch-shell'), 'utf8')

assert(/import QtMultimedia/.test(video), 'login intro uses the native Qt multimedia renderer')
assert(!/import QtMultimedia/.test(intro), 'procedural startup does not initialize the multimedia backend')
assert(/source:\s*active \? "LoginIntroVideo\.qml"/.test(intro), 'video backend loads only when a clip is selected')
assert(/asynchronous:\s*true/.test(intro), 'video backend compilation does not delay the poster overlay')
assert(/WlrLayershell\.layer:\s*WlrLayer\.Overlay/.test(intro), 'login intro covers the starting desktop as an overlay')
assert(/WlrLayershell\.keyboardFocus:\s*WlrKeyboardFocus\.None/.test(intro), 'login intro never takes keyboard focus')
assert(/mask:\s*Region\s*\{\s*\}/.test(intro), 'login intro leaves pointer input untouched')
assert(/muted:\s*true/.test(video), 'login intro is silent')
assert(/VideoOutput\.KeepLastFrame/.test(video), 'video holds its final frame through the handoff')
assert(/VideoOutput\.PreserveAspectCrop/.test(video), 'video crops like the existing wallpaper renderer')
assert(/visible:\s*root\.ready/.test(video), 'poster stays visible until each screen has decoded its first video frame')
assert(/property:\s*"revealOpacity"[\s\S]*?duration:\s*root\.fadeDuration/.test(intro), 'login intro fades into the live wallpaper')
assert(/scale:\s*root\.mode === "procedural"/.test(intro), 'backgrounds without a video receive the default procedural intro')
assert(/Math\.sin\(root\.cameraProgress \* Math\.PI\)/.test(intro), 'procedural motion starts and ends at the exact wallpaper scale')

assert(/HYPRLAND_INSTANCE_SIGNATURE/.test(launcher), 'launcher keys automatic playback to the Hyprland session')
assert(/if mkdir "\$marker"/.test(launcher), 'launcher claims the session marker atomically')
assert(/omarchy-theme-intro resolve/.test(launcher), 'launcher resolves the current image intro through the CLI contract')
assert(/run_shell\(\) \{\s*prepare_login_intro[\s\S]*?quickshell -n/.test(launcher), 'intro resolution finishes before Quickshell maps the desktop')
assert(/OMARCHY_LOGIN_INTRO_RESOLUTION/.test(background), 'background receives the prepared startup resolution without a delayed subprocess')
assert(/resolvedBackground !== currentBackground/.test(background), 'stale intro resolution never plays over a newly selected background')
assert(/function previewIntro\(/.test(background), 'background exposes intro preview IPC')
assert(/function stopIntro\(/.test(background), 'background exposes intro stop IPC')
assert(/function introStatus\(/.test(background), 'background exposes intro status IPC')
JS

test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

test_home="$test_root/home"
stub_bin="$test_root/bin"
call_log="$test_root/calls.log"
background_file="$test_home/Pictures/theme background.webp"
current_dir="$test_home/.local/state/omarchy/current"
theme_intro_dir="$current_dir/theme/intros"
user_intro_dir="$test_home/.local/share/omarchy/login-intros"

mkdir -p "$stub_bin" "$theme_intro_dir" "$(dirname -- "$background_file")"
printf 'current background fixture\n' >"$background_file"
ln -s "$background_file" "$current_dir/background"
background_hash=$(sha256sum "$background_file" | cut -d' ' -f1)

cat >"$stub_bin/ffmpeg" <<'STUB'
#!/bin/bash
output=${!#}
printf 'normalized video\n' >"$output"
STUB

cat >"$stub_bin/omarchy-shell" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >>"$CALL_LOG"
echo ok
STUB

cat >"$stub_bin/hyprctl" <<'STUB'
#!/bin/bash

if [[ ${1:-} == "getoption" && ${2:-} == "animations:enabled" && ${3:-} == "-j" ]]; then
  printf '{"bool":%s}\n' "${ANIMATIONS_ENABLED:-true}"
else
  exit 1
fi
STUB

chmod 755 "$stub_bin/ffmpeg" "$stub_bin/hyprctl" "$stub_bin/omarchy-shell"

run_intro() {
  HOME="$test_home" OMARCHY_PATH="$ROOT" CALL_LOG="$call_log" ANIMATIONS_ENABLED="${ANIMATIONS_ENABLED:-true}" PATH="$stub_bin:$ROOT/bin:$PATH" \
    "$ROOT/bin/omarchy-theme-intro" "$@"
}

resolution=$(run_intro resolve)
jq -e --arg background "$background_file" --arg hash "$background_hash" '
  .enabled == true and .mode == "procedural" and .source == "procedural" and
  .video == "" and .background == $background and .hash == $hash
' <<<"$resolution" >/dev/null
pass "current backgrounds receive the procedural intro by default"

printf 'theme video\n' >"$theme_intro_dir/$background_hash.webm"
resolution=$(run_intro resolve)
jq -e --arg video "$theme_intro_dir/$background_hash.webm" '
  .enabled == true and .mode == "video" and .source == "theme" and .video == $video
' <<<"$resolution" >/dev/null
pass "theme intro is selected by the current background hash"

mkdir -p "$user_intro_dir"
printf 'user video\n' >"$user_intro_dir/$background_hash.mp4"
resolution=$(run_intro resolve)
jq -e --arg video "$user_intro_dir/$background_hash.mp4" '
  .mode == "video" and .source == "user" and .video == $video
' <<<"$resolution" >/dev/null
pass "user intro overrides a theme intro for the same background"

resolution=$(ANIMATIONS_ENABLED=false run_intro resolve)
jq -e '.enabled == false and .mode == "disabled" and .reason == "animations-disabled"' <<<"$resolution" >/dev/null
pass "automatic login motion respects disabled Hyprland animations"

mkdir -p "$test_home/.local/state/omarchy/toggles"
touch "$test_home/.local/state/omarchy/toggles/login-intro-disabled"
resolution=$(run_intro resolve)
jq -e '.enabled == false and .mode == "disabled" and .reason == "disabled"' <<<"$resolution" >/dev/null
pass "disabled login intro resolves without playback"

: >"$call_log"
run_intro preview >/dev/null
grep -F "background previewIntro $user_intro_dir/$background_hash.mp4 $background_file" "$call_log" >/dev/null ||
  fail "manual preview bypasses the disabled toggle and targets the current wallpaper" "$(cat "$call_log")"
pass "manual preview bypasses the disabled toggle and targets the current wallpaper"

source_video="$test_root/source clip.mov"
printf 'source video\n' >"$source_video"
run_intro set "$source_video" >/dev/null
[[ $(cat "$user_intro_dir/$background_hash.mp4") == "normalized video" ]] ||
  fail "setting an intro normalizes it into the hash store"
pass "setting an intro normalizes it into the hash store"

run_intro remove >/dev/null
[[ ! -e $user_intro_dir/$background_hash.mp4 ]] || fail "removing an intro deletes only the current custom clip"
[[ -e $theme_intro_dir/$background_hash.webm ]] || fail "removing a custom intro preserves the theme clip"
pass "removing an intro preserves packaged theme assets"

run_toggle() {
  HOME="$test_home" CALL_LOG="$call_log" PATH="$stub_bin:$ROOT/bin:$PATH" \
    "$ROOT/bin/omarchy-toggle-login-intro" "$@"
}

[[ $(run_toggle status) == "disabled" ]] || fail "toggle reports a disabled intro"
[[ $(run_toggle on) == "enabled" ]] || fail "toggle enables the login intro"
[[ ! -e $test_home/.local/state/omarchy/toggles/login-intro-disabled ]] || fail "enable removes the disabled marker"
[[ $(run_toggle off) == "disabled" ]] || fail "toggle disables the login intro"
[[ -e $test_home/.local/state/omarchy/toggles/login-intro-disabled ]] || fail "disable creates the disabled marker"
grep -F -- "-q background stopIntro" "$call_log" >/dev/null || fail "disabling stops a running intro"
pass "login intro toggle persists state and stops live playback"

grep -Fx 'qt6-multimedia' "$ROOT/install/omarchy-base.packages" >/dev/null ||
  fail "base packages declare the Qt multimedia QML dependency"
grep -Fx 'qt6-multimedia-ffmpeg' "$ROOT/install/omarchy-base.packages" >/dev/null ||
  fail "base packages declare the Qt multimedia FFmpeg backend"
pass "login intro multimedia dependencies are explicit runtime invariants"
