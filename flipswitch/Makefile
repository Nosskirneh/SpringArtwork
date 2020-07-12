TARGET = iphone:clang:11.2
ifdef 64
	ARCHS = arm64
else ifdef 64E
	ARCHS = arm64e
else
	ARCHS = arm64 arm64e
endif

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = SAFlipswitch
$(BUNDLE_NAME)_FILES = Switch.x
$(BUNDLE_NAME)_FRAMEWORKS = UIKit
$(BUNDLE_NAME)_LIBRARIES = flipswitch
$(BUNDLE_NAME)_INSTALL_PATH = /Library/Switches
$(BUNDLE_NAME)_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	# PreferenceLoader plist
	$(ECHO_NOTHING)if [ -f Preferences.plist ]; then mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/SAFlipswitch; cp Preferences.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/SAFlipswitch/; fi$(ECHO_END)
