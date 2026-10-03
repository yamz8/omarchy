echo "Stage background intros for the active theme"

# The update restarts the shell, and the first shell of a boot plays the
# background's intro. Record this boot as played so the update plays none.
state_dir="$HOME/.local/state/omarchy"
boot_id=${OMARCHY_BOOT_ID:-$(< /proc/sys/kernel/random/boot_id)}
mkdir -p "$state_dir"
marker_staged=$(mktemp "$state_dir/.background-intro.boot-id.XXXXXX")
trap 'rm -f "$marker_staged"' EXIT
printf '%s\n' "$boot_id" >"$marker_staged"
mv -f "$marker_staged" "$state_dir/background-intro.boot-id"
trap - EXIT

# The active theme was staged before it shipped intros, so stage it again.
theme_name_path="$state_dir/current/theme.name"
[[ -s $theme_name_path ]] || exit 0

theme_name=$(<"$theme_name_path")
[[ $theme_name =~ ^[[:alnum:]_][[:alnum:].+_-]*$ ]] || exit 0
[[ -d $OMARCHY_PATH/themes/$theme_name/backgrounds/intros ]] || exit 0

omarchy-theme-refresh
