//! Local session preparation. No connection or host mutation occurs here.

use std::net::IpAddr;

/// A bare IP address or DNS name (including Tailscale MagicDNS).
pub fn valid_host(host: &str) -> bool {
    if host.is_empty() || host.len() > 253 || !host.is_ascii() {
        return false;
    }
    if host.parse::<IpAddr>().is_ok() {
        return true;
    }
    // Do not accept malformed dotted IPv4 addresses as DNS names.
    if host.bytes().all(|c| c.is_ascii_digit() || c == b'.') {
        return false;
    }
    host.split('.').all(|label| {
        !label.is_empty()
            && label.len() <= 63
            && label.as_bytes()[0].is_ascii_alphanumeric()
            && label.as_bytes()[label.len() - 1].is_ascii_alphanumeric()
            && label
                .bytes()
                .all(|c| c.is_ascii_alphanumeric() || c == b'-')
    })
}

/// Requested framebuffer dimensions; the Windows host must negotiate support.
#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct DisplayRequest {
    /// 0 = valid, 1 = invalid dimensions, 2 = invalid scale.
    pub status: u32,
    pub width: u32,
    pub height: u32,
    pub scale_percent: u32,
}

pub fn prepare_display(width: u32, height: u32, scale: f64) -> DisplayRequest {
    let status = if !(320..=16384).contains(&width) || !(200..=16384).contains(&height) {
        1
    } else if !scale.is_finite() || !(1.0..=4.0).contains(&scale) {
        2
    } else {
        0
    };
    if status != 0 {
        return DisplayRequest {
            status,
            width: 0,
            height: 0,
            scale_percent: 0,
        };
    }
    DisplayRequest {
        status,
        width,
        height,
        scale_percent: (scale * 100.0).round() as u32,
    }
}

/// Validates UTF-8 bytes without retaining or allocating foreign memory.
///
/// # Safety
/// `bytes` must point to `length` readable bytes for the duration of the call.
#[no_mangle]
pub unsafe extern "C" fn openvnc_validate_host(bytes: *const u8, length: usize) -> u32 {
    if bytes.is_null() || length == 0 || length > 253 {
        return 1;
    }
    let bytes = unsafe { std::slice::from_raw_parts(bytes, length) };
    match std::str::from_utf8(bytes) {
        Ok(host) if valid_host(host) => 0,
        _ => 1,
    }
}

#[no_mangle]
pub extern "C" fn openvnc_prepare_display(width: u32, height: u32, scale: f64) -> DisplayRequest {
    prepare_display(width, height, scale)
}
