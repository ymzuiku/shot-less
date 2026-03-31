.PHONY: ios ios-gen testflight

BUNDLE_ID := com.ymzuiku.ScreenshotCleaner
APP_NAME  := ScreenshotCleaner
APP_PATH  := build/Build/Products/Debug-iphoneos/$(APP_NAME).app

API_KEYS_DIR       := ../vibe-remote-api-keys
ASC_API_KEY_ID     := 523PH2J3BK
ASC_API_ISSUER_ID  := cdc01ff3-bd77-4719-b95d-1bb10b9c14ac
ASC_KEY_FULL_PATH  := $(shell cd $(API_KEYS_DIR) 2>/dev/null && pwd)/connect_AuthKey_$(ASC_API_KEY_ID).p8

ios:
	xcodegen generate
	xcodebuild build \
		-project $(APP_NAME).xcodeproj \
		-scheme $(APP_NAME) \
		-configuration Debug \
		-arch arm64 \
		-sdk iphoneos \
		-derivedDataPath build \
		-allowProvisioningUpdates \
		-quiet
	xcrun devicectl device install app --device 00008120-001259313420C01E $(APP_PATH)
	xcrun devicectl device process launch --device 00008120-001259313420C01E $(BUNDLE_ID)

ios-gen:
	xcodegen generate

testflight:
	@echo "=== TestFlight Release ==="
	$(eval BUILD_NUMBER := $(shell date +%Y%m%d%H%M))
	@echo "Build number: $(BUILD_NUMBER)"
	@sed -i '' 's/CURRENT_PROJECT_VERSION: .*/CURRENT_PROJECT_VERSION: "$(BUILD_NUMBER)"/' project.yml
	@if [ -n "$$KEYCHAIN_PASSWORD" ]; then \
		echo "Unlocking keychain..."; \
		security unlock-keychain -p "$$KEYCHAIN_PASSWORD" ~/Library/Keychains/login.keychain-db; \
		security set-keychain-settings -t 3600 ~/Library/Keychains/login.keychain-db; \
		security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$$KEYCHAIN_PASSWORD" ~/Library/Keychains/login.keychain-db > /dev/null 2>&1; \
	fi
	xcodegen generate
	@echo "Archiving..."
	xcodebuild clean archive \
		-project $(APP_NAME).xcodeproj \
		-scheme $(APP_NAME) \
		-archivePath build/$(APP_NAME).xcarchive \
		-destination 'generic/platform=iOS' \
		-allowProvisioningUpdates \
		-authenticationKeyPath "$(ASC_KEY_FULL_PATH)" \
		-authenticationKeyID "$(ASC_API_KEY_ID)" \
		-authenticationKeyIssuerID "$(ASC_API_ISSUER_ID)"
	@echo "Uploading to App Store Connect..."
	xcodebuild -exportArchive \
		-archivePath build/$(APP_NAME).xcarchive \
		-exportOptionsPlist ExportOptions.plist \
		-exportPath build/export \
		-allowProvisioningUpdates \
		-authenticationKeyPath "$(ASC_KEY_FULL_PATH)" \
		-authenticationKeyID "$(ASC_API_KEY_ID)" \
		-authenticationKeyIssuerID "$(ASC_API_ISSUER_ID)"
	@echo "=== Done! Check App Store Connect for the new build. ==="
