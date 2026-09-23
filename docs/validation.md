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

- Após a correção, o usuário confirmou conexão, imagem, mouse, teclado e fullscreen funcionando. O usuário também confirmou barras dinâmicas, troca de Spaces e uso da senha salva.

- Inspeção da janela via `orca computer`: reproduzido timeout antes de iniciar a conexão com o Windows.
- A política de navegação comparava objetos URL diretamente. Comparar os caminhos de arquivo normalizados fez a página local e o renderer carregarem; observado na UI o avanço para “Conectando ao servidor VNC…”. Navegações para outros arquivos e URLs de rede continuam bloqueadas.
- Adicionados diagnósticos distintos para página local, inicialização JavaScript e conexão VNC. Nenhum diagnóstico inclui senha ou conteúdo remoto.
- `bash scripts/build-macos.sh` passou com acesso ao cache Swift fora do sandbox; `git diff --check` passou. Não foram adicionados nem executados testes automatizados.
- Após a correção, uma tentativa terminou em “Conexão interrompida”; TLS apareceu marcado na inspeção posterior, embora a configuração informada para a porta 6080 seja WS sem TLS. Posteriormente, o usuário confirmou autenticação, imagem e controle funcionando.

Abrir o app, informar IP Tailscale, porta websockify e senha VNC. Confirmar imagem e controle; comparar dimensões recebidas com o monitor selecionado no host. Entrar em fullscreen e alternar Spaces pelos gestos configurados no macOS. Verificar perda de foco com teclas/botões pressionados, desconexão, timeout, senha incorreta e reconexão manual. Verificar salvar, recuperar e esquecer a senha no Chaves. Em queda abrupta da rede, o cliente não pode garantir entrega das liberações de entrada ao host.

O usuário confirmou autenticação, imagem, mouse, teclado e fullscreen no host existente. Uso da senha salva e troca de Spaces também foram confirmados; queda abrupta de rede, exclusão da credencial e avaliação de fluidez prolongada permanecem pendentes. Não foi instalado driver nem criado monitor virtual. Compatibilidade com macOS 13, Macs Intel e WSS ainda não foi validada. O diagnóstico PowerShell também precisa ser executado no Windows.

## Controles dinâmicos em fullscreen

- Controles superiores e informações inferiores ocultos em fullscreen, revelados independentemente ao mover o ponteiro até os últimos 4 pontos da borda correspondente. Permanecem acessíveis enquanto o ponteiro estiver sobre a barra, com margem de 12 pontos para saída.
- Barras sobrepostas com animação de opacidade; o WKWebView permanece na mesma posição estrutural e não muda de tamanho ao revelar as barras. Em janela, as barras continuam fixas.
- Observação local dos eventos de movimento e arraste, sem consumir eventos destinados ao VNC; coordenadas corrigidas para views com eixo vertical invertido. Perda de foco e transições de fullscreen ocultam os controles.
- `bash scripts/build-macos.sh` e `git diff --check`: passaram. Sem testes automatizados. O usuário confirmou que as barras e a troca de Spaces estão fluindo bem após a atualização.

## Barras e margens pretas

- Barras sobrepostas em fullscreen usam preto opaco e esquema escuro para contraste dos controles. Fundo da página e margens internas do noVNC também usam preto puro.
- Compilação com `bash scripts/build-macos.sh` e revisão com `git diff --check` concluídas. Sem testes automatizados; aparência da nova versão ainda não validada na sessão do usuário.
- Investigação do cursor em andamento: ainda sem reprodução ou descrição precisa do sintoma; nenhuma correção de cursor aplicada nesta mudança.

## Primeiro OpenVNC Host

- O usuário informou posteriormente que o problema do cursor estava resolvido; não foi aplicada correção específica de cursor.
- Implementado Host portátil x64 em Rust/Win32: coleta local, preview JSON, avisos de coleta parcial e abertura da pasta para exportação.
- `cargo check --locked --offline -p openvnc-host --target x86_64-pc-windows-msvc`: passou no Mac, verificando o código específico de Windows.
- `cargo build --locked --offline`: núcleo existente compilou no Mac.
- Build release Windows com CRT estático passou no [GitHub Actions, execução 35920253481](https://github.com/lippdev/OpenVNC/actions/runs/35920253481), commit `fac2605`. O pacote contém `.exe`, README, licenças e SHA-256.
- `git diff --check`: passou. Nenhum teste automatizado foi adicionado ou executado; o workflow apenas compila e empacota.
- Abertura da janela, coleta na sessão interativa do usuário, política PowerShell do host e exportação ainda precisam ser validadas no Windows alvo. O runner não executou o aplicativo nem coletou inventário.
- Sem Authenticode, instalador, serviço, pareamento, listener de rede ou driver nesta entrega. O relatório não é enviado automaticamente. O Host informa falha quando o PowerShell bloqueia a execução e não altera essa política.
