# Persist wireless regulatory domain based on the target timezone. Install is
# followed by reboot, so don't mutate live Wi-Fi state with `iw reg set`.
regdom_file=/etc/conf.d/wireless-regdom
[[ -f $regdom_file ]] || exit 0

if grep -q '^WIRELESS_REGDOM=' "$regdom_file"; then
  exit 0
fi

timezone=""
if [[ -e /etc/localtime ]]; then
  timezone=$(readlink -f /etc/localtime || true)
  timezone=${timezone#/usr/share/zoneinfo/}
fi

country="${timezone%%/*}"
zone_tab=/usr/share/zoneinfo/zone.tab
if [[ ! $country =~ ^[A-Z]{2}$ && -n $timezone && -f $zone_tab ]]; then
  country=$(awk -v tz="$timezone" '$3 == tz {print $1; exit}' "$zone_tab")
fi

# zone.tab names each zone once. The older names the timezone pickers still
# offer (Israel, Japan, Asia/Calcutta) are links listed in tzdata.zi. Follow the
# link, but take its country only when every zone.tab zone behind it agrees:
# Iceland now shares its data with Africa/Abidjan and must not become Côte
# d'Ivoire. An all-caps name (EET, WET) is a time, not a place.
tzdata_zi=/usr/share/zoneinfo/tzdata.zi
if [[ -z $country && $timezone == *[[:lower:]]* && -f $zone_tab && -f $tzdata_zi ]]; then
  country=$(awk -v tz="$timezone" '
    FNR == NR { if ($1 == "L") canonical[$3] = $2; next }
    /^#/ { next }
    { zone = ($3 in canonical) ? canonical[$3] : $3 }
    zone == canonical[tz] && !seen[$1]++ { countries++; country = $1 }
    END { if (countries == 1) print country }
  ' "$tzdata_zi" "$zone_tab")
fi

if [[ $country =~ ^[A-Z]{2}$ ]]; then
  echo "WIRELESS_REGDOM=\"$country\"" | sudo tee -a "$regdom_file" >/dev/null
fi
