ZIG ?= zig
XCODEGEN ?= xcodegen
SWIFT ?= swift
SWIFTFORMAT ?= swiftformat
SWIFTLINT ?= swiftlint
CONFIGURATION ?= Debug
DERIVED_DATA ?= $(CURDIR)/.derivedData
ZIG_LIB_DIR := $(CURDIR)/ZigCore/zig-out/lib
# Pin arch so xcodebuild does not warn about arm64 vs x86_64 destinations.
DESTINATION ?= platform=macOS,arch=$(shell uname -m)
REPACK_ARCHIVE := $(CURDIR)/ZigCore/scripts/repack-archive-for-apple-ld.sh

.PHONY: help setup check-zig check-xcodegen check-xcodebuild check-xcode-first-launch zig test-zig test-swift test project build run open format lint bench

help:
	@echo "nib targets:"
	@echo "  make setup       Check for zig, XcodeGen, and xcodebuild"
	@echo "  make zig         Build libnib_core (repacks for Apple ld on macOS)"
	@echo "  make test-zig    Run Zig unit tests"
	@echo "  make test-swift  Run Swift package tests (macOS, requires Zig; no XcodeGen)"
	@echo "  make test        test-zig + test-swift"
	@echo "  make project     Generate Nib.xcodeproj (requires XcodeGen)"
	@echo "  make build       Generate Xcode project and build the app"
	@echo "  make run         Build and launch nib.app"
	@echo "  make open        Generate Nib.xcodeproj and open it in Xcode"
	@echo "  make format      zig fmt + SwiftFormat"
	@echo "  make lint        SwiftLint + zig fmt --check"
	@echo "  make bench       Placeholder until NIB-017"

check-zig:
	@command -v $(ZIG) >/dev/null 2>&1 || { \
		echo "error: zig is not installed or not on PATH."; \
		echo "       brew install zig"; \
		echo "       see docs/TOOLCHAINS.md"; \
		exit 1; \
	}

check-xcodegen:
	@command -v $(XCODEGEN) >/dev/null 2>&1 || { \
		echo "error: xcodegen is not installed (needed to generate Nib.xcodeproj)."; \
		echo "       brew install xcodegen"; \
		echo "       make test   # package tests do not need XcodeGen"; \
		echo "       make build  # after XcodeGen is installed"; \
		exit 1; \
	}

check-xcodebuild:
	@command -v xcodebuild >/dev/null 2>&1 || { \
		echo "error: xcodebuild is not installed. Install Xcode from the Mac App Store."; \
		exit 1; \
	}
	@DEVELOPER_DIR=$$(xcode-select -p 2>/dev/null || true); \
	case "$$DEVELOPER_DIR" in \
		*/CommandLineTools) \
			echo "error: xcodebuild needs the full Xcode app, not Command Line Tools."; \
			echo "       Active directory is $$DEVELOPER_DIR"; \
			echo "       1. Install Xcode from the Mac App Store if needed."; \
			echo "       2. sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"; \
			echo "       3. sudo xcodebuild -license accept"; \
			echo "       Or open the generated project in Xcode:"; \
			echo "       make project && open Nib.xcodeproj"; \
			echo "       make test still works with Command Line Tools."; \
			exit 1; \
			;; \
	esac
	@xcodebuild -version >/dev/null 2>&1 || { \
		echo "error: xcodebuild cannot run. Point xcode-select at Xcode.app:"; \
		echo "       sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"; \
		exit 1; \
	}

check-xcode-first-launch: check-xcodebuild
	@if [ ! -d /Library/Developer/PrivateFrameworks/CoreSimulator.framework ]; then \
		echo "error: Xcode additional components are missing (CoreSimulator)."; \
		echo "       sudo xcodebuild -runFirstLaunch"; \
		echo "       or open Xcode.app once and wait until extra components finish."; \
		echo "       GUI workaround (no CLI build): make open"; \
		exit 1; \
	fi

setup: check-zig check-xcodegen check-xcodebuild check-xcode-first-launch
	@echo "zig        $$($(ZIG) version)"
	@echo "xcodegen   $$($(XCODEGEN) version 2>/dev/null || echo installed)"
	@echo "xcodebuild $$(xcodebuild -version | head -n 1)"
	@echo "Toolchains look ready."

zig:
	cd ZigCore && $(ZIG) build -Doptimize=ReleaseSafe
	$(REPACK_ARCHIVE) $(ZIG_LIB_DIR)/libnib_core.a

test-zig:
	cd ZigCore && $(ZIG) build test --summary all

test-swift: zig
	$(SWIFT) test --package-path "$(CURDIR)" \
		-Xlinker -L$(ZIG_LIB_DIR) \
		-Xlinker -lnib_core

test: test-zig test-swift

project: check-xcodegen
	$(XCODEGEN) generate

build: zig check-xcodegen check-xcode-first-launch
	$(XCODEGEN) generate
	xcodebuild \
		-project Nib.xcodeproj \
		-scheme Nib \
		-configuration $(CONFIGURATION) \
		-destination '$(DESTINATION)' \
		-derivedDataPath "$(DERIVED_DATA)" \
		CODE_SIGNING_ALLOWED=NO \
		build

run: build
	open "$(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/nib.app"

open: zig project
	open Nib.xcodeproj

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
