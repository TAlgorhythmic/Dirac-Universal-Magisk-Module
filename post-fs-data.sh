#!/system/bin/sh
MODDIR=${0%/*}

NS=vendor.dirac
CONFIG=536 # 24 (the service's own default) | 512 (force the AFM backend)
STARTATBOOT=3 # 3 = LOCKED_BOOT_COMPLETED, 1 = BOOT_COMPLETED
STORESETTINGS=0

LIBNAME=dirac
EFFECTLIB=libdiraceffect.so
GEFUUID=3799D6D1-22C5-43C3-B3EC-D664CF8D2F0D
AFMUUID=743539F8-1076-451F-8395-84ACFAB0FAC7
CTLUUID=128B9BA2-D0C9-47C6-AFF3-9F761CD0E228
AMLDIR=/data/adb/modules/aml

dlog() { /system/bin/log -p i -t dirac "$1" 2>/dev/null; }

dlog "config=$CONFIG startAtBoot=$STARTATBOOT storeSettings=$STORESETTINGS"

resetprop -n ro.audio.ignore_effects false

resetprop -n vendor.dirac.config "$CONFIG"
resetprop -n ro.vendor.dirac.config "$CONFIG"
resetprop -n persist.vendor.dirac.config "$CONFIG"
resetprop -n ro.vendor.dirac.startAtBoot "$STARTATBOOT"
resetprop -n ro.vendor.dirac.acs.startAtBoot "$STARTATBOOT"
resetprop -n ro.vendor.dirac.acs.config "$CONFIG"
resetprop -n ro.vendor.dirac.acs.forceAfm true
resetprop -n ro.vendor.dirac.storeSettings "$STORESETTINGS"
resetprop -n ro.vendor.dirac.acs.storeSettings "$STORESETTINGS"
resetprop -n ro.vendor.dirac.acs.ignore_error 0

# Effect registration
[ -d "$AMLDIR" ] && [ ! -f "$AMLDIR/disable" ] && {
	dlog "Audio Modification Library present, leaving registration to aml.sh"
	exit 0
}

add_effect_xml() {
	grep -q "name=\"$1\"" "$FILE" || \
		sed -i "/<effects>/ a\\        <effect name=\"$1\" library=\"$LIBNAME\" uuid=\"$2\"/>" "$FILE"
}

patch_xml() {
	grep -q "name=\"$LIBNAME\"" "$FILE" || \
		sed -i "/<libraries>/ a\\        <library name=\"$LIBNAME\" path=\"$EFFECTLIB\"/>" "$FILE"
	add_effect_xml dirac_gef "$GEFUUID"
	add_effect_xml dirac_afm "$AFMUUID"
	add_effect_xml dirac_controller "$CTLUUID"
}

add_effect_conf() {
	grep -qE "^[[:space:]]+$1 \{" "$FILE" || \
		sed -i "s|^effects {|effects {\n  $1 {\n    library $LIBNAME\n    uuid $2\n  }|" "$FILE"
}

# The legacy .conf format needs an absolute path, unlike the XML which takes a
# bare name and lets the framework search odm/vendor/system soundfx dirs. Pick
# the copy matching audioserver's own bitness - ELF class byte 5 is 2 for 64-bit.
conf_lib_path() {
	if [ "$(od -An -tu1 -j4 -N1 /system/bin/audioserver 2>/dev/null | tr -d ' ')" = 2 ] \
	   && [ -f "$MODDIR/system/vendor/lib64/soundfx/$EFFECTLIB" ]; then
		echo "/system/vendor/lib64/soundfx/$EFFECTLIB"
	else
		echo "/system/vendor/lib/soundfx/$EFFECTLIB"
	fi
}

patch_conf() {
	grep -qE "^[[:space:]]+$LIBNAME \{" "$FILE" || \
		sed -i "s|^libraries {|libraries {\n  $LIBNAME {\n    path $(conf_lib_path)\n  }|" "$FILE"
	add_effect_conf dirac_gef "$GEFUUID"
	add_effect_conf dirac_afm "$AFMUUID"
	add_effect_conf dirac_controller "$CTLUUID"
}

# Where a system path is staged inside the module so it mounts back over itself.
modpath_for() {
	case "$1" in
		/system/*) echo "$MODDIR$1" ;;
		*) echo "$MODDIR/system$1" ;;
	esac
}

# Drop last boot's copies so each boot re-derives from the ROM's current file.
find "$MODDIR/system" -type f \
     \( -name "audio_effects*.conf" -o -name "audio_effects*.xml" \) \
     -delete 2>/dev/null

COUNT=0
for SRC in $(find /vendor/etc /system/etc /odm/etc /my_product/etc -maxdepth 2 -type f \
             \( -name "audio_effects*.conf" -o -name "audio_effects*.xml" \) 2>/dev/null); do
	case "$SRC" in *spatializer*|*haptic*) continue ;; esac
	FILE="$(modpath_for "$SRC")"
	mkdir -p "$(dirname "$FILE")"
	cp -af "$SRC" "$FILE" || continue
	case "$SRC" in
		*.xml) patch_xml ;;
		*.conf) patch_conf ;;
	esac
	chown 0:0 "$FILE"; chmod 0644 "$FILE"
	case "$SRC" in
		/vendor/*|/odm/*|/my_product/*) chcon u:object_r:vendor_configs_file:s0 "$FILE" 2>/dev/null ;;
		*) chcon u:object_r:system_file:s0 "$FILE" 2>/dev/null ;;
	esac
	COUNT=$((COUNT + 1))
	dlog "registered effects in $SRC"
done

[ "$COUNT" -eq 0 ] && dlog "WARNING: no audio_effects config found, Dirac will not load"
dlog "Post fs script finished"
exit 0
