use std::os::windows::process::CommandExt;
use std::{
    fs,
    path::PathBuf,
    process::{Command, Stdio},
    thread,
    time::{Duration, Instant, SystemTime, UNIX_EPOCH},
};

const SCRIPT: &str = include_str!("../../../scripts/windows/Get-OpenVNCHostDiagnostics.ps1");

pub struct Report {
    pub path: PathBuf,
    pub text: String,
    pub summary: String,
}

pub fn collect() -> Result<Report, String> {
    collect_inner().map_err(|e| format!("Não foi possível coletar o diagnóstico: {e}"))
}

fn collect_inner() -> Result<Report, String> {
    let base = std::env::var_os("LOCALAPPDATA").ok_or("LOCALAPPDATA indisponível")?;
    let root = PathBuf::from(base).join("OpenVNC").join("Reports");
    fs::create_dir_all(&root).map_err(|e| e.to_string())?;
    let stamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|e| e.to_string())?
        .as_nanos();
    let dir = root.join(format!("{stamp}-{}", std::process::id()));
    fs::create_dir(&dir).map_err(|e| e.to_string())?;
    let script = dir.join("diagnostics.ps1");
    let path = dir.join("openvnc-host.json");
    fs::write(&script, SCRIPT).map_err(|e| e.to_string())?;
    let result = run_collector(&script, &path);
    // Remove only the script created by this invocation. Keep the report for export.
    let _ = fs::remove_file(&script);
    result?;
    let text = fs::read_to_string(&path).map_err(|e| e.to_string())?;
    let text = text.trim_start_matches('\u{feff}').to_owned();
    let data: serde_json::Value = serde_json::from_str(&text).map_err(|e| e.to_string())?;
    if data["schemaVersion"] != 1 || !data["warnings"].is_array() {
        return Err("formato de relatório inesperado".into());
    }
    let os = data["os"]["Caption"]
        .as_str()
        .unwrap_or("Windows não identificado");
    let screens = data["screens"].as_array().map_or(0, Vec::len);
    // The collector includes two informational notes in every report.
    let incomplete = data["os"].is_null()
        || screens == 0
        || data["warnings"].as_array().is_some_and(|w| w.len() > 2);
    let status = if incomplete {
        "Coleta parcial: confira os avisos no relatório."
    } else {
        "Diagnóstico coletado."
    };
    Ok(Report {
        summary: format!("{status}\r\n{os} · {screens} tela(s) detectada(s)."),
        path,
        text,
    })
}

fn run_collector(script: &std::path::Path, report: &std::path::Path) -> Result<(), String> {
    let system_root = std::env::var_os("SystemRoot").ok_or("SystemRoot indisponível")?;
    let powershell =
        PathBuf::from(system_root).join("System32/WindowsPowerShell/v1.0/powershell.exe");
    let mut child = Command::new(powershell)
        .args(["-NoLogo", "-NoProfile", "-NonInteractive", "-STA", "-File"])
        .arg(script)
        .arg("-OutputPath")
        .arg(report)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .creation_flags(0x08000000) // CREATE_NO_WINDOW; no policy bypass or elevation.
        .spawn()
        .map_err(|e| e.to_string())?;
    let start = Instant::now();
    loop {
        match child.try_wait() {
            Ok(Some(status)) => {
                return if status.success() {
                    Ok(())
                } else {
                    Err(format!("PowerShell encerrou com {status}. Verifique a política de execução de scripts e as permissões da sessão; nenhuma política foi alterada."))
                }
            }
            Ok(None) if start.elapsed() < Duration::from_secs(60) => {
                thread::sleep(Duration::from_millis(100))
            }
            result => {
                let _ = child.kill();
                let _ = child.wait();
                return Err(match result {
                    Err(e) => e.to_string(),
                    _ => "tempo limite de 60 segundos excedido".into(),
                });
            }
        }
    }
}
