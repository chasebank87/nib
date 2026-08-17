# Toolchains

Pin versions here when they change. Bump this file in the same commit as CI.

## Current pins

| Tool | Version | Notes |
| --- | --- | --- |
| macOS deployment target | 14.0 | Sonoma. TextKit 2 + SwiftUI windowing quality. |
| Recommended host macOS | 15.x | Matches GitHub `macos-15` runners. |
| Xcode | 16.0+ | Swift 6 language mode. |
| Swift | 6.0+ | `swift-tools-version: 6.0` in `Package.swift`. |
| Zig | 0.16.0 | [Official download](https://ziglang.org/download/). |
| XcodeGen | 2.44+ | `brew install xcodegen` — used to generate `Nib.xcodeproj`. |
| SwiftFormat | latest via Homebrew | `make format` |
| SwiftLint | latest via Homebrew | `make lint` |

## Install Zig

```bash
# macOS (Homebrew)
brew install zig

# Verify
zig version   # expect 0.16.x
```

If Homebrew lags 0.16.0, use the official tarball for your arch from [ziglang.org/download](https://ziglang.org/download/) and put `zig` on `PATH`.

Linux (for Zig-only tests):

```bash
curl -fsSL https://ziglang.org/download/0.16.0/zig-x86_64-linux-0.16.0.tar.xz | tar -xJ -C /tmp
export PATH="/tmp/zig-x86_64-linux-0.16.0:$PATH"
zig version
```

Archive names differ by arch (`aarch64-macos`, `x86_64-macos`, `aarch64-linux`, `x86_64-linux`). Confirm on the download page if a fetch 404s.

## Xcode / Swift

```bash
xcode-select -p
xcodebuild -version
swift --version
```

`xcodebuild` must use the Xcode app. Command Line Tools (`/Library/Developer/CommandLineTools`) can compile `swift test` but not the `.app`:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
xcodebuild -version
```

If `xcodebuild` fails with `CoreSimulator` / `IDESimulatorFoundation` / `runFirstLaunch`, Xcode has not installed its extra system components yet:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
sudo xcodebuild -runFirstLaunch
```

Or open **Xcode.app** once and wait until it finishes installing additional components. Then `make build` again.

To skip the CLI and build in the IDE:

```bash
make open
```

This repository’s Linux/cloud agents typically **do not** have Xcode. Do not treat a missing `swift` binary as a project failure.

## Generate and build the app

`make test` does **not** need XcodeGen. `make build` and `make run` do.

```bash
brew install xcodegen
make setup
make zig
xcodegen generate
xcodebuild -scheme Nib -destination "platform=macOS,arch=$(uname -m)" CODE_SIGNING_ALLOWED=NO build
```

Or `make build` / `make run`. If `make build` prints `xcodegen: No such file or directory`, install XcodeGen and retry.

`make zig` (and therefore `make test` / `make build`) rewrites `ZigCore/zig-out/lib/libnib_core.a` for Apple `ld` on macOS: `ranlib -D` then `libtool -static`. Zig’s `llvm-ar` writes Mach-O archive members that are not 8-byte aligned; Apple `ld` in Xcode 16.4+ (including Xcode 26) rejects them:

```
ld: 64-bit mach-o member 'libnib_core_zcu.o' not 8-byte aligned in '.../libnib_core.a'
```

Running `libtool -static` on that raw archive **silently drops** `libnib_core_zcu.o`. The next error looks like missing C ABI symbols:

```
Undefined symbols for architecture arm64:
  "_nib_core_utf8_validate", referenced from: ... NibCoreBridge.o
  "_nib_core_version", referenced from: ... NibCoreBridge.o
```

`ranlib -D` fixes member alignment without discarding objects; `make zig` then verifies both symbols are still in the archive. Zig’s own tests do not use Apple `ld`, so they can pass while Swift/Xcode still fail until this rewrite runs.

The Xcode 26 note `product being built is not an allowed client of SwiftUICore` is unrelated noise from the debug dylib; it is not the linker failure.

## CI

[`.github/workflows/ci.yml`](../.github/workflows/ci.yml) runs on `macos-15`: install Zig 0.16.0, `make test-zig`, XcodeGen, `make test-swift`, `make build`.
