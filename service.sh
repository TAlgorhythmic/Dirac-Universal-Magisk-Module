#!/system/bin/sh
# late_start: logs the resolved state, restages the apps if needed and grants
# runtime permissions. Output goes to service.log in the module folder.
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

until [ "$(getprop sys.boot_completed)" = "1" ]; do
	sleep 2
done
sleep 5

if [ "$KSU" = "true" ] || [ "$APATCH" = "true" ]; then
	CHECK_PATH=true
	. "$MODDIR/stage_apps.sh"
fi

if [ "$(getprop ro.build.version.sdk)" -ge 31 ]; then
	if pm grant me.algorhythmics.diracui android.permission.BLUETOOTH_CONNECT; then
		dlog "BLUETOOTH_CONNECT granted"
	else
		dlog "WARNING: could not grant BLUETOOTH_CONNECT"
	fi
fi
