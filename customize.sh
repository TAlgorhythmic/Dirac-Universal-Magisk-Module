#!/system/bin/sh
# Runs during flashing, after the zip is extracted to $MODPATH.
# Magisk/KernelSU/APatch provide: ui_print, abort, set_perm, set_perm_recursive,
# ARCH, API, IS64BIT, BOOTMODE, MODPATH, TMPDIR, ZIPFILE, KSU.

ui_print " "
ui_print "- $(grep_prop name "$MODPATH/module.prop") $(grep_prop version "$MODPATH/module.prop")"
ui_print "- $(getprop ro.product.device)  Android $(getprop ro.build.version.release)  $ARCH"

[ "$API" -lt 26 ] && abort "! Android 8.0 (API 26) or newer required"

case "$ARCH" in
	arm64)
		mv -f "$MODPATH/system/priv-app/DiracUI64" "$MODPATH/system/priv-app/DiracUI"
		rm -rf "$MODPATH/system/priv-app/DiracUI32"
		;;
	arm)
		rm -rf "$MODPATH/system/lib64"
		mv -f "$MODPATH/system/priv-app/DiracUI32" "$MODPATH/system/priv-app/DiracUI"
		rm -rf "$MODPATH/system/priv-app/DiracUI64"
		;;
	*) abort "! Unsupported architecture: $ARCH" ;;
esac

ui_print "Hiding stock dirac if exists..."
for part in /system /vendor /product /system_ext /odm /my_product; do
	# Skip if missing or symlink 
	[ -d "$part" ] && [ ! -L "$part" ] || continue

	for f in $(find "$part" -xdev -iname '*dirac*' -prune 2>/dev/null); do
		# The module mirrors everything under /system (/vendor/x -> /system/vendor/x)
		case "$f" in
			/system/*) t="$f" ;;
			*)         t="/system$f" ;;
		esac

		# Skip anything this module ships itself
		[ -e "$MODPATH$t" ] && continue
		REMOVE="$REMOVE
		$t"
	done
done

# Permissions
ui_print "- Setting permissions"
set_perm_recursive "$MODPATH" 0 0 0755 0644

for d in "$MODPATH/system/vendor/etc" "$MODPATH/system/odm/etc" "$MODPATH/system/my_product/etc"; do
	[ -d "$d" ] && set_perm_recursive "$d" 0 0 0755 0644 u:object_r:vendor_configs_file:s0
done
for d in "$MODPATH/system/lib/soundfx" "$MODPATH/system/lib64/soundfx"; do
	[ -d "$d" ] && set_perm_recursive "$d" 0 0 0755 0644
done

ui_print "- Effects are registered at every boot by post-fs-data.sh"
ui_print "- Done. Reboot to apply."
ui_print " "
