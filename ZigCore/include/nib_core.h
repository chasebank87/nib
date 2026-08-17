#ifndef NIB_CORE_H
#define NIB_CORE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * nib Zig core C ABI.
 *
 * Contract:
 * - All text is UTF-8.
 * - Input buffers are caller-owned; Zig does not retain them after return.
 * - nib_core_version returns a process-lifetime constant; do not free it.
 * - Future allocated outputs must ship with a matching nib_core_*_free.
 * - The core is not thread-safe in this slice. Serialize calls from Swift.
 */

/** NUL-terminated UTF-8 semantic version, e.g. "0.1.0". */
const char *nib_core_version(void);

/**
 * Returns 1 if `bytes[0..len]` is valid UTF-8 (including len == 0).
 * Returns 0 if `bytes` is NULL and len > 0, or if the sequence is invalid.
 */
int32_t nib_core_utf8_validate(const uint8_t *bytes, size_t len);

#ifdef __cplusplus
}
#endif

#endif /* NIB_CORE_H */
