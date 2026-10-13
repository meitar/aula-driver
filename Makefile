.PHONY: all build test run-app cli install-cli clean

all: build

build:
	swift build -c release

test:
	swift run aula-test-runner

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
