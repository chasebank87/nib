const std = @import("std");

pub const version: [:0]const u8 = "0.1.0";

pub fn validateUtf8(bytes: []const u8) bool {
    return std.unicode.utf8ValidateSlice(bytes);
}

export fn nib_core_version() callconv(.c) [*:0]const u8 {
    return version.ptr;
}

export fn nib_core_utf8_validate(bytes: ?[*]const u8, len: usize) callconv(.c) i32 {
    if (len == 0) return 1;
    const ptr = bytes orelse return 0;
    return if (validateUtf8(ptr[0..len])) 1 else 0;
}

test "version is non-empty" {
    try std.testing.expect(version.len >= 5);
}

test "utf8 validate accepts empty" {
    try std.testing.expect(validateUtf8(""));
}

test "utf8 validate accepts ascii" {
    try std.testing.expect(validateUtf8("hello, nib"));
}

test "utf8 validate accepts multibyte" {
    try std.testing.expect(validateUtf8("café 🖋️"));
}

test "utf8 validate rejects lone continuation" {
    const bad = [_]u8{0x80};
    try std.testing.expect(!validateUtf8(&bad));
}

test "c abi empty is valid" {
    try std.testing.expectEqual(@as(i32, 1), nib_core_utf8_validate(null, 0));
}

test "c abi null with length is invalid" {
    try std.testing.expectEqual(@as(i32, 0), nib_core_utf8_validate(null, 4));
}
