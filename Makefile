APP_NAME = AppMusicRPS
BUILD_DIR = .build
APP_BUNDLE = $(APP_NAME).app
BINARY = $(APP_NAME)

.PHONY: all build bundle clean run

all: bundle

build:
	swift build -c release 2>&1

bundle: build
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/release/$(BINARY) $(APP_BUNDLE)/Contents/MacOS/$(BINARY)
	cp AppMusicRPS/Info.plist $(APP_BUNDLE)/Contents/Info.plist
	# discord-rpc binary — copy from source
	cp AppMusicRPS/Resources/discord-rpc $(APP_BUNDLE)/Contents/Resources/discord-rpc
	chmod +x $(APP_BUNDLE)/Contents/MacOS/$(BINARY)
	chmod +x $(APP_BUNDLE)/Contents/Resources/discord-rpc
	@echo "✅ $(APP_BUNDLE) built"

run: bundle
	open $(APP_BUNDLE)

clean:
	rm -rf $(BUILD_DIR) $(APP_BUNDLE)
