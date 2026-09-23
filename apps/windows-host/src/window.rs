use crate::diagnostics::{self, Report};
use std::os::windows::ffi::OsStrExt;
use std::{
    mem, ptr,
    sync::mpsc::{self, Receiver, TryRecvError},
};
use windows_sys::Win32::{
    Foundation::*,
    Graphics::Gdi::*,
    System::LibraryLoader::GetModuleHandleW,
    UI::{
        Controls::EM_SETLIMITTEXT, Input::KeyboardAndMouse::EnableWindow, WindowsAndMessaging::*,
    },
};

const COLLECT: usize = 101;
const FOLDER: usize = 102;
const POLL: usize = 1;

struct State {
    button: HWND,
    folder: HWND,
    status: HWND,
    preview: HWND,
    report: Option<Report>,
    pending: Option<Receiver<Result<Report, String>>>,
}

fn wide(text: &str) -> Vec<u16> {
    text.encode_utf16().chain(Some(0)).collect()
}

unsafe fn set_text(hwnd: HWND, text: &str) {
    SetWindowTextW(hwnd, wide(text).as_ptr());
}

unsafe fn notice(hwnd: HWND, text: &str) {
    MessageBoxW(
        hwnd,
        wide(text).as_ptr(),
        wide("OpenVNC Host").as_ptr(),
        MB_OK | MB_ICONINFORMATION,
    );
}

unsafe fn control(
    parent: HWND,
    class: &str,
    text: &str,
    style: u32,
    id: usize,
    rect: [i32; 4],
) -> HWND {
    let child = CreateWindowExW(
        0,
        wide(class).as_ptr(),
        wide(text).as_ptr(),
        WS_CHILD | WS_VISIBLE | style,
        rect[0],
        rect[1],
        rect[2],
        rect[3],
        parent,
        id as HMENU,
        GetModuleHandleW(ptr::null()),
        ptr::null(),
    );
    if !child.is_null() {
        SendMessageW(
            child,
            WM_SETFONT,
            GetStockObject(DEFAULT_GUI_FONT) as usize,
            1,
        );
    }
    child
}

// All handles and State are accessed only on the UI thread. The worker returns owned data.
unsafe extern "system" fn window_proc(hwnd: HWND, message: u32, w: WPARAM, l: LPARAM) -> LRESULT {
    let state = GetWindowLongPtrW(hwnd, GWLP_USERDATA) as *mut State;
    if message == WM_DESTROY {
        PostQuitMessage(0);
        return 0;
    }
    if state.is_null() {
        return DefWindowProcW(hwnd, message, w, l);
    }
    match message {
        WM_COMMAND if w & 0xffff == COLLECT && (*state).pending.is_none() => {
            let (tx, rx) = mpsc::channel();
            let spawn = std::thread::Builder::new()
                .name("host-diagnostics".into())
                .spawn(move || {
                    let result = std::panic::catch_unwind(diagnostics::collect)
                        .unwrap_or_else(|_| Err("Falha interna ao coletar diagnóstico.".into()));
                    let _ = tx.send(result);
                });
            if let Err(error) = spawn {
                notice(hwnd, &error.to_string());
                return 0;
            }
            (*state).pending = Some(rx);
            (*state).report = None;
            EnableWindow((*state).button, 0);
            EnableWindow((*state).folder, 0);
            set_text((*state).preview, "");
            set_text((*state).status, "Consultando Windows, GPU, telas e serviços…\r\nA coleta pode levar até 60 segundos.");
            0
        }
        WM_COMMAND if w & 0xffff == FOLDER => {
            if let Some(report) = &(*state).report {
                if let Some(folder) = report.path.parent() {
                    // Pass the path as an argument, never as a shell command.
                    if let Some(root) = std::env::var_os("SystemRoot") {
                        if let Err(error) = std::process::Command::new(
                            std::path::PathBuf::from(root).join("explorer.exe"),
                        )
                        .arg(folder)
                        .spawn()
                        {
                            notice(hwnd, &format!("Não foi possível abrir a pasta: {error}"));
                        }
                    }
                }
            }
            0
        }
        WM_TIMER if w == POLL => {
            let outcome = (*state).pending.as_ref().map(|rx| rx.try_recv());
            let result = match outcome {
                Some(Ok(result)) => result,
                Some(Err(TryRecvError::Disconnected)) => Err("A coleta foi interrompida.".into()),
                _ => return 0,
            };
            (*state).pending = None;
            EnableWindow((*state).button, 1);
            match result {
                Ok(report) => {
                    let path: Vec<u16> = report.path.as_os_str().encode_wide().collect();
                    let path = String::from_utf16_lossy(&path);
                    set_text(
                        (*state).status,
                        &format!("{}\r\nArquivo: {path}", report.summary),
                    );
                    set_text(
                        (*state).preview,
                        &report.text.replace('\n', "\r\n").replace("\r\r\n", "\r\n"),
                    );
                    (*state).report = Some(report);
                    EnableWindow((*state).folder, 1);
                }
                Err(error) => set_text((*state).status, &error),
            }
            0
        }
        WM_CLOSE if (*state).pending.is_some() => {
            notice(
                hwnd,
                "Aguarde a coleta terminar (até 60 segundos) antes de fechar.",
            );
            0
        }
        _ => DefWindowProcW(hwnd, message, w, l),
    }
}

pub fn run() {
    unsafe {
        let instance = GetModuleHandleW(ptr::null());
        let name = wide("OpenVNCHostWindow");
        let class = WNDCLASSW {
            lpfnWndProc: Some(window_proc),
            hInstance: instance,
            hCursor: LoadCursorW(ptr::null_mut(), IDC_ARROW),
            hbrBackground: (COLOR_WINDOW + 1) as HBRUSH,
            lpszClassName: name.as_ptr(),
            ..mem::zeroed()
        };
        if RegisterClassW(&class) == 0 {
            notice(ptr::null_mut(), "Não foi possível registrar a janela.");
            return;
        }
        let hwnd = CreateWindowExW(
            0,
            name.as_ptr(),
            wide("OpenVNC Host — Diagnóstico").as_ptr(),
            WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX,
            CW_USEDEFAULT,
            CW_USEDEFAULT,
            800,
            660,
            ptr::null_mut(),
            ptr::null_mut(),
            instance,
            ptr::null(),
        );
        if hwnd.is_null() {
            notice(ptr::null_mut(), "Não foi possível abrir o OpenVNC Host.");
            return;
        }
        let title = control(
            hwnd,
            "STATIC",
            "OpenVNC Host · Primeira versão",
            0,
            0,
            [20, 18, 740, 24],
        );
        let intro = control(hwnd, "STATIC", "Colete as informações deste Windows para preparar o monitor virtual.\r\nEsta versão faz diagnóstico local; pareamento e monitor virtual ainda não estão disponíveis.", 0, 0, [20, 50, 740, 44]);
        let button = control(
            hwnd,
            "BUTTON",
            "Coletar diagnóstico",
            WS_TABSTOP | BS_DEFPUSHBUTTON as u32,
            COLLECT,
            [20, 108, 180, 34],
        );
        let folder = control(
            hwnd,
            "BUTTON",
            "Abrir pasta do relatório",
            WS_TABSTOP,
            FOLDER,
            [216, 108, 200, 34],
        );
        let status = control(
            hwnd,
            "STATIC",
            "Pronto. A coleta consulta o sistema e salva um relatório JSON local.",
            0,
            0,
            [20, 156, 740, 84],
        );
        let preview = control(
            hwnd,
            "EDIT",
            "",
            WS_BORDER
                | WS_VSCROLL
                | WS_TABSTOP
                | ES_MULTILINE as u32
                | ES_READONLY as u32
                | ES_AUTOVSCROLL as u32,
            0,
            [20, 250, 740, 310],
        );
        let privacy = control(hwnd, "STATIC", "O relatório contém IPs da rede e configuração das telas. Revise antes de compartilhar.\r\nNenhuma senha, captura de tela ou instalação de driver é coletada/executada.", 0, 0, [20, 575, 740, 40]);
        if [title, intro, button, folder, status, preview, privacy]
            .iter()
            .any(|h| h.is_null())
        {
            notice(hwnd, "Não foi possível criar os controles da janela.");
            DestroyWindow(hwnd);
            return;
        }
        SendMessageW(preview, EM_SETLIMITTEXT, 1024 * 1024, 0);
        EnableWindow(folder, 0);
        let state = Box::into_raw(Box::new(State {
            button,
            folder,
            status,
            preview,
            report: None,
            pending: None,
        }));
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, state as isize);
        if SetTimer(hwnd, POLL, 100, None) == 0 {
            notice(
                hwnd,
                "Não foi possível iniciar a atualização do diagnóstico.",
            );
            SetWindowLongPtrW(hwnd, GWLP_USERDATA, 0);
            drop(Box::from_raw(state));
            DestroyWindow(hwnd);
            return;
        }
        ShowWindow(hwnd, SW_SHOW);
        let mut message: MSG = mem::zeroed();
        loop {
            let result = GetMessageW(&mut message, ptr::null_mut(), 0, 0);
            if result <= 0 {
                break;
            }
            if IsDialogMessageW(hwnd, &message) == 0 {
                TranslateMessage(&message);
                DispatchMessageW(&message);
            }
        }
        KillTimer(hwnd, POLL);
        drop(Box::from_raw(state));
    }
}
