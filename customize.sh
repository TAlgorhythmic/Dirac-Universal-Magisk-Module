#!/system/bin/sh
# Runs during flashing, after the zip is extracted to $MODPATH.

if [ "$BOOTMODE" != "true" ]; then
	abort "! Installing from recovery is not supported, use Magisk, KernelSU or APatch"
fi

ui_print " "
ui_print "- $(grep_prop name "$MODPATH/module.prop") $(grep_prop version "$MODPATH/module.prop")"
ui_print "- $(getprop ro.product.device)  Android $(getprop ro.build.version.release)  $ARCH"

[ "$API" -lt 26 ] && abort "! Android 8.0 (API 26) or newer required"

case "$ARCH" in
	arm64)
		;;
	arm)
		rm -rf "$MODPATH/system/vendor/lib64"
		;;
	*) abort "! Unsupported architecture: $ARCH" ;;
esac

ui_print "- Hiding stock dirac if exists..."
for part in /system /vendor /product /system_ext /odm /my_product; do
	[ -d "$part" ] && [ ! -L "$part" ] || continue

	for f in $(find "$part" -xdev -iname '*dirac*' -prune 2>/dev/null); do
		case "$f" in
			/system/*) t="$f" ;;
			*)         t="/system$f" ;;
		esac

		[ -e "$MODPATH$t" ] && continue
		REMOVE="$REMOVE
		$t"
	done
done

ui_print "- Setting permissions"
set_perm_recursive "$MODPATH" 0 0 0755 0644

# Perms + SELinux
for d in "$MODPATH/system/vendor/etc" "$MODPATH/system/odm/etc" "$MODPATH/system/my_product/etc"; do
	[ -d "$d" ] && set_perm_recursive "$d" 0 0 0755 0644 u:object_r:vendor_configs_file:s0
done
for d in "$MODPATH/system/vendor/lib" "$MODPATH/system/vendor/lib64"; do
	[ -d "$d" ] && set_perm_recursive "$d" 0 0 0755 0644 u:object_r:vendor_file:s0
done

for s in post-fs-data.sh service.sh uninstall.sh; do
	[ -f "$MODPATH/$s" ] && set_perm "$MODPATH/$s" 0 0 0755
done

if [ "$KSU" = "true" ]; then
	ui_print "! WARNING: KernelSU detected"
	ui_print "! Additional manual configuration is required:"
	ui_print "! Turn off 'Umount modules by default' in KernelSU settings"
fi

ui_print "- Done. Reboot to apply."
ui_print " "
