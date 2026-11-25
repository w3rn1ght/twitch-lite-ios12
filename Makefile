TARGET := iphone:clang:12.4:12.0
ARCHS := arm64

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = TwitchLite

TwitchLite_FILES := $(wildcard Sources/*.m)
TwitchLite_CFLAGS := -fobjc-arc -Wall -Wextra -Wno-unused-parameter -Wno-deprecated-declarations \
                     -Wno-unused-function -Wno-sign-compare -Wno-unknown-warning-option \
                     -Wno-unused-variable -Wno-missing-braces -Wno-unused-but-set-variable
TwitchLite_FRAMEWORKS := UIKit Foundation WebKit AVFoundation AVKit CoreMedia Security SafariServices
TwitchLite_INSTALL_PATH = /Applications
TwitchLite_RESOURCE_DIRS = Resources
TwitchLite_CODESIGN_FLAGS = -S

include $(THEOS_MAKE_PATH)/application.mk
