#ifndef OPENVNC_CORE_H
#define OPENVNC_CORE_H

#include <stddef.h>
#include <stdint.h>

// Keep layouts synchronized with crates/openvnc-core/src/lib.rs.
typedef struct {
    uint32_t status;
    uint32_t width;
    uint32_t height;
    uint32_t scale_percent;
} OpenVNCDisplayRequest;

// Returns 0 for a valid host, 1 otherwise. Does not connect.
uint32_t openvnc_validate_host(const uint8_t *bytes, size_t length);
OpenVNCDisplayRequest openvnc_prepare_display(uint32_t width, uint32_t height, double scale);

#endif
