include $(THEOS)/makefiles/common.mk

TARGET = iphone:clang:9.2
TARGET_IPHONEOS_DEPLOYMENT_VERSION = 9.2
ifdef 64
	ARCHS = arm64
else ifdef 64E
	ARCHS = arm64e
else
	ARCHS = arm64 arm64e
endif

BUNDLE_NAME = SpringArtworkPrefs
$(BUNDLE_NAME)_FILES = SARootListController.xm $(wildcard *.xm) $(wildcard *.m) ../../TwitterStuff/Prompt.m ../SettingsKeys.m
$(BUNDLE_NAME)_CFLAGS = -fobjc-arc
$(BUNDLE_NAME)_INSTALL_PATH = /Library/PreferenceBundles
$(BUNDLE_NAME)_LIBRARIES = colorpicker
$(BUNDLE_NAME)_FRAMEWORKS = SafariServices
$(BUNDLE_NAME)_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/SpringArtwork.plist$(ECHO_END)
