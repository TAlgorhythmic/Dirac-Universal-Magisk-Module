#!/system/bin/sh
# late_start: everything functional is already done by post-fs-data.sh and the
# module mount. This only records the resolved state so a bad boot can be
# diagnosed from one logcat grab.
MODDIR=${0%/*}

exec > "$MODDIR/service.log" 2>&1
set -x

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
SDK=$(getprop ro.build.version.sdk)

# Wait for PackageManager to be ready
until [ "$(getprop sys.boot_completed)" = "1" ]; do
	sleep 2
done
sleep 5

if [ "$SDK" -ge 29 ]; then
	PKGACS="se.dirac.acs"
	PKGACSAPK="$MODDIR/system/priv-app/DiracAudioControlService/DiracAudioControlService.apk"
	PKGACSHASH=$(sha256sum "$PKGACSAPK" | cut -d' ' -f1)
	TMPACS="$TMPDIR/$PKGACS.apk"

	PKGUI="me.algorhythmics.diracui"
	PKGUIAPK="$MODDIR/system/priv-app/DiracUI/DiracUI.apk"
	PKGUIHASH=$(sha256sum "$PKGUIAPK" | cut -d' ' -f1)
	TMPUI="$TMPDIR/$PKGUI.apk"

	ACS_INSTALLED="$MODDIR/.installed_$PKGACS"
	UI_INSTALLED="$MODDIR/.installed_$PKGUI"

	# Install both if both missing
	if [ "$(cat "$ACS_INSTALLED" 2>/dev/null)" != "$PKGACSHASH" ] && [ "$(cat "$UI_INSTALLED" 2>/dev/null)" != "$PKGUIHASH" ]; then
		cp "$PKGACSAPK" "$TMPACS" && chmod 644 "$TMPACS"
		cp "$PKGUIAPK" "$TMPUI" && chmod 644 "$TMPUI"

		PARENT=$(pm install-create --multi-package --staged -r | sed 's/.*\[\([0-9]*\)\].*/\1/')

		ACS=$(pm install-create --staged -r | sed 's/.*\[\([0-9]*\)\].*/\1/')
		UI=$(pm install-create --staged -r | sed 's/.*\[\([0-9]*\)\].*/\1/')

		# Write each APK into its child session
		pm install-write "$ACS" base.apk "$TMPACS"
		pm install-write "$UI" base.apk "$TMPUI"

		if out=$(pm install-multi-package --staged -r "$TMPACS" "$TMPUI"); then
			echo "$PKGACSHASH" > "$ACS_INSTALLED"
			echo "$PKGUIHASH" > "$UI_INSTALLED"
		fi
		rm -f "$TMPACS" "$TMPUI"
	fi

	# Install acs if missing
	if [ "$(cat "$ACS_INSTALLED" 2>/dev/null)" != "$PKGACSHASH" ]; then
		cp "$PKGACSAPK" "$TMPACS" && chmod 644 "$TMPACS"
		if out=$(pm install --staged -r "$TMPACS"); then
			echo "$PKGACSHASH" > "$ACS_INSTALLED"
		fi
		rm -f "$TMPACS"
	fi

	# Install ui if missing
	if [ "$(cat "$UI_INSTALLED" 2>/dev/null)" != "$PKGUIHASH" ]; then
		cp "$PKGUIAPK" "$TMPUI" && chmod 644 "$TMPUI"
		if out=$(pm install --staged -r "$TMPUI"); then
			echo "$PKGUIHASH" > "$UI_INSTALLED"
		fi
		rm -f "$TMPUI"
	fi
fi

# Grant bluetooth permissions
if [ "$SDK" -ge 31 ]; then
	pm grant me.algorhythmics.diracui android.permission.BLUETOOTH_CONNECT
fi
