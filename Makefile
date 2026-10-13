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
	./scripts/bundle_app.sh 1.0.3

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
