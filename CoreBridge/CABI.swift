import Foundation

/// Swift declarations for the C ABI in `ZigCore/include/nib_core.h`.
/// Kept as `@_silgen_name` so the package does not need pkg-config to compile.
@_silgen_name("nib_core_version")
func nib_core_version() -> UnsafePointer<CChar>

@_silgen_name("nib_core_utf8_validate")
func nib_core_utf8_validate(_ bytes: UnsafePointer<UInt8>?, _ len: Int) -> Int32
