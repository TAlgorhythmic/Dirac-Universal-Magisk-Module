#!/system/bin/sh
# late_start: logs the resolved state, restages the apps if needed and grants
# runtime permissions. Output goes to service.log in the module folder.
MODDIR=${0%/*}

exec > "$MODDIR/service.log" 2>&1
set -x

dlog() { /system/bin/log -p i -t dirac "$1" 2>/dev/null; }

dlog "Running dirac service.sh"

resetprop -n ro.audio.ignore_effects false

resetprop -n ro.vendor.dirac.startAtBoot "$STARTATBOOT"
resetprop -n ro.vendor.dirac.config "$CONFIG"
resetprop -n ro.vendor.dirac.acs.startAtBoot "$STARTATBOOT"
resetprop -n ro.vendor.dirac.acs.config "$CONFIG"
resetprop -n ro.vendor.dirac.acs.forceAfm true
resetprop -n ro.vendor.dirac.storeSettings "$STORESETTINGS"
resetprop -n ro.vendor.dirac.acs.storeSettings "$STORESETTINGS"
resetprop -n ro.vendor.dirac.acs.ignore_error 0

NS=vendor.dirac
CFG=$(getprop $NS.config)
dlog "$NS.config=$CFG startAtBoot=$(getprop $NS.acs.startAtBoot) storeSettings=$(getprop $NS.acs.storeSettings)"

case "$CFG" in
	"") dlog "WARNING: $NS.config is empty, resetprop did not take" ;;
	*) [ $(( CFG & 512 )) -eq 0 ] && dlog "WARNING: AFM bit clear in $CFG, GEF will be probed first" ;;
esac

until [ "$(getprop sys.boot_completed)" = "1" ]; do
	sleep 2
done
sleep 5

ACSPKG="se.dirac.acs"
UIPKG="me.algorhythmics.diracui"

# If using magisk
if command -v magisk >/dev/null 2>&1 && [ -z "$KSU" ] && [ -z "$APATCH" ]; then
	magisk --denylist rm "$ACSPKG" 2>/dev/null
	magisk --denylist rm "$UIPKG" 2>/dev/null
	magisk --sulist add "$ACSPKG" 2>/dev/null
	magisk --sulist add "$UIPKG" 2>/dev/null

	if magisk magiskhide sulist 2>/dev/null; then
		magisk magiskhide add "$ACSPKG" 2>/dev/null
		magisk magiskhide add "$UIPKG" 2>/dev/null
	else
		magisk magiskhide rm "$ACSPKG" 2>/dev/null
		magisk magiskhide rm "$UIPKG" 2>/dev/null
	fi
fi

API=$(getprop ro.build.version.sdk)

if appops get "$ACSPKG" > /dev/null 2>&1; then
	if [ "$API" -ge 30 ]; then
		appops set "$ACSPKG" AUTO_REVOKE_PERMISSIONS_IF_UNUSED ignore
	fi
	if [ "$API" -ge 33 ]; then
		appops set "$ACSPKG" ACCESS_RESTRICTED_SETTINGS allow
	fi
	if [ "$API" -ge 35 ]; then
		pm grant --all-permissions "$ACSPKG"
	fi
fi

if appops get "$UIPKG" > /dev/null 2>&1; then
	if [ "$API" -ge 30 ]; then
		appops set "$UIPKG" AUTO_REVOKE_PERMISSIONS_IF_UNUSED ignore
	fi
	if [ "$API" -ge 33 ]; then
		appops set "$UIPKG" ACCESS_RESTRICTED_SETTINGS allow
	fi
	if [ "$API" -ge 35 ]; then
		pm grant --all-permissions "$UIPKG"
	elif [ "$API" -ge 31 ]; then
		pm grant "$UIPKG" android.permission.BLUETOOTH_CONNECT
	fi
fi
