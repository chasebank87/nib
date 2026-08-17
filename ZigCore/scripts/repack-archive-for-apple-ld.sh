#!/bin/sh
# Zig's llvm-ar writes Mach-O archive members that are not 8-byte aligned.
# Apple ld (Xcode 16.4+, including Xcode 26) rejects those archives:
#   ld: 64-bit mach-o member 'libnib_core_zcu.o' not 8-byte aligned
# Apple libtool rewrites the archive with the padding ld requires.
set -eu

if [ "$(uname -s)" != "Darwin" ]; then
  exit 0
fi

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <lib.a>" >&2
  exit 1
fi

archive=$1
if [ ! -f "$archive" ]; then
  echo "error: archive not found: $archive" >&2
  exit 1
fi

tmp=$(mktemp "${archive}.XXXXXX")
cleanup() {
  rm -f "$tmp"
}
trap cleanup EXIT

xcrun libtool -static -no_warning_for_no_symbols -o "$tmp" "$archive"
mv -f "$tmp" "$archive"
trap - EXIT
