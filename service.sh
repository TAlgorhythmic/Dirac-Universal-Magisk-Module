#!/system/bin/sh
# late_start: everything functional is already done by post-fs-data.sh and the
# module mount. This only records the resolved state so a bad boot can be
# diagnosed from one logcat grab.
MODDIR=${0%/*}

dlog() { /system/bin/log -p i -t dirac "$1" 2>/dev/null; }

NS=vendor.dirac
CFG=$(getprop $NS.config)
dlog "$NS.config=$CFG startAtBoot=$(getprop $NS.acs.startAtBoot) storeSettings=$(getprop $NS.acs.storeSettings)"

case "$CFG" in
	"") dlog "WARNING: $NS.config is empty, resetprop did not take" ;;
	*) [ $(( CFG & 512 )) -eq 0 ] && dlog "WARNING: AFM bit clear in $CFG, GEF will be probed first" ;;
esac
