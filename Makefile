APP_NAME = AppMusicRPS
BUILD_DIR = .build
APP_BUNDLE = $(APP_NAME).app
BINARY = $(APP_NAME)
RPC_BINARY = AppMusicRPS/Resources/discord-rpc

.PHONY: all build bundle clean run

all: bundle

build-rpc:
	cd discord-rpc-go && go build -o ../$(RPC_BINARY) .

build: build-rpc
	swift build -c release 2>&1

bundle: build
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/release/$(BINARY) $(APP_BUNDLE)/Contents/MacOS/$(BINARY)
	cp AppMusicRPS/Info.plist $(APP_BUNDLE)/Contents/Info.plist
	cp $(RPC_BINARY) $(APP_BUNDLE)/Contents/Resources/discord-rpc
	chmod +x $(APP_BUNDLE)/Contents/MacOS/$(BINARY)
	chmod +x $(APP_BUNDLE)/Contents/Resources/discord-rpc
	codesign --force --deep --sign - $(APP_BUNDLE)
	@echo "✅ $(APP_BUNDLE) built"

run: bundle
	open $(APP_BUNDLE)

clean:
	rm -rf $(BUILD_DIR) $(APP_BUNDLE) $(RPC_BINARY)
