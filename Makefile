.PHONY: all build build-arm64 build-universal test run-app cli install-cli clean

all: build

build:
	swift build -c release

build-arm64:
	swift build -c release --triple arm64-apple-macosx

build-universal:
	swift build -c release --triple x86_64-apple-macosx
	swift build -c release --triple arm64-apple-macosx
	mkdir -p .build/universal/release
	lipo -create .build/x86_64-apple-macosx/release/aula-cli .build/arm64-apple-macosx/release/aula-cli -output .build/universal/release/aula-cli
	lipo -create .build/x86_64-apple-macosx/release/AulaDriverApp .build/arm64-apple-macosx/release/AulaDriverApp -output .build/universal/release/AulaDriverApp
	@echo "Universal binaries built successfully in .build/universal/release/"

test:
	swift run aula-test-runner

app: build-universal
	mkdir -p AulaDriverApp.app/Contents/MacOS
	mkdir -p AulaDriverApp.app/Contents/Resources
	cp Resources/AppIcon.icns AulaDriverApp.app/Contents/Resources/AppIcon.icns
	cp .build/universal/release/AulaDriverApp AulaDriverApp.app/Contents/MacOS/AulaDriverApp
	cat << 'EOF' > AulaDriverApp.app/Contents/Info.plist
	<?xml version="1.0" encoding="UTF-8"?>
	<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
	<plist version="1.0">
	<dict>
	    <key>CFBundleExecutable</key>
	    <string>AulaDriverApp</string>
	    <key>CFBundleIconFile</key>
	    <string>AppIcon</string>
	    <key>CFBundleIconName</key>
	    <string>AppIcon</string>
	    <key>CFBundleIdentifier</key>
	    <string>com.aulakit.driver</string>
	    <key>CFBundleName</key>
	    <string>Aula Driver</string>
	    <key>CFBundlePackageType</key>
	    <string>APPL</string>
	    <key>CFBundleShortVersionString</key>
	    <string>1.0.2</string>
	    <key>CFBundleVersion</key>
	    <string>1.0.2</string>
	    <key>LSMinimumSystemVersion</key>
	    <string>13.0</string>
	    <key>NSHighResolutionCapable</key>
	    <true/>
	</dict>
	</plist>
	EOF
	codesign --force --deep --sign - AulaDriverApp.app
	@echo "AulaDriverApp.app bundled successfully"

run-app:
	swift run AulaDriverApp

cli:
	swift run aula-cli $(ARGS)

install-cli: build
	mkdir -p $(HOME)/.local/bin
	cp .build/release/aula-cli $(HOME)/.local/bin/aula-cli
	@echo "Installed aula-cli to $(HOME)/.local/bin/aula-cli"

clean:
	rm -rf .build
