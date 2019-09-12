TARGET = iphone:clang:9.2
ARCHS = arm64# arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SpotifyBackgrounds
$(TWEAK_NAME)_FILES = Tweak.xm

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 Spotify"
