TARGET = iphone:clang:11.2
ifdef DEBUG
	ARCHS = arm64
else
	ARCHS = arm64 arm64e
endif

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = Flipswitch

Flipswitch_FILES = Switch.x
Flipswitch_FRAMEWORKS = UIKit
Flipswitch_LIBRARIES = flipswitch
Flipswitch_INSTALL_PATH = /Library/Switches
Flipswitch_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	# PreferenceLoader plist
	$(ECHO_NOTHING)if [ -f Preferences.plist ]; then mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/SpringArtworkFlipswitch; cp Preferences.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/SpringArtworkFlipswitch/; fi$(ECHO_END)
