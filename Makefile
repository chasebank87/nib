ZIG ?= zig
XCODEGEN ?= xcodegen
SWIFT ?= swift
SWIFTFORMAT ?= swiftformat
SWIFTLINT ?= swiftlint
CONFIGURATION ?= Debug
DERIVED_DATA ?= $(CURDIR)/.derivedData
ZIG_LIB_DIR := $(CURDIR)/ZigCore/zig-out/lib

.PHONY: help zig test-zig test-swift test build run format lint bench

help:
	@echo "nib targets:"
	@echo "  make zig         Build libnib_core"
	@echo "  make test-zig    Run Zig unit tests"
	@echo "  make test-swift  Run Swift package tests (macOS, requires Zig build)"
	@echo "  make test        test-zig + test-swift"
	@echo "  make build       Generate Xcode project and build the app"
	@echo "  make run         Build and launch nib.app"
	@echo "  make format      zig fmt + SwiftFormat"
	@echo "  make lint        SwiftLint + zig fmt --check"
	@echo "  make bench       Placeholder until NIB-017"

zig:
	cd ZigCore && $(ZIG) build -Doptimize=ReleaseSafe

test-zig:
	cd ZigCore && $(ZIG) build test --summary all

test-swift: zig
	$(SWIFT) test --package-path "$(CURDIR)" \
		-Xlinker -L$(ZIG_LIB_DIR) \
		-Xlinker -lnib_core

test: test-zig test-swift

build: zig
	$(XCODEGEN) generate
	xcodebuild \
		-project Nib.xcodeproj \
		-scheme Nib \
		-configuration $(CONFIGURATION) \
		-destination 'platform=macOS' \
		-derivedDataPath "$(DERIVED_DATA)" \
		CODE_SIGNING_ALLOWED=NO \
		build

run: build
	open "$(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/nib.app"

format:
	$(ZIG) fmt ZigCore/build.zig ZigCore/src
	$(SWIFTFORMAT) App UI Domain Services CoreBridge Tests Package.swift

lint:
	$(ZIG) fmt --check ZigCore/build.zig ZigCore/src
	$(SWIFTLINT) lint --strict

bench:
	@echo "NIB-017: Zig buffer/search benchmarks are not implemented yet."
	@echo "Planned: cd ZigCore && zig build -Doptimize=ReleaseFast && zig build bench"
	@exit 0
