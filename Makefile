TARGET = iphone:clang:9.2
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SpringArtwork
$(TWEAK_NAME)_FILES = Tweak.xm SAViewController.xm SADockViewController.xm SAManager.xm Common.m SAImageHelper.m SettingsKeys.m
$(TWEAK_NAME)_FRAMEWORKS = AVFoundation MediaRemote
$(TWEAK_NAME)_CFLAGS = -fobjc-arc
$(TWEAK_NAME)_LIBRARIES = rocketbootstrap colorpicker
$(TWEAK_NAME)_PRIVATE_FRAMEWORKS = AppSupport

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"

SUBPROJECTS += preferences

include $(THEOS_MAKE_PATH)/aggregate.mk
