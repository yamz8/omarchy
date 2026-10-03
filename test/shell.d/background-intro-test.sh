#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

intro_home="$test_tmp/home"
state_dir="$intro_home/.local/state/omarchy"
theme_backgrounds="$state_dir/current/theme/backgrounds"
user_backgrounds="$intro_home/.config/omarchy/backgrounds/tokyo-night"
marker="$state_dir/background-intro.boot-id"
toggle="$state_dir/toggles/background-intros-off"
mkdir -p "$theme_backgrounds/intros" "$user_backgrounds/intros"
printf 'still\n' >"$theme_backgrounds/road.webp"
printf 'video\n' >"$theme_backgrounds/intros/road.mp4"
printf 'still\n' >"$theme_backgrounds/lake.jpg"
printf 'video\n' >"$theme_backgrounds/clip.mp4"
printf 'video\n' >"$theme_backgrounds/intros/clip.mp4"
printf 'still\n' >"$user_backgrounds/mine.png"
printf 'video\n' >"$user_backgrounds/intros/mine.webm"

command_bin="$test_tmp/bin"
command_log="$test_tmp/command-log"
mkdir -p "$command_bin"
cat >"$command_bin/owe" <<'SH'
#!/bin/bash
printf 'owe: %s\n' "$*" >>"$COMMAND_LOG"
case ${1:-} in
  intro)
    [[ ${OWE_FAIL:-} == "" ]] || exit 1
    ;;
  status)
    if [[ ${OWE_FAIL:-} == "interrupted" ]]; then
      printf '{"status":"ok","intro":false,"intro_result":"error"}\n'
    else
      printf '{"status":"ok","intro":false,"intro_result":""}\n'
    fi
    ;;
esac
SH
cat >"$command_bin/hyprctl" <<'SH'
#!/bin/bash
if [[ ${ANIMATIONS:-on} == on ]]; then
  printf '{"option":"animations:enabled","int":1,"bool":true}\n'
else
  printf '{"option":"animations:enabled","int":0,"bool":false}\n'
fi
SH
cat >"$command_bin/omarchy-notification-send" <<'SH'
#!/bin/bash
printf 'notification: %s\n' "$*" >>"$COMMAND_LOG"
SH
chmod +x "$command_bin"/*

launch() {
  env PATH="$command_bin:$ROOT/bin:$PATH" HOME="$intro_home" COMMAND_LOG="$command_log" OMARCHY_BOOT_ID=boot-a "$@" \
    "$ROOT/bin/omarchy-theme-bg-boot-intro"
}

use_background() {
  ln -nsf "$1" "$state_dir/current/background"
  rm -f "$marker"
  : >"$command_log"
}

played() {
  grep '^owe: intro ' "$command_log" | sed 's/^owe: intro //' || true
}

use_background "$theme_backgrounds/road.webp"
launch
[[ $(played) == "$theme_backgrounds/intros/road.mp4" ]] || fail "a theme still plays the intro named after it" "$(played)"
[[ $(<"$marker") == "boot-a" ]] || fail "playing an intro consumes the boot"
launch
(( $(played | wc -l) == 1 )) || fail "an intro plays once per boot" "$(played)"
: >"$command_log"
launch OMARCHY_BOOT_ID=boot-b
[[ $(played) == "$theme_backgrounds/intros/road.mp4" ]] || fail "the next boot plays the intro again" "$(played)"

use_background "$user_backgrounds/mine.png"
launch
[[ $(played) == "$user_backgrounds/intros/mine.webm" ]] || fail "a user's own still plays the intro beside it" "$(played)"

use_background "$theme_backgrounds/lake.jpg"
launch
[[ -z $(played) && $(<"$marker") == "boot-a" ]] || fail "a still without an intro plays none and consumes the boot" "$(played)"

use_background "$theme_backgrounds/clip.mp4"
launch
[[ -z $(played) ]] || fail "a video background plays no intro" "$(played)"

pass "a still plays the intro beside it once per boot"

use_background "$theme_backgrounds/road.webp"
mkdir -p "$(dirname "$toggle")"
touch "$toggle"
launch
rm "$toggle"
[[ -z $(played) && $(<"$marker") == "boot-a" ]] || fail "turned-off intros consume the boot without playing" "$(played)"
launch
[[ -z $(played) ]] || fail "turning intros back on midway through a boot starts no late intro" "$(played)"

use_background "$theme_backgrounds/road.webp"
launch ANIMATIONS=off
[[ -z $(played) && $(<"$marker") == "boot-a" ]] || fail "with animations off the boot is consumed without playing" "$(played)"

pass "intros stay off with the toggle or with animations off"

use_background "$theme_backgrounds/road.webp"
if launch OWE_FAIL=rejected; then
  fail "an intro OWE never started reports a retryable failure"
else
  status=$?
  (( status == 2 )) || fail "an intro OWE never started uses the retry exit code" "$status"
fi
[[ ! -e $marker ]] || fail "an intro OWE never started releases the boot"
launch
[[ $(<"$marker") == "boot-a" ]] || fail "a retry OWE accepts consumes the boot"

use_background "$theme_backgrounds/road.webp"
if launch OWE_FAIL=interrupted; then
  fail "an interrupted intro reports a failure"
else
  status=$?
  (( status == 1 )) || fail "an interrupted intro does not request a retry" "$status"
fi
[[ $(<"$marker") == "boot-a" ]] || fail "an intro interrupted after OWE accepted it still consumes the boot"

use_background "$theme_backgrounds/road.webp"
for index in {1..32}; do
  launch >/dev/null &
  launcher_pids[$index]=$!
done
for launcher_pid in "${launcher_pids[@]}"; do
  wait "$launcher_pid"
done
(( $(played | wc -l) == 1 )) || fail "concurrent launchers start exactly one intro" "$(played | wc -l)"

failing_bin="$test_tmp/failing-bin"
mkdir -p "$failing_bin"
printf '#!/bin/bash\nexit 1\n' >"$failing_bin/mv"
chmod +x "$failing_bin/mv"
use_background "$theme_backgrounds/road.webp"
if env PATH="$failing_bin:$command_bin:$ROOT/bin:$PATH" HOME="$intro_home" COMMAND_LOG="$command_log" OMARCHY_BOOT_ID=boot-a \
  "$ROOT/bin/omarchy-theme-bg-boot-intro" 2>/dev/null; then
  fail "a failed marker write fails the launcher"
fi
! compgen -G "$state_dir/.background-intro.boot-id.*" >/dev/null || fail "a failed marker write leaves no staged marker behind"

pass "the boot is released only when OWE never started the intro"

: >"$command_log"
env PATH="$command_bin:$ROOT/bin:$PATH" HOME="$intro_home" COMMAND_LOG="$command_log" "$ROOT/bin/omarchy-toggle-background-intros"
[[ -f $toggle ]] && grep -q 'Background intros disabled' "$command_log" || fail "the toggle turns intros off"
env PATH="$command_bin:$ROOT/bin:$PATH" HOME="$intro_home" COMMAND_LOG="$command_log" "$ROOT/bin/omarchy-toggle-background-intros"
[[ ! -e $toggle ]] && grep -q 'Background intros enabled' "$command_log" || fail "the toggle turns intros back on"

pass "the toggle turns background intros off and on"

migration=$(grep -l 'Stage background intros for the active theme' "$ROOT"/migrations/*.sh)
migration_home="$test_tmp/migration-home"
migration_bin="$test_tmp/migration-bin"
migration_calls="$test_tmp/migration-calls"
mkdir -p "$migration_home/.local/state/omarchy/current" "$migration_bin"
cat >"$migration_bin/omarchy-theme-refresh" <<'SH'
#!/bin/bash
printf 'refresh\n' >>"$MIGRATION_CALLS"
SH
chmod +x "$migration_bin/omarchy-theme-refresh"
migrate() {
  : >"$migration_calls"
  HOME="$migration_home" PATH="$migration_bin:$PATH" MIGRATION_CALLS="$migration_calls" OMARCHY_PATH="$ROOT" \
    OMARCHY_BOOT_ID=update-boot bash -euo pipefail "$migration" >/dev/null
}

theme_with_intros=$(ls -d "$ROOT"/themes/*/backgrounds/intros | head -1)
theme_with_intros=${theme_with_intros%/backgrounds/intros}
printf '%s\n' "${theme_with_intros##*/}" >"$migration_home/.local/state/omarchy/current/theme.name"
migrate
[[ $(<"$migration_calls") == "refresh" ]] || fail "the migration stages an active theme that ships intros"
[[ $(<"$migration_home/.local/state/omarchy/background-intro.boot-id") == "update-boot" ]] \
  || fail "the migration records the updating boot so the restarted shell plays no intro"

printf 'custom-theme\n' >"$migration_home/.local/state/omarchy/current/theme.name"
migrate
[[ ! -s $migration_calls ]] || fail "the migration leaves a theme without intros alone"
rm "$migration_home/.local/state/omarchy/current/theme.name"
migrate
[[ ! -s $migration_calls ]] || fail "the migration tolerates missing theme state"

pass "the migration stages intros without playing one during the update"

run_node_test <<'JS'
const fs = require('fs')
const backgroundQml = fs.readFileSync(path.join(root, 'shell/plugins/background/Background.qml'), 'utf8')

assert(
  /root\.setBackground\(String\(text \|\| ""\)\.trim\(\), false\)\s*\n\s*root\.checkBootIntro\(\)/.test(backgroundQml),
  'the first background lookup starts the launcher once the still is set'
)
assert(
  backgroundQml.includes('command: ["omarchy-theme-bg-boot-intro"]')
    && backgroundQml.includes('readonly property int bootIntroMaxAttempts: 60')
    && backgroundQml.includes('readonly property int bootIntroRetryInterval: 1000')
    && backgroundQml.includes('exitCode === 2 && root.bootIntroAttempts < root.bootIntroMaxAttempts')
    && backgroundQml.includes('bootIntroRetry.restart()'),
  'the shell retries through the login window while OWE is not up'
)
assert(
  !/bootIntroCover|color: "black"/.test(backgroundQml),
  'nothing covers the still: the intro opens on it'
)
JS

packaged=0
for intro in "$ROOT"/themes/*/backgrounds/intros/*; do
  [[ -e $intro ]] || continue
  name=${intro##*/}
  [[ $name == *.mp4 ]] || fail "packaged intros are mp4 files" "$intro"
  backgrounds=${intro%/intros/*}
  compgen -G "$backgrounds/${name%.mp4}.*" >/dev/null || fail "a packaged intro is named after a still in its theme" "$intro"
  ((++packaged))
done
(( packaged > 0 )) || fail "no packaged intros were found"

pass "packaged intros are named after their stills"
