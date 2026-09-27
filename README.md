# Dirac Universal

Dirac audio for any Android device.

Dirac Audio is a stock OEM sound-enhancement stack featuring headphone
impulse-response filters, EQ, and spatial effects.

## Features

* **Headphone filters** - impulse-response correction, six profiles bundled
* **Equalizer** - per-usecase, applied in the DSP rather than the app
* **Spatial effects** - Dirac's SFX processing for speaker and headset
* **Stereo width and tonal balance** - continuous, `-1.0` to `+1.0`
* **Presets** - DiracUI stores a preset per Bluetooth device and per output,
  and applies it as soon as the service binds
* **Speaker and headset tunings** - separate DSP profiles, switched per usecase
* **Custom settings app** - My own settings app to manage settings
* **Merged devices and filters** - diracvdd.bin with multiple devices from
  various vendors combined, selectable in the UI
* **arm64 and arm32 support**

## Requirements

* Android 8.0 (API 26) or newer. Hard requirement.
* Magisk, KernelSU or APatch
* [Audio Modification Library](https://github.com/reiryuki/Audio-Modification-Library-Ryuki-Mod-Magisk-Module) if used alongside any other audio mod.
* **KernelSU only:** a mount metamodule. Install one of these first, then reboot:
    * [meta-overlayfs](https://github.com/tiann/KernelSU/releases) — the official reference implementation
    * [mountify](https://github.com/backslashxx/mountify) — overlayfs backed by tmpfs or an ext4 sparse image
    * [Hybrid-mount](https://github.com/Hybrid-Mount/meta-hybrid_mount) — Flexible mounting, lets you choose between magic mount an overlayfs, written in rust

  Magisk and APatch mount modules themselves and need nothing extra.
* **KernelSU only:** both APKs ship inside the module, so unmounting modules for
  an app takes that app's own APK with it. Pick one:
    * Turn off *Umount modules by default* in the KernelSU settings, or
    * Disable *Umount modules* in App Profile for `me.algorhythmics.diracui` and
      `se.dirac.acs`. Doing the same for your Launcher, SystemUI, Settings and
      PermissionController is also recommended.

## Installing

Flash the zip in the manager and reboot. Open **DiracUI** to configure.
To uninstall, remove the module from the root manager.

## Building

    make          # build out/<id>-<version>.zip

## Licence

The module scripts, packaging, and the **DiracUI** app are MIT licensed. See `LICENSE`.

**The MIT licence does not apply to the Dirac components.** The following are
proprietary works of Dirac Research AB, redistributed here unmodified, and are covered
by their own terms, not by this project's licence:

    libDiracAPI_SHARED.so     libdiraceffect.so
    libdiracapwrapper.so      libdirac.so
    DiracAudioControlService.apk  (se.dirac.acs)
    diracmobile.config        diracvdd.bin        interfacedb

They are included only to make the stack usable on hardware it was not meant for.
No source is provided for them and none is available. If you redistribute this module
or reuse parts of it, those files remain Dirac Research's property and their terms
apply. This project is unofficial and is not affiliated with, endorsed by, or supported
by Dirac Research AB or OPPO/OPlus.
