import AppKit
import SwiftUI

@main
struct OpenVNCApp: App {
    var body: some Scene {
        WindowGroup {
            ConnectionView()
                .frame(minWidth: 560, minHeight: 460)
        }
        .defaultSize(width: 680, height: 540)
    }
}

@MainActor
private final class WindowContext: ObservableObject {
    weak var window: NSWindow?
    @Published var screen: NSScreen?

    func update(_ window: NSWindow?) {
        self.window = window
        self.screen = window?.screen
    }
}

private struct ConnectionView: View {
    @AppStorage("hostAddress") private var host = ""
    @StateObject private var context = WindowContext()
    @State private var prepared: PreparedSession?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                Image(systemName: "display.2")
                    .font(.system(size: 38))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Seu Windows, no Mac").font(.title.bold())
                    Text("Uma tela adaptada ao seu espaço de trabalho.")
                        .foregroundStyle(.secondary)
                }
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Computador Windows").font(.headline)
                    TextField("IP ou nome do computador no Tailscale", text: $host)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(prepare)
                    Text("Use um computador acessível pela sua rede Tailscale.")
                        .font(.caption).foregroundStyle(.secondary)
                    Divider()
                    Label(context.screen?.localizedName ?? "Identificando tela…", systemImage: "laptopcomputer")
                    Text("A resolução será preparada para a tela onde esta janela está aberta.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let prepared {
                VStack(alignment: .leading, spacing: 5) {
                    Label("Configuração preparada", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                    Text("\(prepared.host) · \(prepared.width) × \(prepared.height) pixels")
                    Text("Escala sugerida: \(prepared.scalePercent)% — depende do suporte do Windows.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .textSelection(.enabled)
            }
            if let error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }

            Spacer(minLength: 0)
            Text("Prévia inicial: prepara a configuração local. A conexão e a criação da tela no Windows estarão disponíveis em uma próxima etapa.")
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                Button("Tela cheia", systemImage: "arrow.up.left.and.arrow.down.right") {
                    context.window?.toggleFullScreen(nil)
                }
                Spacer()
                Button("Preparar sessão", action: prepare)
                    .buttonStyle(.borderedProminent)
                    .disabled(host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(28)
        .background(WindowReader(context: context).frame(width: 0, height: 0))
        .onChange(of: host) { _ in invalidate() }
        .onReceive(context.$screen) { _ in invalidate() }
    }

    private func invalidate() {
        prepared = nil
        error = nil
    }

    private func prepare() {
        invalidate()
        do {
            prepared = try SessionPreparation.prepare(host: host, screen: context.window?.screen)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct WindowReader: NSViewRepresentable {
    let context: WindowContext

    func makeNSView(context: Context) -> ScreenObserverView {
        let view = ScreenObserverView()
        view.onUpdate = { [weak model = self.context] window in model?.update(window) }
        return view
    }

    func updateNSView(_ nsView: ScreenObserverView, context: Context) {}
}

private final class ScreenObserverView: NSView {
    var onUpdate: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self)
        if let window {
            window.collectionBehavior.insert(.fullScreenPrimary)
            for name in [NSWindow.didChangeScreenNotification, NSWindow.didChangeBackingPropertiesNotification] {
                NotificationCenter.default.addObserver(
                    self, selector: #selector(refresh), name: name, object: window
                )
            }
        }
        refresh()
    }

    @objc private func refresh() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.onUpdate?(self.window)
        }
    }

    deinit { NotificationCenter.default.removeObserver(self) }
}
