#![cfg_attr(windows, windows_subsystem = "windows")]

#[cfg(windows)]
mod diagnostics;
#[cfg(windows)]
mod window;

fn main() {
    #[cfg(windows)]
    window::run();
    #[cfg(not(windows))]
    {
        eprintln!("OpenVNC Host requires an interactive Windows desktop.");
        std::process::exit(1);
    }
}
