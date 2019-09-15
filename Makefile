TARGET = iphone:clang:9.2
ARCHS = arm64# arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SpotifyBackgrounds
$(TWEAK_NAME)_FILES = Tweak.xm SAViewController.xm SACanvasReceiver.xm Common.m
$(TWEAK_NAME)_FRAMEWORKS = AVFoundation
$(TWEAK_NAME)_CFLAGS = -fobjc-arc
$(TWEAK_NAME)_LIBRARIES = rocketbootstrap
$(TWEAK_NAME)_PRIVATE_FRAMEWORKS = AppSupport

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 Spotify SpringBoard"
