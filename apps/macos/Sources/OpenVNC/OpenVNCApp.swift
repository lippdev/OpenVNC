import AppKit
import SwiftUI
import WebKit

@main
struct OpenVNCApp: App {
    var body: some Scene {
        WindowGroup {
            ConnectionView()
                .frame(minWidth: 680, minHeight: 600)
        }
        .defaultSize(width: 920, height: 700)
    }
}

@MainActor
private final class WindowContext: ObservableObject {
    weak var window: NSWindow?
    @Published var screen: NSScreen?
    @Published private(set) var isFullscreen = false
    @Published private(set) var topVisible = false
    @Published private(set) var bottomVisible = false
    var topHeight: CGFloat = 48
    var bottomHeight: CGFloat = 64

    func trackPointer(_ point: NSPoint, in bounds: NSRect) {
        guard isFullscreen, window?.isKeyWindow == true, bounds.contains(point) else {
            hideControls()
            return
        }
        let fromTop = bounds.maxY - point.y
        let fromBottom = point.y - bounds.minY
        let showTop = fromTop <= (topVisible ? topHeight + 12 : 4)
        let showBottom = fromBottom <= (bottomVisible ? bottomHeight + 12 : 4)
        if topVisible != showTop { topVisible = showTop }
        if bottomVisible != showBottom { bottomVisible = showBottom }
    }

    func hideControls() {
        if topVisible { topVisible = false }
        if bottomVisible { bottomVisible = false }
    }

    func update(_ window: NSWindow?) {
        self.window = window
        self.screen = window?.screen
        let fullscreen = window?.styleMask.contains(.fullScreen) == true
        if fullscreen != isFullscreen || window?.isKeyWindow != true { hideControls() }
        isFullscreen = fullscreen
    }
}

private struct ConnectionView: View {
    @AppStorage("hostAddress") private var host = ""
    @AppStorage("websocketPort") private var port = "6080"
    @AppStorage("useTLS") private var tls = false
    @AppStorage("rememberCredential") private var remember = false
    @StateObject private var context = WindowContext()
    @StateObject private var session = VNCSessionController()
    @State private var prepared: PreparedSession?
    @State private var error: String?
    @State private var password = ""

    var body: some View {
        ZStack {
            // Keep the WebView attached to this window for lifecycle events.
            remoteView.opacity(session.active ? 1 : 0)
                .allowsHitTesting(session.active)
                .accessibilityHidden(!session.active)
            if !session.active { setupView }
        }
        .background(WindowReader(context: context).frame(width: 0, height: 0))
        .onChange(of: host) { _ in invalidate() }
        .onChange(of: port) { _ in invalidate() }
        .onChange(of: tls) { _ in invalidate() }
        .onReceive(context.$screen) { _ in if !session.active { invalidate() } }
    }

    private var setupView: some View {
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
                    TextField("IP Tailscale do Windows", text: $host)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(connect)
                    HStack {
                        Text("Porta da ponte VNC")
                        TextField("6080", text: $port).frame(width: 80)
                        Toggle("Usar TLS (WSS)", isOn: $tls)
                    }
                    SecureField("Senha VNC", text: $password)
                        .textFieldStyle(.roundedBorder).onSubmit(connect)
                    Toggle("Usar e salvar senha no Chaves", isOn: $remember)
                    Button("Esquecer senha salva") { forgetCredential() }
                        .font(.caption)
                    Text("Mantenha o Tailscale conectado. A senha é a do serviço VNC do Windows.")
                        .font(.caption).foregroundStyle(.secondary)
                    Divider()
                    Label(context.screen?.localizedName ?? "Identificando tela…", systemImage: "laptopcomputer")
                    Text("A resolução será preparada para a tela onde esta janela está aberta.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
            if let message = session.message {
                Text(message).foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
            Text("Conexão VNC: exibe a tela selecionada no Windows. A criação automática de monitor virtual ainda está em desenvolvimento.")
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                Button("Tela cheia", systemImage: "arrow.up.left.and.arrow.down.right") {
                    context.window?.toggleFullScreen(nil)
                }
                Spacer()
                Button("Conectar ao Windows", action: connect)
                    .buttonStyle(.borderedProminent)
                    .disabled(host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var remoteView: some View {
        VStack(spacing: 0) {
            if !context.isFullscreen {
                sessionControls
                Divider()
            }
            VNCWebView(webView: session.webView)
            if !context.isFullscreen { sessionFooter }
        }
        .overlay(alignment: .top) {
            if context.isFullscreen {
                sessionControls
                    .background(.regularMaterial)
                    .background(panelMeasurement { context.topHeight = $0 })
                    .opacity(context.topVisible ? 1 : 0)
                    .allowsHitTesting(context.topVisible)
                    .accessibilityHidden(!context.topVisible)
            }
        }
        .overlay(alignment: .bottom) {
            if context.isFullscreen {
                sessionFooter
                    .frame(maxWidth: .infinity)
                    .background(.regularMaterial)
                    .background(panelMeasurement { context.bottomHeight = $0 })
                    .opacity(context.bottomVisible ? 1 : 0)
                    .allowsHitTesting(context.bottomVisible)
                    .accessibilityHidden(!context.bottomVisible)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: context.topVisible)
        .animation(.easeInOut(duration: 0.18), value: context.bottomVisible)
        .onChange(of: session.active) { _ in context.hideControls() }
    }

    private func panelMeasurement(_ update: @escaping (CGFloat) -> Void) -> some View {
        GeometryReader { geometry in
            Color.clear
                .onAppear { update(geometry.size.height) }
                .onChange(of: geometry.size.height) { update($0) }
        }
    }

    private var sessionControls: some View {
        HStack {
            Circle().fill(session.state == .connected ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(session.state == .connected ? "Conectado" : "Conectando…")
            if let framebuffer = session.framebuffer {
                Text(framebuffer).foregroundStyle(.secondary)
            }
            Spacer()
            Button(session.viewOnly ? "Permitir controle" : "Somente visualizar") {
                session.toggleViewOnly()
            }.disabled(session.state != .connected)
            Button("Ctrl+Alt+Del") { session.sendCtrlAltDel() }
                .disabled(session.state != .connected || session.viewOnly)
            Button { context.window?.toggleFullScreen(nil) } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }.help("Alternar tela cheia")
            Button("Desconectar") { session.disconnect() }
        }
        .padding(10)
    }

    private var sessionFooter: some View {
        VStack(spacing: 0) {
            if let message = session.message {
                Text(message).font(.caption).padding(6)
            }
            if let prepared {
                Text("Referência do Mac: \(prepared.width) × \(prepared.height). O VNC atual usa o monitor escolhido no Windows.")
                    .font(.caption).foregroundStyle(.secondary).padding(6)
            }
        }
    }

    private func invalidate() {
        prepared = nil
        error = nil
    }

    private func connect() {
        invalidate()
        do {
            let endpoint = try VNCEndpoint(host: host, port: port, tls: tls)
            prepared = try SessionPreparation.prepare(host: host, screen: context.window?.screen)
            try session.connect(endpoint: endpoint, password: password, remember: remember)
            password = ""
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func forgetCredential() {
        do {
            let endpoint = try VNCEndpoint(host: host, port: port, tls: tls)
            try CredentialStore.remove(account: endpoint.credentialAccount)
            password = ""
            error = nil
        } catch { self.error = error.localizedDescription }
    }
}

private struct VNCWebView: NSViewRepresentable {
    let webView: WKWebView
    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

private struct WindowReader: NSViewRepresentable {
    let context: WindowContext

    func makeNSView(context: Context) -> ScreenObserverView {
        let view = ScreenObserverView()
        view.onUpdate = { [weak model = self.context] window in model?.update(window) }
        view.onPointer = { [weak model = self.context] point, bounds in
            model?.trackPointer(point, in: bounds)
        }
        return view
    }

    func updateNSView(_ nsView: ScreenObserverView, context: Context) {}
}

private final class ScreenObserverView: NSView {
    var onUpdate: ((NSWindow?) -> Void)?
    var onPointer: ((NSPoint, NSRect) -> Void)?
    private var mouseMonitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self)
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        mouseMonitor = nil
        if let window {
            window.acceptsMouseMovedEvents = true
            mouseMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
            ) { [weak self] event in
                // Observe only; all movement and drag events still reach the VNC view.
                if let self, event.window === self.window, let content = self.window?.contentView {
                    var point = content.convert(event.locationInWindow, from: nil)
                    if content.isFlipped {
                        point.y = content.bounds.minY + content.bounds.maxY - point.y
                    }
                    self.onPointer?(point, content.bounds)
                }
                return event
            }
            window.collectionBehavior.insert(.fullScreenPrimary)
            for name in [NSWindow.didChangeScreenNotification, NSWindow.didChangeBackingPropertiesNotification,
                         NSWindow.didEnterFullScreenNotification, NSWindow.didExitFullScreenNotification,
                         NSWindow.didResignKeyNotification] {
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

    deinit {
        NotificationCenter.default.removeObserver(self)
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
    }
}
