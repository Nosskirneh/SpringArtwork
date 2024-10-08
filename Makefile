TARGET = iphone:clang:11.2
ifdef 64
	ARCHS = arm64
else ifdef 64E
	ARCHS = arm64e
else
	ARCHS = arm64 arm64e
endif

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SpringArtwork
$(TWEAK_NAME)_FILES = Tweak.xm Spotify.xm SASPTService.xm SASPTHandler.xm SAViewController.xm SABlurEffect.m SAManager.xm Common.m SAImageHelper.m SettingsKeys.m
$(TWEAK_NAME)_FRAMEWORKS = AVFoundation MediaRemote
$(TWEAK_NAME)_CFLAGS = -fobjc-arc
$(TWEAK_NAME)_LIBRARIES = rocketbootstrap colorpicker
$(TWEAK_NAME)_PRIVATE_FRAMEWORKS = AppSupport MediaRemote

include $(THEOS_MAKE_PATH)/tweak.mk

ifdef PREFS_ONLY
after-install::
	install.exec "killall -9 Preferences"
else ifdef CLIENTS_ONLY
after-install::
	install.exec "killall -9 Spotify"
else
after-install::
	install.exec "killall -9 SpringBoard"
endif

SUBPROJECTS += preferences
SUBPROJECTS += flipswitch

include $(THEOS_MAKE_PATH)/aggregate.mk
