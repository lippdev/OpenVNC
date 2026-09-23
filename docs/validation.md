# Validação — 2026-09-23

- Ambiente: Mac arm64, Swift 6.4, Cargo 1.98.1.
- `cargo build --offline`: passou, sem dependências externas.
- `bash scripts/build-macos.sh`: passou; cliente Swift ligado à biblioteca Rust e bundle `dist/OpenVNC.app` gerado com assinatura ad hoc.
- `git diff --check`: passou.
- Dependências noVNC 1.7.0 e esbuild 0.28.2 fixadas em lockfile com integridade.
- Build do renderer e compilação Rust/Swift passaram; bundle inclui fontes/licenças upstream.
- A ponte do Windows respondeu HTTP com `405 Method Not Allowed` e identificação `WebSockify Python/3.11.16` à consulta HEAD. Isso confirma alcance do serviço, não autenticação VNC nem captura.
- Não foram executados testes automatizados nem validação visual/interativa. A ferramenta de controle da UI indicada pela skill retornou `zsh: command not found: orca`.
- A compilação precisou de acesso ao cache de módulos do Swift fora do sandbox de execução do agente.

## Validação manual pendente

### Investigação do carregamento local

- Após a correção, o usuário confirmou conexão, imagem, mouse, teclado e fullscreen funcionando. Reconexão com senha salva continua pendente.

- Inspeção da janela via `orca computer`: reproduzido timeout antes de iniciar a conexão com o Windows.
- A política de navegação comparava objetos URL diretamente. Comparar os caminhos de arquivo normalizados fez a página local e o renderer carregarem; observado na UI o avanço para “Conectando ao servidor VNC…”. Navegações para outros arquivos e URLs de rede continuam bloqueadas.
- Adicionados diagnósticos distintos para página local, inicialização JavaScript e conexão VNC. Nenhum diagnóstico inclui senha ou conteúdo remoto.
- `bash scripts/build-macos.sh` passou com acesso ao cache Swift fora do sandbox; `git diff --check` passou. Não foram adicionados nem executados testes automatizados.
- Após a correção, uma tentativa terminou em “Conexão interrompida”; TLS apareceu marcado na inspeção posterior, embora a configuração informada para a porta 6080 seja WS sem TLS. Autenticação com senha digitada pelo usuário, imagem e controle continuam pendentes.

Abrir o app, informar IP Tailscale, porta websockify e senha VNC. Confirmar imagem e controle; comparar dimensões recebidas com o monitor selecionado no host. Entrar em fullscreen e alternar Spaces pelos gestos configurados no macOS. Verificar perda de foco com teclas/botões pressionados, desconexão, timeout, senha incorreta e reconexão manual. Verificar salvar, recuperar e esquecer a senha no Chaves. Em queda abrupta da rede, o cliente não pode garantir entrega das liberações de entrada ao host.

O usuário confirmou autenticação, imagem, mouse, teclado e fullscreen no host existente. Reconexão, persistência da senha e avaliação de fluidez prolongada permanecem pendentes. Não foi instalado driver nem criado monitor virtual. Compatibilidade com macOS 13, Macs Intel e WSS ainda não foi validada. O diagnóstico PowerShell também precisa ser executado no Windows.

## Controles dinâmicos em fullscreen

- Controles superiores e informações inferiores ocultos em fullscreen, revelados independentemente ao mover o ponteiro até os últimos 4 pontos da borda correspondente. Permanecem acessíveis enquanto o ponteiro estiver sobre a barra, com margem de 12 pontos para saída.
- Barras sobrepostas com animação de opacidade; o WKWebView permanece na mesma posição estrutural e não muda de tamanho ao revelar as barras. Em janela, as barras continuam fixas.
- Observação local dos eventos de movimento e arraste, sem consumir eventos destinados ao VNC; coordenadas corrigidas para views com eixo vertical invertido. Perda de foco e transições de fullscreen ocultam os controles.
- `bash scripts/build-macos.sh` e `git diff --check`: passaram. Sem testes automatizados. A interação das novas barras, incluindo convivência com menu/Dock do macOS, ainda precisa de validação manual após reabrir o aplicativo; a sessão ativa do usuário não foi reiniciada.
