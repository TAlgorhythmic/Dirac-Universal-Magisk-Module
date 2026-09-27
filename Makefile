# Builds the flashable Magisk module zip.
#
#   make            build out/<id>-<version>.zip
#   make check      sanity-check the module layout
#   make install    adb sideload the zip (recovery)
#   make push       install the zip on a booted, rooted device
#   make clean      remove build output

MODULE_PROP  := module.prop
ID           := $(shell sed -n 's/^id=//p' $(MODULE_PROP))
VERSION      := $(shell sed -n 's/^version=//p' $(MODULE_PROP))
VERSION_CODE := $(shell sed -n 's/^versionCode=//p' $(MODULE_PROP))

OUT   := out
STAGE := $(OUT)/stage
ZIP   := $(OUT)/$(ID)-$(VERSION).zip

# Contents of the zip. Optional files are picked up only if they exist.
CONTENT := $(MODULE_PROP) META-INF customize.sh service.sh post-fs-data.sh \
           uninstall.sh system
CONTENT += README.md LICENSE aml.sh
CONTENT += $(wildcard sepolicy.rule) $(wildcard system.prop)

SOURCES := $(shell find $(CONTENT) -type f 2>/dev/null)
TEXT    := $(MODULE_PROP) customize.sh service.sh post-fs-data.sh uninstall.sh

ADB      ?= adb
DEVICE   ?= /data/local/tmp

.DEFAULT_GOAL := all
.PHONY: all zip check clean list lint install push bump help

all: $(ZIP)
zip: $(ZIP)

$(ZIP): $(SOURCES) $(MAKEFILE_LIST)
	@command -v zip >/dev/null || { echo "error: 'zip' not installed" >&2; exit 1; }
	@rm -rf $(STAGE) && mkdir -p $(STAGE)
	@cp -a $(CONTENT) $(STAGE)/
	@find $(STAGE) -name .gitkeep -delete
	@# ship LF line endings and sane modes no matter what the editor did
	@find $(STAGE) -type f \( -name '*.sh' -o -name '*.prop' -o -name '*-binary' \
		-o -name '*-script' -o -name '*.rule' \) -exec sed -i 's/\r$$//' {} +
	@find $(STAGE) -type d -exec chmod 0755 {} +
	@find $(STAGE) -type f -exec chmod 0644 {} +
	@chmod 0755 $(STAGE)/META-INF/com/google/android/update-binary
	@rm -f $@
	@cd $(STAGE) && zip -qr9X $(abspath $@) .
	@rm -rf $(STAGE)
	@echo "built $@ ($$(du -h $@ | cut -f1))"

check:
	@fail=0; \
	for f in id name version versionCode author description; do \
		grep -q "^$$f=" $(MODULE_PROP) || { echo "module.prop: missing $$f"; fail=1; }; \
	done; \
	case "$(VERSION_CODE)" in ''|*[!0-9]*) echo "module.prop: versionCode must be an integer"; fail=1;; esac; \
	[ -f META-INF/com/google/android/update-binary ] || { echo "missing update-binary"; fail=1; }; \
	grep -q '^#MAGISK' META-INF/com/google/android/updater-script \
		|| { echo "updater-script must start with #MAGISK"; fail=1; }; \
	for f in $(TEXT); do \
		! grep -qU $$'\r' $$f || { echo "$$f: CRLF line endings"; fail=1; }; \
	done; \
	[ $$fail -eq 0 ] && echo "check: ok $(ID) $(VERSION) ($(VERSION_CODE))"; \
	exit $$fail

lint:
	@command -v shellcheck >/dev/null \
		&& shellcheck -s sh -e SC1091,SC2034,SC2148 $(wildcard *.sh) \
		|| echo "shellcheck not installed, skipping"

list: $(ZIP)
	@unzip -l $(ZIP)

install: $(ZIP)
	$(ADB) sideload $(ZIP)

push: $(ZIP)
	$(ADB) push $(ZIP) $(DEVICE)/$(notdir $(ZIP))
	$(ADB) shell su -c 'magisk --install-module $(DEVICE)/$(notdir $(ZIP))'
	@echo "reboot to apply: $(ADB) reboot"

bump:
	@sed -i 's/^versionCode=.*/versionCode=$(shell expr $(VERSION_CODE) + 1)/' $(MODULE_PROP)
	@echo "versionCode -> $$(sed -n 's/^versionCode=//p' $(MODULE_PROP))"

clean:
	@rm -rf $(OUT)

help:
	@sed -n '2,8p' $(MAKEFILE_LIST) | sed 's/^# \?//'
