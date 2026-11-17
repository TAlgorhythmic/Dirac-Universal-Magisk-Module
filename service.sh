#!/system/bin/sh
# late_start: logs the resolved state, restages the apps if needed and grants
# runtime permissions. Output goes to service.log in the module folder.
MODDIR=${0%/*}

exec > "$MODDIR/service.log" 2>&1
set -x

dlog() { /system/bin/log -p i -t dirac "$1" 2>/dev/null; }

# cmd-based tools (appops, pm, settings) pass their fds to system_server, which can't
# write to service.log (system_file in the module dir) and fails with "Failed transaction".
# Capturing through a pipe works.
run() {
	out=$("$@" </dev/null 2>&1)
	rc=$?
	[ -n "$out" ] && echo "$out"
	return $rc
}

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

# Prevent the service from booting into safe-mode.
if [ "$API" -ge 28 ]; then
	EX='Landroid/media/audiofx/AudioEffect;'
	CUR=$(run settings get global hidden_api_blacklist_exemptions)
	case "$CUR" in
		*"$EX"*) ;;
		*)
			[ -z "$CUR" ] || [ "$CUR" = null ] || EX="$CUR,$EX"
			run settings put global hidden_api_blacklist_exemptions "$EX"
			sleep 1
			pkill -x "$ACSPKG"
			;;
	esac
fi

if run appops get "$ACSPKG" > /dev/null; then
	if [ "$API" -ge 30 ]; then
		run appops set "$ACSPKG" AUTO_REVOKE_PERMISSIONS_IF_UNUSED ignore
	fi
	if [ "$API" -ge 33 ]; then
		run appops set "$ACSPKG" ACCESS_RESTRICTED_SETTINGS allow
	fi
	if [ "$API" -ge 35 ]; then
		run pm grant --all-permissions "$ACSPKG"
	fi
fi

if run appops get "$UIPKG" > /dev/null; then
	if [ "$API" -ge 30 ]; then
		run appops set "$UIPKG" AUTO_REVOKE_PERMISSIONS_IF_UNUSED ignore
	fi
	if [ "$API" -ge 33 ]; then
		run appops set "$UIPKG" ACCESS_RESTRICTED_SETTINGS allow
	fi
	if [ "$API" -ge 35 ]; then
		run pm grant --all-permissions "$UIPKG"
	elif [ "$API" -ge 31 ]; then
		run pm grant "$UIPKG" android.permission.BLUETOOTH_CONNECT
	fi
fi
