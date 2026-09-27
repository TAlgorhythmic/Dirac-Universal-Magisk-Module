#!/system/bin/sh
# late_start: everything functional is already done by post-fs-data.sh and the
# module mount. This only records the resolved state so a bad boot can be
# diagnosed from one logcat grab.
MODDIR=${0%/*}

dlog() { /system/bin/log -p i -t dirac "$1" 2>/dev/null; }

dlog "Running dirac service.sh"

NS=vendor.dirac
CFG=$(getprop $NS.config)
dlog "$NS.config=$CFG startAtBoot=$(getprop $NS.acs.startAtBoot) storeSettings=$(getprop $NS.acs.storeSettings)"

case "$CFG" in
	"") dlog "WARNING: $NS.config is empty, resetprop did not take" ;;
	*) [ $(( CFG & 512 )) -eq 0 ] && dlog "WARNING: AFM bit clear in $CFG, GEF will be probed first" ;;
esac

TMPDIR=/data/local/tmp

APPS="
se.dirac.acs:$MODDIR/system/priv-app/DiracAudioControlService/DiracAudioControlService.apk
me.algorhythmics.diracui:$MODDIR/system/priv-app/DiracUI/DiracUI.apk
"

# Wait for PackageManager to be ready
until [ "$(getprop sys.boot_completed)" = "1" ]; do
	sleep 2
done
sleep 5

for entry in $APPS; do
	pkg=${entry%%:*}
	apk=${entry#*:}
	marker="$MODDIR/.installed_$pkg"

	if [ ! -f "$apk" ]; then
		dlog "$pkg: APK not found at $apk"
		continue
	fi

	hash=$(sha256sum "$apk" | cut -d' ' -f1)

	# Skip if the /data update exists and matches this module's APK
	if pm path "$pkg" 2>/dev/null | grep -q '/data/app/' \
		&& [ "$(cat "$marker" 2>/dev/null)" = "$hash" ]; then
		dlog "$pkg: up to date"
		continue
	fi

	# Install from /data/local/tmp to avoid SELinux denials on the module path
	tmp="$TMPDIR/$pkg.apk"
	cp "$apk" "$tmp" && chmod 644 "$tmp"
	if out=$(pm install -r "$tmp" 2>&1); then
		echo "$hash" > "$marker"
		dlog "$pkg: installed ($out)"
	else
		dlog "$pkg: install failed ($out)"
	fi
	rm -f "$tmp"
done

# Grant bluetooth permissions
SDK=$(getprop ro.build.version.sdk)
if [ "$SDK" -ge 31 ]; then
	pm grant me.algorhythmics.diracui android.permission.BLUETOOTH_CONNECT
fi
