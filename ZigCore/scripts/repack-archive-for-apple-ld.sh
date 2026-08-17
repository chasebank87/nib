#!/bin/sh
# Zig's llvm-ar writes Mach-O archive members that are not 8-byte aligned.
# Apple ld (Xcode 16.4+, including Xcode 26) rejects those archives:
#   ld: 64-bit mach-o member 'libnib_core_zcu.o' not 8-byte aligned
#
# Feeding that archive straight to `libtool -static` is worse: libtool
# silently discards the unaligned zcu object, and the app then fails with:
#   Undefined symbols: _nib_core_version, _nib_core_utf8_validate
#
# `ranlib -D` rewrites member alignment in place without dropping objects.
# Then `libtool -static` can emit an archive Apple ld will accept.
#
# usage: repack-archive-for-apple-ld.sh <input.a> [output.a]
# If output is omitted, the input archive is replaced.
set -eu

if [ "$(uname -s)" != "Darwin" ]; then
  exit 0
fi

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: $0 <input.a> [output.a]" >&2
  exit 1
fi

input=$1
output=${2:-$1}

if [ ! -f "$input" ]; then
  echo "error: archive not found: $input" >&2
  exit 1
fi

work=$(mktemp)
out=$(mktemp)
cleanup() {
  rm -f "$work" "$out"
}
trap cleanup EXIT

cp "$input" "$work"
xcrun ranlib -D "$work"
xcrun libtool -static -no_warning_for_no_symbols -o "$out" "$work"

if ! nm -g "$out" | grep -q 'nib_core_version'; then
  echo "error: archive is missing nib_core_version after Apple ld repack" >&2
  nm -g "$out" >&2 || true
  exit 1
fi
if ! nm -g "$out" | grep -q 'nib_core_utf8_validate'; then
  echo "error: archive is missing nib_core_utf8_validate after Apple ld repack" >&2
  nm -g "$out" >&2 || true
  exit 1
fi

mv -f "$out" "$output"
trap - EXIT
rm -f "$work"
