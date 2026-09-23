# ADR-001: conectar ao VNC existente antes da gestão de display

Estado: adotado para o primeiro protótipo de conexão.

O host já expõe TightVNC por websockify na interface Tailscale. Incorporar noVNC 1.7.0 como biblioteca de renderização em WKWebView permite reutilizar esse caminho. A janela, o fullscreen, as credenciais e o ciclo de sessão ficam em Swift; a política de endpoint fica no núcleo Rust.

Os recursos web serão empacotados no app, sem CDN, página remota ou servidor HTTP local. esbuild 0.28.2 gera um único script durante o build. npm lockfile fixa integridade e versões; o app não precisa de Node ou npm em execução.

Licenças declaradas dos pacotes: noVNC MPL-2.0; esbuild MIT. Preservar os avisos e licenças dos componentes transitivos incluídos no bundle. Não modificar o código upstream noVNC. Fontes do noVNC: https://github.com/novnc/noVNC/tree/v1.7.0.

No protótipo, WebSocket sem TLS somente para IPs do intervalo Tailscale IPv4/IPv6: a criptografia depende do túnel Tailscale existente. WSS exige a verificação TLS normal. Não desativar verificação de certificados. Não aceitar URLs com credenciais ou senhas em parâmetros. A configuração Tailscale e suas políticas precisam estar corretas; validar um IP não autentica o computador remoto.

O renderer exibirá o framebuffer que o servidor VNC selecionar. Escala local não é criação de monitor virtual. Não habilitar resizeSession nem alterar monitores físicos para simular esse recurso. Não oferecer seleção de codec/bitrate de vídeo nesta rota VNC.

Próxima prova: driver virtual + seleção do monitor no host + captura real. Este ADR não afirma compatibilidade do TightVNC com qualquer driver virtual.
