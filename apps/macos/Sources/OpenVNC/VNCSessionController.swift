import AppKit
import Combine
import WebKit

@MainActor
final class VNCSessionController: NSObject, ObservableObject, WKNavigationDelegate {
    enum State { case idle, connecting, connected, disconnected, failed }
    @Published private(set) var state: State = .idle
    @Published private(set) var message: String?
    @Published private(set) var framebuffer: String?
    @Published private(set) var viewOnly = false
    let webView: WKWebView
    var active: Bool { state == .connecting || state == .connected }

    private var ready = false
    private var rendererLoading = false
    private var pageLoaded = false
    private var sessionID: String?
    private var endpoint: VNCEndpoint?
    private var password = ""
    private var remember = false
    private var timeout: Task<Void, Never>?
    private var subscriptions = Set<AnyCancellable>()
    private let page: URL?

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: .zero, configuration: config)
        page = Bundle.main.resourceURL?.appendingPathComponent("Viewer/index.html")
        super.init()
        webView.navigationDelegate = self
        config.userContentController.add(SessionMessageHandler(owner: self), name: "session")
        if let page, FileManager.default.fileExists(atPath: page.path) {
            webView.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
        } else {
            message = "Visualizador ausente. Recompile o aplicativo com o script do projeto."
        }
        for name in [NSApplication.didResignActiveNotification, NSWindow.didResignKeyNotification] {
            NotificationCenter.default.publisher(for: name)
                .receive(on: RunLoop.main)
                .sink { [weak self] notification in
                    guard let self else { return }
                    if let window = notification.object as? NSWindow, window !== self.webView.window { return }
                    self.command("window.openVNC.releaseInput()")
                }.store(in: &subscriptions)
        }
        NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self, let window = notification.object as? NSWindow,
                      window === self.webView.window else { return }
                self.disconnect()
            }.store(in: &subscriptions)
    }

    func connect(endpoint: VNCEndpoint, password supplied: String, remember: Bool) throws {
        guard !active else { return }
        guard let page, FileManager.default.fileExists(atPath: page.path) else {
            fail("Visualizador ausente. Recompile o aplicativo.")
            return
        }
        // Retrieve only on explicit connect. Never send credentials in a URL.
        let secret = supplied.isEmpty && remember
            ? try CredentialStore.read(account: endpoint.credentialAccount) ?? "" : supplied
        self.endpoint = endpoint
        self.password = secret
        self.remember = remember
        sessionID = UUID().uuidString
        state = .connecting
        message = ready ? "Conectando ao servidor VNC…" : "Carregando o visualizador local…"
        framebuffer = nil
        viewOnly = false
        timeout?.cancel()
        timeout = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 20_000_000_000) } catch { return }
            guard let self, self.state == .connecting else { return }
            self.fail(self.ready
                ? "O servidor VNC não concluiu a conexão a tempo. Confira o Tailscale, a porta e o serviço VNC."
                : self.rendererLoading
                    ? "O motor VNC não terminou de iniciar. A conexão com o Windows ainda não foi iniciada."
                    : self.pageLoaded
                        ? "A página local abriu, mas o JavaScript do visualizador não iniciou. Recompile o aplicativo."
                        : "A página do visualizador local não carregou. A conexão com o Windows ainda não foi iniciada.")
        }
        if ready { startRenderer() }
    }

    func disconnect() {
        timeout?.cancel()
        timeout = nil
        sessionID = nil
        password = ""
        endpoint = nil
        command("window.openVNC.disconnect()")
        state = .disconnected
        framebuffer = nil
    }

    func toggleViewOnly() {
        guard state == .connected else { return }
        viewOnly.toggle()
        command("window.openVNC.setViewOnly(\(viewOnly ? "true" : "false"))")
    }

    func sendCtrlAltDel() {
        guard state == .connected, !viewOnly else { return }
        command("window.openVNC.sendCtrlAltDel()")
    }

    private func startRenderer() {
        guard let endpoint, let sessionID, state == .connecting else { return }
        message = "Conectando ao servidor VNC…"
        webView.callAsyncJavaScript(
            "window.openVNC.connect(config)",
            arguments: ["config": ["id": sessionID, "url": endpoint.url.absoluteString, "password": password]],
            in: nil, in: .page
        ) { [weak self] result in
            guard let self, self.sessionID == sessionID else { return }
            if case .failure = result { self.fail("Não foi possível iniciar o visualizador VNC.") }
        }
    }

    private func command(_ script: String) {
        guard ready else { return }
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    private func fail(_ description: String) {
        disconnect()
        state = .failed
        message = description
    }

    fileprivate func receive(_ body: Any) {
        guard let body = body as? [String: Any], let event = body["event"] as? String else { return }
        if event == "rendererLoading" {
            rendererLoading = true
            return
        }
        if event == "rendererFailed" {
            ready = false
            fail("O motor VNC não pôde ser carregado. Reabra o aplicativo.")
            return
        }
        if event == "ready" {
            ready = true
            if state == .connecting { startRenderer() }
            return
        }
        guard let id = body["id"] as? String, id == sessionID else { return }
        switch event {
        case "connected":
            timeout?.cancel()
            timeout = nil
            state = .connected
            message = nil
            if remember, !password.isEmpty, let endpoint {
                do { try CredentialStore.save(password, account: endpoint.credentialAccount) }
                catch { message = "Conectado, mas não foi possível salvar a senha no Chaves." }
            }
            password = ""
        case "dimensions":
            if let width = body["width"] as? Int, let height = body["height"] as? Int,
               (1...65535).contains(width), (1...65535).contains(height) {
                framebuffer = "\(width) × \(height)"
            }
        case "disconnected":
            let clean = body["clean"] as? Bool ?? false
            disconnect()
            message = clean ? "Sessão encerrada." : "Conexão interrompida. Confira o Windows e o Tailscale antes de reconectar."
        case "credentialsRequired": fail("Informe a senha VNC para conectar. Este protótipo suporta autenticação por senha VNC.")
        case "authenticationFailed": fail("O Windows recusou a autenticação. Confira a senha e as permissões VNC.")
        case "verificationRequired": fail("Este servidor exige verificação de identidade ainda não suportada pelo protótipo.")
        default: fail("Não foi possível estabelecer a conexão VNC.")
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // WebKit reconstructs an absolute URL; Bundle URLs can retain a base URL.
        // Compare normalized file locations rather than URL representation.
        let requested = navigationAction.request.url
        let isViewer = requested?.isFileURL == true
            && requested?.standardizedFileURL.path == page?.standardizedFileURL.path
        decisionHandler(isViewer ? .allow : .cancel)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        ready = false
        fail("Não foi possível carregar o visualizador local.")
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pageLoaded = true
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        ready = false
        fail("O carregamento do visualizador local falhou.")
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        ready = false
        rendererLoading = false
        pageLoaded = false
        fail("O visualizador foi interrompido. Tente conectar novamente.")
        if let page { webView.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent()) }
    }
}

@MainActor
private final class SessionMessageHandler: NSObject, WKScriptMessageHandler {
    weak var owner: VNCSessionController?
    init(owner: VNCSessionController) { self.owner = owner }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, message.webView === owner?.webView else { return }
        owner?.receive(message.body)
    }
}
